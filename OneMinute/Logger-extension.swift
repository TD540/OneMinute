//
//  Logger-extension.swift
//  OneMinute
//
//  https://www.avanderlee.com/debugging/oslog-unified-logging/
//

import OSLog

extension Logger {
    /// Using your bundle identifier is a great way to ensure a unique identifier.
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// Logs the view cycles like a view that appeared.
    static let viewCycle = Logger(subsystem: subsystem, category: "viewcycle")

    /// All logs related to tracking and analytics.
    static let statistics = Logger(subsystem: subsystem, category: "statistics")

    /// All logs related to haptics.
    static let haptics = Logger(subsystem: subsystem, category: "haptics")
}
