//
//  Haptics.swift
//  OneMinute
//

import CoreHaptics

/// Plays continuous buzzes of a given length. Does nothing on devices without haptics.
final class Haptics {
    private let engine: CHHapticEngine? = {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = try? CHHapticEngine() else { return nil }
        // Let the engine power down while idle, e.g. between timer runs.
        engine.isAutoShutdownEnabled = true
        engine.playsHapticsOnly = true
        return engine
    }()

    func play(duration: TimeInterval) {
        guard let engine else { return }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
            ],
            relativeTime: 0,
            duration: duration
        )
        do {
            // Starting an already running engine is harmless, and this restarts it
            // after it shut down while idle or the system stopped it.
            try engine.start()
            let player = try engine.makePlayer(with: CHHapticPattern(events: [event], parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are a nice-to-have, so failures are ignored.
        }
    }
}
