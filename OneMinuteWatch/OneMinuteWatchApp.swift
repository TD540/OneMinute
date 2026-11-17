//
//  OneMinuteWatchApp.swift
//  OneMinuteWatch
//

import SwiftUI

@main
struct OneMinuteWatchApp: App {
    init() {
        // Early, so a start or stop from the other device that launches the app arrives.
        TimerSync.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}
