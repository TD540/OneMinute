//
//  TimerView.swift
//  OneMinute
//
//  Created by Thomas on 12/11/2023.
//

import SwiftUI
import CoreHaptics

struct TimerView: View {
    @State var isTimerRunning = false
    @State private var startTime =  Date()
    @State private var count = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Button {
            if !isTimerRunning {
                count = 0
                startTime = Date()
            }
            isTimerRunning.toggle()
        } label: {
            VStack {
                if isTimerRunning {
                    Text(String(count))
                        .font(.system(size: 200))
                } else {
                    Text("start")
                        .font(.system(size: 200))
                    Text("one minute")
                }
            }
            .fontWeight(.bold)
            .fontDesign(.rounded)
            .padding()
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .showTappableIndicators(lineWidth: 6)
            .padding()
        }
        .onAppear(perform: prepareHaptics)
        .foregroundColor(.primary)
        .background {
            RoundedRectangle(cornerRadius: 20.0)
                .fill(isTimerRunning ? Color.green : .clear)
        }
        .animation(.easeInOut, value: isTimerRunning)
        .onReceive(timer) { _ in
            if isTimerRunning && count < 60 {
                count = Int(Date().timeIntervalSince(startTime))
                self.complexSuccess()
            } else {
                isTimerRunning = false
            }
        }
        .padding()
        .edgesIgnoringSafeArea(.bottom)
    }

    @State private var engine: CHHapticEngine?

    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("There was an error creating the engine: \(error.localizedDescription)")
        }
    }

    func complexSuccess() {
        // make sure that the device supports haptics
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        var events = [CHHapticEvent]()

        // create one intense, sharp tap
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        events.append(event)

        // convert those events into a pattern and play it immediately
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play pattern: \(error.localizedDescription).")
        }
    }

}

#Preview {
    TimerView()
}
