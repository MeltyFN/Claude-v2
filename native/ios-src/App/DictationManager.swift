// App target only.
// Native dictation for the iPhone build: Apple's speech recognition, kept running while the phone is
// locked (needs the "Audio" background mode), plus the Live Activity on the lock screen / Dynamic Island.
import ActivityKit
import AVFoundation
import Foundation
import Speech

final class DictationManager {
    static let shared = DictationManager()

    /// Words still being recognized (shown as a live preview in the app).
    var onPartial: ((String) -> Void)?
    /// A finished phrase is waiting; the web app collects it with drain().
    var onFinal: (() -> Void)?
    /// Listening started (true) or stopped (false), with an optional reason.
    var onState: ((Bool, String?) -> Void)?

    private(set) var isListening = false
    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var currentToken = UUID()
    private var rolloverTimer: Timer?

    // Finished phrases waiting for the web app. Kept here so nothing is lost while the
    // app's page is asleep behind the lock screen; the page collects them when it wakes.
    private var pending: [String] = []
    private let pendingLock = NSLock()

    private var startedAt = Date()
    private var latest = ""
    private var activity: Any?                  // Activity<DictationAttributes> on iOS 16.2+
    private var lastActivityUpdate = Date.distantPast
    private var trailingUpdate: DispatchWorkItem?

    private init() {
        // The lock-screen Stop button (StopDictationIntent) posts this.
        NotificationCenter.default.addObserver(forName: .stopSermonDictation, object: nil, queue: .main) { [weak self] _ in
            self?.stop(reason: nil)
        }
        // A phone call or Siri interrupts the microphone: stop cleanly and say why.
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            self?.stop(reason: "Dictation stopped because another app (like a phone call) took the microphone.")
        }
    }

    // MARK: - Permissions

    func requestPermissions(_ done: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { DispatchQueue.main.async { done(false) }; return }
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async { done(granted) }
            }
        }
    }

    // MARK: - Start / stop

    func start(locale: String, title: String) throws {
        if isListening { return }
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)) ?? SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "SermonDictation", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Speech recognition isn't available right now. Check your internet connection."])
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        engine.prepare()
        try engine.start()

        isListening = true
        startedAt = Date()
        latest = ""
        beginTask()
        // Apple limits a single recognition request to about a minute, so hand over to a fresh one regularly.
        rolloverTimer = Timer.scheduledTimer(withTimeInterval: 50, repeats: true) { [weak self] _ in self?.rollOver() }
        startActivity(title: title)
        onState?(true, nil)
    }

    func stop(reason: String?) {
        guard isListening else { return }
        isListening = false
        rolloverTimer?.invalidate(); rolloverTimer = nil
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()          // the last words still arrive as a final result
        currentToken = UUID()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        endActivity()
        onState?(false, reason)
    }

    /// Finished phrases the web app hasn't collected yet (and forget them).
    func drain() -> [String] {
        pendingLock.lock(); defer { pendingLock.unlock() }
        let out = pending
        pending.removeAll()
        return out
    }

    // MARK: - Recognition

    private func beginTask() {
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if #available(iOS 16, *) { req.addsPunctuation = true }
        request = req

        let token = UUID()
        currentToken = token
        var heardSoFar = ""
        var finished = false

        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    if result.isFinal {
                        if !finished { finished = true; self.commit(text) }
                    } else {
                        heardSoFar = text
                        if token == self.currentToken { self.partial(text) }
                    }
                }
                if error != nil && !finished {
                    // Recognition gave up (long silence, network hiccup): keep what was heard and carry on.
                    finished = true
                    self.commit(heardSoFar)
                    if token == self.currentToken && self.isListening {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            if self.isListening && token == self.currentToken { self.beginTask() }
                        }
                    }
                }
            }
        }
    }

    private func rollOver() {
        guard isListening else { return }
        let old = request
        beginTask()        // new audio goes to the fresh request from now on
        old?.endAudio()    // the old one finishes and delivers its final text
    }

    private func commit(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        pendingLock.lock(); pending.append(t); pendingLock.unlock()
        latest = t
        updateActivity(force: true)
        onFinal?()
    }

    private func partial(_ text: String) {
        latest = text
        updateActivity(force: false)
        onPartial?(text)
    }

    // MARK: - Live Activity

    private func trimmed(_ s: String) -> String {
        s.count > 110 ? "…" + String(s.suffix(110)) : s
    }

    private func startActivity(title: String) {
        guard #available(iOS 16.2, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        for old in Activity<DictationAttributes>.activities {           // never leave a stale one behind
            Task { await old.end(nil, dismissalPolicy: .immediate) }
        }
        let attributes = DictationAttributes(noteTitle: title.isEmpty ? "Sermon Notes" : title)
        let state = DictationAttributes.ContentState(startedAt: startedAt, latestWords: "", isListening: true)
        activity = try? Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil), pushType: nil)
    }

    /// Updates are limited to about one every 1.5 seconds (iOS budgets them); the latest words are never dropped.
    private func updateActivity(force: Bool) {
        guard #available(iOS 16.2, *), let a = activity as? Activity<DictationAttributes> else { return }
        let wait = 1.5 - Date().timeIntervalSince(lastActivityUpdate)
        if !force && wait > 0 {
            trailingUpdate?.cancel()
            let item = DispatchWorkItem { [weak self] in self?.updateActivity(force: true) }
            trailingUpdate = item
            DispatchQueue.main.asyncAfter(deadline: .now() + wait, execute: item)
            return
        }
        trailingUpdate?.cancel()
        lastActivityUpdate = Date()
        let state = DictationAttributes.ContentState(startedAt: startedAt, latestWords: trimmed(latest), isListening: true)
        Task { await a.update(.init(state: state, staleDate: nil)) }
    }

    private func endActivity() {
        trailingUpdate?.cancel()
        guard #available(iOS 16.2, *), let a = activity as? Activity<DictationAttributes> else { return }
        let state = DictationAttributes.ContentState(startedAt: startedAt, latestWords: trimmed(latest), isListening: false)
        // Show "Dictation stopped" briefly, then remove it from the lock screen.
        Task { await a.end(.init(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(10))) }
        activity = nil
    }
}
