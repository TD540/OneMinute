//
//  TimerActivityAttributes.swift
//  OneMinute
//

import ActivityKit
import Foundation

/// Describes the Live Activity shown on the Lock Screen and in the Dynamic Island while the
/// timer runs. Shared between the app, which starts and ends it, and the widget extension,
/// which draws it.
nonisolated struct TimerActivityAttributes: ActivityAttributes {
    /// Nothing changes during the minute: the system counts from `start` on its own.
    struct ContentState: Codable, Hashable {}

    /// When the timer started.
    var start: Date

    /// The minute being counted, for timer texts and progress views.
    var interval: ClosedRange<Date> { start...start.addingTimeInterval(60) }
}
