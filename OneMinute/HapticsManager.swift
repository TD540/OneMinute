//
//  HapticsManager.swift
//  OneMinute
//
//  Created by thomas on 22/11/2023.
//

import CoreHaptics

class HapticsManager {
    private var engine: CHHapticEngine?

    init() {
        prepareHaptics()
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Error starting the haptic engine: \(error)")
        }
    }

    func playTimerEndHaptic() {
        playHaptic(intensity: 1.0, duration: 0.8)
    }

    func playHaptic(intensity: Float = 1.0, sharpness: Float = 1.0, delay: TimeInterval = 0.0, duration: TimeInterval = 0.1) {
        guard let engine = engine, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        let intensityParameter = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParameter = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensityParameter, sharpnessParameter], relativeTime: delay, duration: duration)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Error playing haptic pattern: \(error)")
        }
    }

    func restartHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            engine?.stop()
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Error restarting the haptic engine: \(error)")
        }
    }
}
