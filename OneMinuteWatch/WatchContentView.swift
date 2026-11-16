//
//  WatchContentView.swift
//  OneMinuteWatch
//

import SwiftUI
import WatchKit

/// Dev flag: set to `true` to count every 0.05 s instead of every second.
private let fastMode = false

/// The timer on Apple Watch: the whole display is one button, like on iPhone.
struct WatchContentView: View {
    /// Seconds counted so far, or `nil` when the timer isn't running.
    @State private var seconds: Int?
    /// Keeps the app running, and its haptics playing, while the wrist is down.
    @State private var session: WKExtendedRuntimeSession?
    /// The display's safe area, measured outside `ignoresSafeArea`, so the text stays clear of the clock.
    @State private var safeArea = EdgeInsets()
    /// Where the current touch started, once it has moved too far to count as a tap.
    @State private var cancelledTouch: CGPoint?
    /// Where the last tap landed, for the green flood.
    @State private var tapLocation = CGPoint.zero

    private var isRunning: Bool { seconds != nil }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let seconds {
                    RollingNumber(value: seconds, tracking: -0.2, overhang: 0.07)
                } else {
                    Text("start")
                }
            }
            // Far too big for any display, then shrunk to fill the space.
            .font(.system(size: 400, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.01)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // A hint that tapping again stops the timer.
            if isRunning {
                Text("stop")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            }
        }
        .padding(safeArea)
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Green floods out from the tap that starts the timer, and drains into the one that stops it.
        .background { Flood(isFilled: isRunning, origin: tapLocation, color: .green) }
        .contentShape(.rect)
        .gesture(tap)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, toggle)
        // Black on green while running.
        .foregroundStyle(isRunning ? Color.black : Color.primary)
        // Cover the whole display, so the flood reaches its corners.
        .ignoresSafeArea()
        .onGeometryChange(for: EdgeInsets.self, of: \.safeAreaInsets) { safeArea = $0 }
        .animation(.easeInOut, value: isRunning)
        .task(id: isRunning) {
            // Restarted whenever the timer starts or stops; stopping cancels the count.
            guard isRunning else { return }
            let start = ContinuousClock.now
            startSession()
            defer { endSession() }
            try? await count(from: start)
        }
    }

    private func toggle() {
        WKInterfaceDevice.current().play(isRunning ? .stop : .start)
        seconds = isRunning ? nil : 0
    }

    /// Toggles the timer on a plain tap only: any touch that moves, like a swipe, is cancelled
    /// for good, even if it comes back to where it started.
    private var tap: some Gesture {
        let slop: CGFloat = 6
        return DragGesture(minimumDistance: 0)
            .onChanged { value in
                if hypot(value.translation.width, value.translation.height) > slop {
                    cancelledTouch = value.startLocation
                }
            }
            .onEnded { value in
                defer { cancelledTouch = nil }
                guard cancelledTouch != value.startLocation,
                      hypot(value.translation.width, value.translation.height) <= slop else { return }
                tapLocation = value.location
                toggle()
            }
    }

    /// Starts a self-care session, which keeps the app frontmost and counting, with haptics,
    /// when the wrist goes down. Without one, the app is suspended and the ticks are missed.
    private func startSession() {
        let session = WKExtendedRuntimeSession()
        session.start()
        self.session = session
    }

    private func endSession() {
        if session?.state == .running {
            session?.invalidate()
        }
        session = nil
    }

    /// Counts to 60 from `start` with a tap each step and the strongest haptic at the end, then stops.
    private func count(from start: ContinuousClock.Instant) async throws {
        let tick: Duration = fastMode ? .milliseconds(50) : .seconds(1)
        let device = WKInterfaceDevice.current()

        for second in 1...60 {
            // Sleeping until a fixed deadline avoids drift.
            let deadline = start + tick * second
            try await Task.sleep(until: deadline)
            seconds = second

            // Skip haptics when catching up on ticks missed while suspended.
            let isLate = ContinuousClock.now - deadline > tick / 2
            if !isLate {
                // The firmest short tap for each second; apps can choose a haptic but not its strength.
                device.play(second == 60 ? .notification : .start)
            }
        }

        // Show 60 for one more tick before going back to "start".
        try await Task.sleep(until: start + tick * 61)
        seconds = nil
    }
}

#Preview {
    WatchContentView()
}
