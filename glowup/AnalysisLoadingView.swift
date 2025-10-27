//
//  AnalysisLoadingView.swift
//  glowup
//
//  Created by AI Assistant
//

import SwiftUI

struct AnalysisLoadingView: View {
    let currentStage: String
    
    @State private var rotation: Double = 0
    @State private var currentTipIndex = 0
    
    private let loadingTips = [
        "Go grab a matcha ☕ this takes a couple mins",
        "Worth the wait - AI is analyzing thousands of details",
        "Pro tip: Good lighting = better results next time",
        "Hang tight - mapping your unique features",
        "Almost there - building your personalized roadmap",
        "Fun fact: Each analysis processes 50+ data points",
        "Time for a quick stretch while we work our magic",
        "Your glow-up journey starts in just a moment",
        "We're analyzing facial harmony, skin texture, and more"
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            // Infinite rotating gradient animation
            ZStack {
                Circle()
                    .stroke(GlowPalette.creamyWhite.opacity(0.1), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.94, green: 0.34, blue: 0.56),
                                Color(red: 1.0, green: 0.6, blue: 0.78),
                                Color(red: 0.94, green: 0.34, blue: 0.56)
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
                
                Image(systemName: "sparkles")
                    .font(.glowHeading)
                    .foregroundStyle(Color(red: 0.94, green: 0.34, blue: 0.56))
            }
            
            // Stage indicator
            VStack(spacing: 12) {
                Text(currentStage)
                    .font(.glowSubheading)
                    .deepRoseText()
                    .multilineTextAlignment(.center)
                
                // Rotating tips
                Text(loadingTips[currentTipIndex])
                    .font(.subheadline)
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .id("tip-\(currentTipIndex)")
            }
        }
        .padding()
        .onAppear {
            startTipRotation()
        }
    }
    
    private func startTipRotation() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentTipIndex = (currentTipIndex + 1) % loadingTips.count
            }
        }
    }
}

#Preview {
    ZStack {
        GradientBackground.twilightAura
            .ignoresSafeArea()
        AnalysisLoadingView(currentStage: "Analyzing facial features...")
    }
}
