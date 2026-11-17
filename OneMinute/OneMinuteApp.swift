//
//  OneMinuteApp.swift
//  OneMinute
//
//  Created by Thomas on 09/10/2023.
//

import SwiftUI

@main
struct OneMinuteApp: App {
    init() {
        // Early, so a start or stop from the other device that launches the app arrives.
        TimerSync.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
