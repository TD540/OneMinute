//
//  TimerView.swift
//  OneMinute
//
//  Created by Thomas on 12/11/2023.
//

import SwiftUI

struct TimerView: View {
    @State private var isTimerRunning = false
    @State private var count = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var haptics = HapticsManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Button(action: toggleTimer) {
            VStack {
                if isTimerRunning {
                    Text(String(count))
                        .font(.system(size: 400))
                        .frame(maxWidth: 400, maxHeight: 400)
                } else {
                    Text("start")
                        .font(.system(size: 100))
                    Text("one minute")
                        .font(.system(size: 25))
                }
            }
            .fontWeight(.bold)
            .fontDesign(.rounded)
            .padding()
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .showTappableIndicators(lineWidth: 8)
            .padding()
        }
        .foregroundColor(.primary)
        .background {
            RoundedRectangle(cornerRadius: 50.0)
                .fill(isTimerRunning ? Color.green : .clear)
        }
        .padding()
        .animation(.easeInOut, value: isTimerRunning)
        .onReceive(timer) { _ in
            updateTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            haptics.restartHaptics()
        }
    }

    private func toggleTimer() {
        isTimerRunning.toggle()
        if isTimerRunning {
            count = 0
        }
    }

    private func updateTimer() {
        if isTimerRunning {
            count += 1
            if count >= 60 {
                isTimerRunning = false
            } else {
                if scenePhase == .active {
                    haptics.playComplexSuccess()
                }
            }
        }
    }

}


#Preview {
    TimerView()
}
