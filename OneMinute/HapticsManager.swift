//
//  HapticsManager.swift
//  OneMinute
//
//  Created by thomas on 22/11/2023.
//

import AVFoundation
import CoreHaptics
import OSLog

class HapticsManager: NSObject {
    private var engine: CHHapticEngine?
    private var volumeObservation: NSKeyValueObservation?
    private var currentVolume = AVAudioSession.sharedInstance().outputVolume

    override init() {
        super.init()
        configureAudioSession()
        prepareHaptics()
        observeVolumeChanges()
    }

    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.ambient)
            try audioSession.setActive(true)
        } catch {
            Logger.haptics.error("Error configuring audio session: \(error.localizedDescription)")
        }
    }

    private func prepareHaptics() {
            guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
                Logger.haptics.warning("Haptics not supported on this device.")
                return
            }
            do {
                engine = try CHHapticEngine()
                try engine?.start()
            } catch {
                Logger.haptics.error("Error starting the haptic engine: \(error.localizedDescription)")
            }
        }

    private func observeVolumeChanges() {
        volumeObservation = AVAudioSession.sharedInstance().observe(\.outputVolume) { [weak self] avSession, _ in
            self?.currentVolume = avSession.outputVolume
            Logger.haptics.debug("Volume changed: \(avSession.outputVolume)")
        }
    }

    func playTimerEndHaptic() {
        playHaptic(duration: 0.8)
    }

    func playHaptic(sharpness: Float = 1.0, delay: TimeInterval = 0.0, duration: TimeInterval = 0.1) {
        guard let engine = engine, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        let intensity = currentVolume
        let intensityParameter = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParameter = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensityParameter, sharpnessParameter], relativeTime: delay, duration: duration)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            Logger.haptics.error("Error playing haptic pattern: \(error.localizedDescription)")
        }
    }

    func restartHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            engine?.stop()
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            Logger.haptics.error("Error restarting the haptic engine: \(error.localizedDescription)")
        }
    }

    deinit {
        volumeObservation?.invalidate()
    }

}
