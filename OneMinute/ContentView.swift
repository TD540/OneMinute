//
//  ContentView.swift
//  OneMinute
//
//  Created by Thomas on 09/10/2023.
//

import SwiftUI

/// Dev flag: set to `true` to count every 0.05 s instead of every second.
private let fastMode = false

struct ContentView: View {
    /// Seconds counted so far, or `nil` when the timer isn't running.
    @State private var seconds: Int?
    @State private var haptics = Haptics()
    @State private var foldSides = FoldSides()
    @Environment(\.scenePhase) private var scenePhase

    private var isRunning: Bool { seconds != nil }

    var body: some View {
        Button {
            seconds = isRunning ? nil : 0
        } label: {
            Group {
                if let seconds {
                    RollingNumber(value: seconds, reservedDigits: 2)
                } else {
                    Text("start")
                }
            }
                .font(.system(size: isRunning ? 400 : 100, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // On a partially open iPhone Duo: "start" on the right side, the count on the left.
                .padding(isRunning ? foldSides.first : foldSides.second)
                .onGeometryChange(for: FoldSides.self, of: FoldSides.init) { foldSides = $0 }
                // Black while running, like the Dynamic Island.
                .tappableIndicators(color: isRunning ? .black : .primary)
                .background(isRunning ? .green : .clear)
                .contentShape(.rect)
        }
        .foregroundStyle(.primary)
        // Cover the whole display; the indicators follow its rounded corners.
        .ignoresSafeArea()
        .statusBarHidden()
        .animation(.easeInOut, value: isRunning)
        .task(id: isRunning) {
            // Restarted whenever the timer starts or stops; stopping cancels the count.
            guard isRunning else { return }
            try? await count()
        }
    }

    /// Counts to 60 with a tick haptic each step and a long one at the end, then stops.
    private func count() async throws {
        let tick: Duration = fastMode ? .milliseconds(50) : .seconds(1)
        let start = ContinuousClock.now

        for second in 1...60 {
            // Sleeping until a fixed deadline avoids drift and keeps counting real time
            // while the app is in the background.
            let deadline = start + tick * second
            try await Task.sleep(until: deadline)
            seconds = second

            // Skip haptics when inactive, or when catching up on ticks missed in the background.
            let isLate = ContinuousClock.now - deadline > tick / 2
            if scenePhase == .active && !isLate {
                haptics.play(duration: second == 60 ? 0.8 : 0.1)
            }
        }

        // Show 60 for one more tick before going back to "start".
        try await Task.sleep(until: start + tick * 61)
        seconds = nil
    }
}

/// Padding that keeps content on one side of the iPhone Duo's fold. The fold is only reported
/// while the device is partially open, so elsewhere both are zero and content stays centered.
private struct FoldSides: Equatable {
    /// Keeps content left of the fold (or above it, when the fold runs sideways).
    var first = EdgeInsets()
    /// Keeps content right of the fold (or below it).
    var second = EdgeInsets()

    init() {}

    init(_ proxy: GeometryProxy) {
        guard let fold = proxy.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed)
            .first(where: \.isActive)?.frame else { return }
        if fold.height > fold.width {
            first.trailing = proxy.size.width - fold.minX
            second.leading = fold.maxX
        } else {
            first.bottom = proxy.size.height - fold.minY
            second.top = fold.maxY
        }
    }
}

#Preview {
    ContentView()
}
