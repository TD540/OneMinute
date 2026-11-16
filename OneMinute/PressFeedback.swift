//
//  PressFeedback.swift
//  OneMinute
//

import SwiftUI

extension View {
    /// Feedback for a view that fills the screen and acts as one big button. While pressed, the
    /// view sinks a little and tilts away under the finger, like a card pressed off-center, with
    /// a soft glow at the fingertip. Each change of `rippleTrigger` sends a ripple out from
    /// `rippleOrigin`, as if a drop fell there.
    ///
    /// - Parameters:
    ///   - press: Where the finger is, in the view's coordinates, or `nil` when not pressed.
    ///   - glow: The color of the light under the finger.
    func pressFeedback(
        at press: CGPoint?,
        glow: Color,
        rippleFrom rippleOrigin: CGPoint,
        rippleTrigger: Int
    ) -> some View {
        modifier(PressFeedback(press: press, glow: glow, rippleOrigin: rippleOrigin, rippleTrigger: rippleTrigger))
    }
}

private struct PressFeedback: ViewModifier {
    var press: CGPoint?
    var glow: Color
    var rippleOrigin: CGPoint
    var rippleTrigger: Int

    /// Where the finger was last, so the glow and tilt fade out in place after it lifts.
    @State private var lastPress = CGPoint.zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isPressed: Bool { press != nil }

    func body(content: Content) -> some View {
        content
            .overlay {
                // Light under the fingertip, brightening what's below it.
                Circle()
                    .fill(RadialGradient(colors: [glow.opacity(0.45), glow.opacity(0)], center: .center, startRadius: 0, endRadius: 180))
                    .frame(width: 360, height: 360)
                    .position(lastPress)
                    .opacity(isPressed ? 1 : 0)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
            .keyframeAnimator(initialValue: Ripple.duration, trigger: rippleTrigger) { [rippleOrigin, reduceMotion] view, elapsed in
                view.modifier(Ripple(origin: rippleOrigin, elapsed: reduceMotion ? Ripple.duration : elapsed))
            } keyframes: { _ in
                MoveKeyframe(0)
                LinearKeyframe(Ripple.duration, duration: Ripple.duration)
            }
            // Rounded like the display, so the corners show as the view sinks.
            .clipShape(ConcentricRectangle())
            .visualEffect { [lastPress, isPressed, reduceMotion] content, proxy in
                // How far off-center the finger is, from -1 to 1 on each axis; zero once released,
                // so the tilt springs back to flat.
                let pull = isPressed && !reduceMotion ? 1.0 : 0.0
                let x = (lastPress.x / max(proxy.size.width, 1) - 0.5) * 2 * pull
                let y = (lastPress.y / max(proxy.size.height, 1) - 0.5) * 2 * pull
                let maxTilt = 10.0
                return content
                    .scaleEffect(isPressed ? 0.95 : 1)
                    // Tilt the side under the finger away, one axis at a time so both animate smoothly.
                    .rotation3DEffect(.degrees(-y * maxTilt), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
                    .rotation3DEffect(.degrees(x * maxTilt), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            }
            .animation(.spring(duration: 0.35, bounce: 0.4), value: isPressed)
            .animation(.interactiveSpring, value: lastPress)
            .onChange(of: press, initial: true) {
                if let press { lastPress = press }
            }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: isPressed) { _, pressed in pressed }
    }
}

/// Distorts a view with the `ripple` shader at a moment in the ripple's life.
private struct Ripple: ViewModifier {
    nonisolated static let duration: TimeInterval = 2

    var origin: CGPoint
    var elapsed: TimeInterval

    private let amplitude: Double = 14
    private let frequency: Double = 15
    private let decay: Double = 6
    private let speed: Double = 1400

    func body(content: Content) -> some View {
        content.visualEffect { [origin, elapsed, amplitude, frequency, decay, speed] view, _ in
            view.layerEffect(
                ShaderLibrary.ripple(
                    .float2(origin),
                    .float(elapsed),
                    .float(amplitude),
                    .float(frequency),
                    .float(decay),
                    .float(speed)
                ),
                maxSampleOffset: CGSize(width: amplitude, height: amplitude),
                // Skips the shader entirely when no ripple is running.
                isEnabled: 0 < elapsed && elapsed < Self.duration
            )
        }
    }
}

/// A color that floods out from a point until it covers the view, and drains back into it.
struct Flood: View {
    var isFilled: Bool
    var origin: CGPoint
    var color: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // Just large enough to reach the corner farthest from the origin.
            let radius = [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
                .map { hypot($0.x - origin.x, $0.y - origin.y) }
                .max() ?? 0
            Circle()
                .fill(color)
                .frame(width: radius * 2, height: radius * 2)
                .scaleEffect(isFilled ? 1 : 0.001)
                .position(origin)
        }
        .allowsHitTesting(false)
    }
}

#Preview("Pressed top right") {
    Text("12")
        .font(.system(size: 200, weight: .semibold))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.green)
        .pressFeedback(at: CGPoint(x: 330, y: 120), glow: .white, rippleFrom: .zero, rippleTrigger: 0)
        .ignoresSafeArea()
}
