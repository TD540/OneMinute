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
    /// When the timer started, here or on iPhone, or `nil` when it isn't running.
    @State private var startDate: Date?
    private let sync = TimerSync.shared
    /// Keeps the app running, and its haptics playing, while the wrist is down.
    @State private var session: WKExtendedRuntimeSession?
    /// Distance from the display's edges to the corner brackets, which frame the text.
    @State private var indicatorInset: CGFloat = 20
    /// Where the current touch started, once it has moved too far to count as a tap.
    @State private var cancelledTouch: CGPoint?
    /// Where the last tap landed, for the green flood.
    @State private var tapLocation = CGPoint.zero

    private var isRunning: Bool { startDate != nil }
    /// Thinner than on iPhone, to suit the smaller display.
    private let lineWidth: CGFloat = 6

    var body: some View {
        Group {
            if let seconds {
                RollingNumber(value: seconds, tracking: -0.2, overhang: 0.07)
            } else {
                Text("start")
            }
        }
        // Far too big for any display, then shrunk to fill the space between the corner brackets.
        .font(.system(size: 400, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.01)
        // Out to the outer edges of the brackets' lines.
        .padding(indicatorInset - lineWidth / 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A hint that tapping again stops the timer.
        .overlay(alignment: .bottom) {
            if isRunning {
                // Sitting on the bottom edge of the lower brackets' lines.
                Text("stop")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .alignmentGuide(.bottom) { $0[.lastTextBaseline] }
                    .padding(.bottom, indicatorInset - lineWidth / 2)
            }
        }
        .onGeometryChange(for: CGFloat.self, of: \.tappableIndicatorsInset) { indicatorInset = $0 }
        // Black while running.
        .tappableIndicators(color: isRunning ? .black : .primary, lineWidth: lineWidth)
        // Green floods out from the tap that starts the timer, and drains into the one that stops it.
        .background { Flood(isFilled: isRunning, origin: tapLocation, color: .green) }
        .contentShape(.rect)
        .gesture(tap)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, toggle)
        // Black on green while running.
        .foregroundStyle(isRunning ? Color.black : Color.primary)
        // Cover the whole display; the flood reaches its corners and the brackets follow them.
        .ignoresSafeArea()
        // Hides the clock, which would otherwise sit on the top-right bracket. Undocumented API.
        ._statusBarHidden(true)
        .animation(.easeInOut, value: isRunning)
        .onChange(of: sync.received, initial: true) { follow(sync.received) }
        .task(id: startDate) {
            // Restarted whenever the timer starts or stops; stopping cancels the count.
            guard let startDate else { return }
            // The start on the steady clock; in the past when following a start on iPhone.
            let start = ContinuousClock.now - .seconds(Date.now.timeIntervalSince(startDate))
            startSession()
            defer { endSession() }
            try? await count(from: start)
        }
    }

    private func toggle() {
        WKInterfaceDevice.current().play(isRunning ? .stop : .start)
        let now = Date.now
        if isRunning {
            stop()
            sync.send(.init(kind: .stop, date: now))
        } else {
            startDate = now
            seconds = 0
            sync.send(.init(kind: .start, date: now))
        }
    }

    private func stop() {
        startDate = nil
        seconds = nil
    }

    /// Starts or stops along with iPhone.
    private func follow(_ event: TimerSync.Event?) {
        guard let event else { return }
        switch event.kind {
        case .start:
            let elapsed = Date.now.timeIntervalSince(event.date)
            // Skip a minute that's already over, or the same or a later start than this one's.
            // Following only earlier starts settles both devices on the first one.
            guard elapsed < 61 else { return }
            if let startDate, startDate <= event.date { return }
            startDate = event.date
            seconds = min(max(Int(elapsed), 0), 60)
        case .stop:
            // Only a stop of this timer, not one from before it started.
            guard let startDate, event.date > startDate else { return }
            stop()
        }
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
        stop()
    }
}

#Preview {
    WatchContentView()
}
