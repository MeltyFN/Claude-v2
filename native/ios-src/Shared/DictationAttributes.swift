// Shared by the App target AND the Widget extension target (tick both in Xcode's Target Membership).
// Describes what the Live Activity shows.
import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct DictationAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// When listening started; the lock screen counts up from here on its own ("Listening · 12:31").
        var startedAt: Date
        /// The most recent words heard (trimmed to fit).
        var latestWords: String
        /// false once dictation has stopped.
        var isListening: Bool
    }

    /// The sermon title (or "Sermon Notes" if it has none yet).
    var noteTitle: String
}
