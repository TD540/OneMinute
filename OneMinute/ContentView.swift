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
    /// When the timer started, here or on Apple Watch, or `nil` when it isn't running.
    @State private var startDate: Date?
    private let sync = TimerSync.shared
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

    private var isRunning: Bool { startDate != nil }

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
        .onChange(of: sync.received, initial: true) { follow(sync.received) }
        .task(id: startDate) {
            // Restarted whenever the timer starts or stops; stopping cancels the count.
            guard let startDate else { return }
            // The start on the steady clock, worked out before requesting the Live Activity,
            // which can take a while. In the past when following a start on Apple Watch.
            let start = ContinuousClock.now - .seconds(Date.now.timeIntervalSince(startDate))
            let activityID = startLiveActivity(start: startDate)
            // Suspended apps don't run, so ask for extra time after leaving the app to end the
            // activity when the minute runs out. iOS grants about 30 seconds.
            let backgroundTask = BackgroundTask(name: "Minute")
            let finished = (try? await count(from: start)) != nil
            // Linger for 5 seconds after a minute that ran out; vanish at once when stopped early.
            // A date already past, after catching up on a minute that ran out while suspended,
            // removes it at once too.
            let dismissalPolicy: ActivityUIDismissalPolicy =
                finished ? .after(startDate.addingTimeInterval(65)) : .immediate
            // A separate task, since this one may have been cancelled by stopping the timer.
            Task {
                if let activityID {
                    await Self.endLiveActivities([activityID], dismissalPolicy: dismissalPolicy)
                }
                backgroundTask.end()
            }
        }
    }

    private func toggle() {
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

    /// Starts or stops along with Apple Watch.
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
    /// counting even while the app is suspended. Returns the activity's ID, or `nil` if Live
    /// Activities are turned off.
    private func startLiveActivity(start: Date) -> String? {
        // End any activity left behind, for example by a minute that ran out while suspended,
        // in the background so the new activity isn't held up waiting for them. Collected by ID
        // before the request, so the new activity is never among them.
        let staleIDs = Set(Activity<TimerActivityAttributes>.activities.map(\.id))
        if !staleIDs.isEmpty {
            Task { await Self.endLiveActivities(staleIDs) }
        }
        let attributes = TimerActivityAttributes(start: start)
        let content = ActivityContent(
            state: TimerActivityAttributes.ContentState(),
            staleDate: attributes.interval.upperBound
        )
        return try? Activity.request(attributes: attributes, content: content).id
    }

    /// Ends the timer's Live Activities with the given IDs. Activities aren't `Sendable`, so
    /// they're looked up here, off the main actor, rather than handed over from it.
    @concurrent
    private static func endLiveActivities(
        _ ids: Set<String>,
        dismissalPolicy: ActivityUIDismissalPolicy = .immediate
    ) async {
        for activity in Activity<TimerActivityAttributes>.activities where ids.contains(activity.id) {
            await activity.end(nil, dismissalPolicy: dismissalPolicy)
        }
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
        stop()
    }
}

/// Extra time to keep running after the app leaves the foreground, until `end()` is called or
/// iOS's allowance runs out.
private final class BackgroundTask {
    private var id = UIBackgroundTaskIdentifier.invalid

    init(name: String) {
        id = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.end()
        }
    }

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}

/// The whole rectangle except a strip of `bottomInset` along its bottom edge.
nonisolated private struct HitArea: Shape {
    var bottomInset: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(rect.divided(atDistance: bottomInset, from: .maxYEdge).remainder)
    }
}

/// Padding that keeps content on one side of the iPhone Duo's fold. The fold is only reported
/// while the device is partially open, so elsewhere both are zero and content stays centered.
nonisolated private struct FoldSides: Equatable {
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
