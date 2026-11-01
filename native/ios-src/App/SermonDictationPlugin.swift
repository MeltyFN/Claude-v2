// App target only.
// Lets the web app (index.html) use native dictation: start(), stop(), drain() and
// "partial" / "final" / "state" events. The web app switches to this automatically
// when it is running inside the native iPhone build.
import Capacitor
import Foundation

@objc(SermonDictationPlugin)
public class SermonDictationPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "SermonDictationPlugin"
    public let jsName = "SermonDictation"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stop", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "drain", returnType: CAPPluginReturnPromise)
    ]

    private let manager = DictationManager.shared

    public override func load() {
        manager.onPartial = { [weak self] text in self?.notifyListeners("partial", data: ["text": text]) }
        manager.onFinal = { [weak self] in self?.notifyListeners("final", data: [:]) }
        manager.onState = { [weak self] listening, reason in
            var data: [String: Any] = ["listening": listening]
            if let reason { data["error"] = reason }
            self?.notifyListeners("state", data: data)
        }
    }

    @objc func start(_ call: CAPPluginCall) {
        let lang = call.getString("lang") ?? Locale.current.identifier
        let title = call.getString("title") ?? ""
        manager.requestPermissions { [weak self] granted in
            guard let self else { return }
            guard granted else {
                call.reject("Microphone or speech recognition permission was denied. Turn them on in Settings > Sermon Notes.", "not-allowed")
                return
            }
            do {
                try self.manager.start(locale: lang, title: title)
                call.resolve()
            } catch {
                call.reject(error.localizedDescription, "start-failed")
            }
        }
    }

    @objc func stop(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.manager.stop(reason: nil)
            call.resolve()
        }
    }

    @objc func drain(_ call: CAPPluginCall) {
        call.resolve(["texts": manager.drain()])
    }
}
