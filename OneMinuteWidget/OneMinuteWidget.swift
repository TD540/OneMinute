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
                Text("1 minute")
                    .font(.system(.title3, weight: .bold))
                Spacer()
                ElapsedText(interval: context.attributes.interval)
                    .font(.system(size: 56, weight: .black))
                    .frame(width: 140)
                    .multilineTextAlignment(.trailing)
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
                    ElapsedText(interval: context.attributes.interval)
                        .font(.system(size: 44, weight: .black))
                        .foregroundStyle(.green)
                        .frame(width: 120)
                        .multilineTextAlignment(.trailing)
                }
            } compactLeading: {
                ProgressRing(interval: context.attributes.interval)
            } compactTrailing: {
                ElapsedText(interval: context.attributes.interval)
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(.green)
                    .frame(width: 44)
                    .multilineTextAlignment(.trailing)
            } minimal: {
                ProgressRing(interval: context.attributes.interval)
            }
            .keylineTint(.green)
        }
    }
}

/// The time counted so far, from 0:00 up to 1:00, updated live by the system.
private struct ElapsedText: View {
    var interval: ClosedRange<Date>

    var body: some View {
        Text(timerInterval: interval, countsDown: false)
            .monospacedDigit()
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
