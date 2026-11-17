//
//  OneMinuteWidget.swift
//  OneMinuteWidget
//

import ActivityKit
import WidgetKit
import SwiftUI

/// The running timer on the Lock Screen and in the Dynamic Island. The system counts the seconds
/// itself, so the activity keeps up even while the app is suspended.
struct OneMinuteLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            // Lock Screen: black on green, like the app while it counts.
            HStack {
                Text("Minuut")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Spacer()
                ElapsedText(interval: context.attributes.interval, isOver: context.isStale, size: 56)
                    .frame(width: 140, alignment: .trailing)
            }
            .foregroundStyle(.black)
            .padding()
            .activityBackgroundTint(.green)
            .activitySystemActionForegroundColor(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ProgressRing(interval: context.attributes.interval)
                        .frame(width: 44, height: 44)
                        .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(interval: context.attributes.interval, isOver: context.isStale, size: 44)
                        .foregroundStyle(.green)
                        .frame(width: 120, alignment: .trailing)
                }
            } compactLeading: {
                ProgressRing(interval: context.attributes.interval)
            } compactTrailing: {
                ElapsedText(interval: context.attributes.interval, isOver: context.isStale, size: 17, weight: .bold)
                    .foregroundStyle(.green)
                    .frame(width: 44, alignment: .trailing)
            } minimal: {
                ProgressRing(interval: context.attributes.interval)
            }
            .keylineTint(.green)
        }
    }
}

/// The seconds counted so far, from 0 up to 60, updated live by the system. Once the minute is
/// over, "start" again, like the app.
private struct ElapsedText: View {
    var interval: ClosedRange<Date>
    /// Whether the minute has run out, which the system reports by marking the activity stale.
    var isOver: Bool
    var size: CGFloat
    var weight: Font.Weight = .black

    /// How much the digits are pulled together.
    private var tracking: CGFloat { 0.04 * size }

    var body: some View {
        Group {
            if isOver {
                Text("start")
                    .minimumScaleFactor(0.5)
            } else {
                // The system's live timer always reads "0:31", and Live Activities can't format
                // it differently. So the timer is laid out wide enough for all of it, aligned to
                // the trailing edge, and clipped to the last two digits.
                Text(timerInterval: interval, countsDown: false)
                    .monospacedDigit()
                    // Tighter than usual, like the digits in the app.
                    .tracking(-tracking)
                    .multilineTextAlignment(.trailing)
                    // Tracking also shortens the last digit, which would poke out past the edge.
                    .padding(.trailing, tracking)
                    .frame(width: 4 * size, alignment: .trailing)
                    .frame(width: 1.36 * size, alignment: .trailing)
                    .clipped()
            }
        }
        .font(.system(size: size, weight: weight, design: .rounded))
        .lineLimit(1)
    }
}

/// A green ring that fills up over the minute.
private struct ProgressRing: View {
    var interval: ClosedRange<Date>

    var body: some View {
        ProgressView(timerInterval: interval, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.circular)
        .tint(.green)
    }
}

#Preview("Lock Screen", as: .content, using: TimerActivityAttributes(start: .now)) {
    OneMinuteLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState()
}

#Preview("Compact", as: .dynamicIsland(.compact), using: TimerActivityAttributes(start: .now)) {
    OneMinuteLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState()
}
