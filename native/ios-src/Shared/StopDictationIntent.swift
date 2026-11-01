// Shared by the App target AND the Widget extension target (tick both in Xcode's Target Membership).
// The Stop button on the lock screen / Dynamic Island. Because it is a LiveActivityIntent, iOS runs it
// inside the app's own process, where DictationManager is listening for this notification.
import AppIntents
import Foundation

extension Notification.Name {
    static let stopSermonDictation = Notification.Name("SermonNotesStopDictation")
}

@available(iOS 17.0, *)
struct StopDictationIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop dictation"
    static var description = IntentDescription("Stops Sermon Notes dictation.")

    init() {}

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .stopSermonDictation, object: nil)
        }
        return .result()
    }
}
