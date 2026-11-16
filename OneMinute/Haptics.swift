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

    func play(duration: TimeInterval, intensity: Float = 1, sharpness: Float = 1) {
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0,
            duration: duration
        )
        play([event])
    }

    /// A tap followed by fading pulses, felt as the ripple's waves passing under the finger.
    /// Mirrors the ripple shader: crests come every π / frequency seconds, shrinking by its decay.
    func ripple(frequency: Double = 15, decay: Double = 6) {
        let crestInterval = Double.pi / frequency
        let events = (0..<4).map { crest in
            let time = Double(crest) * crestInterval
            let strength = exp(-decay * time)
            return CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(0.9 * strength)),
                    // Softer as the waves fade.
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(0.2 + 0.4 * strength))
                ],
                relativeTime: time
            )
        }
        play(events)
    }

    private func play(_ events: [CHHapticEvent]) {
        guard let engine else { return }
        do {
            // Starting an already running engine is harmless, and this restarts it
            // after it shut down while idle or the system stopped it.
            try engine.start()
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are a nice-to-have, so failures are ignored.
        }
    }
}
