// Widget extension target only (replace the files Xcode generated for the extension with this one).
// The Live Activity: a lock-screen card and the Dynamic Island, in the app's colors
// (#14161C, #5A6070, #E6E8EE, #FAF9F6).
import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct SermonNotesWidgets: WidgetBundle {
    var body: some Widget {
        SermonLiveActivity()
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    static let ink = Color(hex: 0x14161C)
    static let slate = Color(hex: 0x5A6070)
    static let mist = Color(hex: 0xE6E8EE)
    static let paper = Color(hex: 0xFAF9F6)
    static let rec = Color(hex: 0xE5484D)      // recording red
}

struct SermonLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DictationAttributes.self) { context in
            LockScreenCard(context: context)
                .activityBackgroundTint(Color.ink)
                .activitySystemActionForegroundColor(Color.paper)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .foregroundStyle(context.state.isListening ? Color.rec : Color.slate)
                            .symbolEffectPulseIfAvailable(context.state.isListening)
                        Text(context.state.isListening ? "Listening" : "Stopped")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.paper)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(state: context.state)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.mist)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(wordsOrPlaceholder(context.state))
                            .font(.footnote)
                            .foregroundStyle(Color.mist)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if context.state.isListening { StopButton() }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "waveform")
                    .foregroundStyle(context.state.isListening ? Color.rec : Color.slate)
            } compactTrailing: {
                ElapsedText(state: context.state)
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.mist)
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "waveform")
                    .foregroundStyle(context.state.isListening ? Color.rec : Color.slate)
            }
            .keylineTint(Color.rec)
        }
    }
}

/// The card on the lock screen: "Listening · 12:31", the sermon title, the latest words and Stop.
struct LockScreenCard: View {
    let context: ActivityViewContext<DictationAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(context.state.isListening ? Color.rec : Color.slate)
                        .frame(width: 8, height: 8)
                    if context.state.isListening {
                        (Text("Listening · ") + Text(context.state.startedAt, style: .timer))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.paper)
                    } else {
                        Text("Dictation stopped")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.paper)
                    }
                }
                Text(context.attributes.noteTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.slate)
                    .lineLimit(1)
                Text(wordsOrPlaceholder(context.state))
                    .font(.footnote)
                    .foregroundStyle(Color.mist)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if context.state.isListening { StopButton(compact: true) }
        }
        .padding(16)
    }
}

/// Counts up from when listening started, without the app needing to send updates.
struct ElapsedText: View {
    let state: DictationAttributes.ContentState
    var body: some View {
        if state.isListening {
            Text(state.startedAt, style: .timer).multilineTextAlignment(.trailing)
        } else {
            Text("Done")
        }
    }
}

/// Stops dictation right from the lock screen (iOS 17+). On iOS 16, tapping the card opens the app instead.
struct StopButton: View {
    var compact = false
    var body: some View {
        if #available(iOS 17.0, *) {
            Button(intent: StopDictationIntent()) {
                Label("Stop", systemImage: "stop.fill")
                    .font(.footnote.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: compact ? nil : .infinity)
            }
            .tint(Color.rec)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
    }
}

private func wordsOrPlaceholder(_ state: DictationAttributes.ContentState) -> String {
    if !state.latestWords.isEmpty { return state.latestWords }
    return state.isListening ? "Listening for the first words…" : "Open Sermon Notes to see your transcript."
}

private extension View {
    /// A gentle pulse on the waveform while listening (iOS 17+), plain on iOS 16.
    @ViewBuilder func symbolEffectPulseIfAvailable(_ on: Bool) -> some View {
        if on {
            if #available(iOS 17.0, *) { self.symbolEffect(.pulse) } else { self }
        } else {
            self
        }
    }
}
