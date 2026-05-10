import ActivityKit
import WidgetKit
import SwiftUI

struct TimelogWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimelogActivityAttributes.self) { context in
            // Lock Screen / Notification banner
            HStack(spacing: 16) {
                Image(systemName: context.state.isRunning ? "timer" : "pause.circle")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.displayTime)
                        .font(.system(.title2, design: .monospaced, weight: .semibold))
                        .monospacedDigit()
                    Text(context.state.phase)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.75))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .foregroundStyle(.tint)
                        .font(.title3)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.displayTime)
                        .font(.system(.title2, design: .monospaced, weight: .semibold))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.phase)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    EmptyView()
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.tint)
                    .font(.caption)
            } compactTrailing: {
                Text(context.state.displayTime)
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.tint)
            }
        }
    }
}

#Preview("Lock Screen", as: .content, using: TimelogActivityAttributes()) {
    TimelogWidgetExtensionLiveActivity()
} contentStates: {
    TimelogActivityAttributes.ContentState(displayTime: "25:00", isRunning: true, phase: "Focus")
    TimelogActivityAttributes.ContentState(displayTime: "04:32", isRunning: false, phase: "Short Break")
}
