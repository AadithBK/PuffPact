//
//  CravingTimerView.swift
//  PuffPact
//

import SwiftUI
import Combine

public struct CravingTimerView: View {
    @EnvironmentObject var state: AppState
    @State private var timeRemaining = 180 // 3 minutes
    @State private var timerRunning = true
    @State private var breathingScale: CGFloat = 1.0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    public var body: some View {
        VStack(spacing: 28) {
            // Drag indicator
            Capsule()
                .frame(width: 36, height: 5)
                .foregroundColor(Color.secondary.opacity(0.4))
                .padding(.top, 12)
            
            Text("Craving Interrupter")
                .font(.title2.bold())
            
            Text("Most acute nicotine cravings peak and subside within 3 to 5 minutes. Breathe with the circle.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 30)
            
            // Breathing Circle
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 200, height: 200)
                    .scaleEffect(breathingScale)
                    .animation(Animation.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathingScale)
                
                Circle()
                    .stroke(Color.blue, lineWidth: 4)
                    .frame(width: 170, height: 170)
                
                VStack(spacing: 4) {
                    Text(formatTime(timeRemaining))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                    Text("Breathe slowly")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 20)
            .onAppear {
                breathingScale = 1.25
            }
            .onReceive(timer) { _ in
                if timerRunning && timeRemaining > 0 {
                    timeRemaining -= 1
                }
            }
            
            Spacer()
            
            // Decision Buttons
            VStack(spacing: 12) {
                Button(action: {
                    // Resisted successfully!
                    state.isCravingTimerActive = false
                }) {
                    Text("I Survived the Craving! 🎉")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                
                Button(action: {
                    // Still smoked, log it with craving marker
                    state.logSmoke(for: state.currentUser.id, cravingUsed: true)
                    state.isCravingTimerActive = false
                }) {
                    Text("I still smoked (Log it honestly)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

