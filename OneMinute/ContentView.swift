//
//  ContentView.swift
//  OneMinute
//
//  Created by Thomas on 09/10/2023.
//

import ActivityKit
import SwiftUI

/// Dev flag: set to `true` to count every 0.05 s instead of every second.
private let fastMode = false

struct ContentView: View {
    /// Seconds counted so far, or `nil` when the timer isn't running.
    @State private var seconds: Int?
    @State private var haptics = Haptics()
    @State private var foldSides = FoldSides()
    @Environment(\.scenePhase) private var scenePhase
    /// Mirrors `scenePhase` for the counting task: environment values read from inside a task
    /// keep the value they had when it started, while state is always current.
    @State private var isActive = true
    /// Height of the strip along the bottom edge where swiping goes home.
    @State private var homeIndicatorHeight: CGFloat = 0
    /// Distance from the display's edges to the corner brackets, which frame the text.
    @State private var indicatorInset: CGFloat = 20
    /// Where the current touch started, once it has moved too far to count as a tap.
    @State private var cancelledTouch: CGPoint?
    /// Where the finger is while a touch can still become a tap.
    @State private var press: CGPoint?
    /// Where the last tap landed, and how many there have been, for the ripple and the green flood.
    @State private var tapLocation = CGPoint.zero
    @State private var tapCount = 0

    private var isRunning: Bool { seconds != nil }

    var body: some View {
        Group {
            if let seconds {
                // Sized for one digit, filling the space; two digits shrink to fit side by side.
                RollingNumber(value: seconds, tracking: -0.2, overhang: 0.07)
            } else {
                Text("start")
            }
        }
        // Far too big for any display, then shrunk to fill the space between the corner brackets.
        .font(.system(size: 1000, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.01)
        // Out to the outer edges of the brackets' lines, which are 8 pt wide.
        .padding(indicatorInset - 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A hint that tapping again stops the timer.
        .overlay(alignment: .bottom) {
            if isRunning {
                // Sitting on the bottom edge of the lower brackets' lines, which are 8 pt wide.
                Text("stop")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .alignmentGuide(.bottom) { $0[.lastTextBaseline] }
                    .padding(.bottom, indicatorInset - 4)
            }
        }
        // On a partially open iPhone Duo: "start" on the right side, the count on the left.
        .padding(isRunning ? foldSides.first : foldSides.second)
        .onGeometryChange(for: FoldSides.self, of: FoldSides.init) { foldSides = $0 }
        .onGeometryChange(for: CGFloat.self, of: \.tappableIndicatorsInset) { indicatorInset = $0 }
        // Black while running, like the Dynamic Island.
        .tappableIndicators(color: isRunning ? .black : .primary)
        // Green floods out from the tap that starts the timer, and drains into the one that stops it.
        .background { Flood(isFilled: isRunning, origin: tapLocation, color: .green) }
        .pressFeedback(at: press, glow: isRunning ? .white : .primary, rippleFrom: tapLocation, rippleTrigger: tapCount)
        // Leave out the strip by the home indicator, so swiping home doesn't stop the timer.
        .contentShape(HitArea(bottomInset: homeIndicatorHeight))
        .gesture(tap)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, toggle)
        // Black on green while running, regardless of dark mode.
        .foregroundStyle(isRunning ? Color.black : Color.primary)
        // Cover the whole display; the indicators follow its rounded corners.
        .ignoresSafeArea()
        // Measured outside `ignoresSafeArea`, where the safe area is still reported.
        .onGeometryChange(for: CGFloat.self, of: \.safeAreaInsets.bottom) { homeIndicatorHeight = $0 }
        .statusBarHidden()
        .animation(.easeInOut, value: isRunning)
        .onChange(of: scenePhase, initial: true) { isActive = scenePhase == .active }
        .task(id: isRunning) {
            // Restarted whenever the timer starts or stops; stopping cancels the count.
            guard isRunning else { return }
            // Read both clocks together, before requesting the Live Activity, which can take a
            // while: starting from the same instant keeps the app and the activity in step.
            let start = ContinuousClock.now
            let activity = startLiveActivity(start: .now)
            try? await count(from: start)
            // A separate task, since this one may have been cancelled by stopping the timer.
            Task { await activity?.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func toggle() {
        seconds = isRunning ? nil : 0
    }

    /// Toggles the timer on a plain tap only. Unlike a button, which fires as long as the finger
    /// lifts inside it, any touch that moves (a swipe home, or pressing and sliding away to back
    /// out) is cancelled for good, even if it comes back to where it started.
    private var tap: some Gesture {
        let slop: CGFloat = 10
        return DragGesture(minimumDistance: 0)
            .onChanged { value in
                if hypot(value.translation.width, value.translation.height) > slop {
                    cancelledTouch = value.startLocation
                }
                press = cancelledTouch == value.startLocation ? nil : value.location
            }
            .onEnded { value in
                defer {
                    cancelledTouch = nil
                    press = nil
                }
                guard cancelledTouch != value.startLocation,
                      hypot(value.translation.width, value.translation.height) <= slop else { return }
                tapLocation = value.location
                tapCount += 1
                if isActive { haptics.ripple() }
                toggle()
            }
    }

    /// Shows the timer on the Lock Screen and in the Dynamic Island, where the system keeps
    /// counting even while the app is suspended. Returns `nil` if Live Activities are turned off.
    private func startLiveActivity(start: Date) -> Activity<TimerActivityAttributes>? {
        // End any activity left behind, for example by a minute that ran out while suspended.
        for activity in Activity<TimerActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        let attributes = TimerActivityAttributes(start: start)
        let content = ActivityContent(
            state: TimerActivityAttributes.ContentState(),
            staleDate: attributes.interval.upperBound
        )
        return try? Activity.request(attributes: attributes, content: content)
    }

    /// Counts to 60 from `start` with a tick haptic each step and a long one at the end, then stops.
    private func count(from start: ContinuousClock.Instant) async throws {
        let tick: Duration = fastMode ? .milliseconds(50) : .seconds(1)

        for second in 1...60 {
            // Sleeping until a fixed deadline avoids drift and keeps counting real time
            // while the app is in the background.
            let deadline = start + tick * second
            try await Task.sleep(until: deadline)
            seconds = second

            // Skip haptics when inactive, or when catching up on ticks missed in the background.
            let isLate = ContinuousClock.now - deadline > tick / 2
            if isActive && !isLate {
                if second == 60 {
                    haptics.play(duration: 0.8, intensity: 0.7, sharpness: 0.5)
                } else {
                    // A tick that is clearly felt without being harsh.
                    haptics.play(duration: 0.1, intensity: 0.6, sharpness: 0.5)
                }
            }
        }

        // Show 60 for one more tick before going back to "start".
        try await Task.sleep(until: start + tick * 61)
        seconds = nil
    }
}

/// The whole rectangle except a strip of `bottomInset` along its bottom edge.
private struct HitArea: Shape {
    var bottomInset: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(rect.divided(atDistance: bottomInset, from: .maxYEdge).remainder)
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
