//
//  ContentView.swift
//  OneMinute
//
//  Created by Thomas on 09/10/2023.
//

import SwiftUI

struct ContentView: View {
    @State private var timer: Timer?
    @State private var count: Int = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Button {
                if timer == nil {
                    startTimer()
                } else {
                    stopTimer()
                }
            } label: {
                Text("\(count)")
                    .font(.system(size: 200, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(10.0)
            }
            if timer != nil {
                Button {
                    stopTimer()
                } label: {
                    Text("stop")
                }
            } else {
                Text("start")
            }
        }
        .foregroundStyle(.primary)
        .padding()
    }
    
    func startTimer() {
        stopTimer()
        count = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if count < 60 {
                count += 1
            } else {
                stopTimer()
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        count = 0
    }
}


#Preview {
    ContentView()
}
