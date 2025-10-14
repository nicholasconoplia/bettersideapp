//
//  GlowProfileView.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import SwiftUI

struct GlowProfileView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        entity: GlowProfile.entity(),
        sortDescriptors: [],
        animation: .easeInOut
    ) private var profiles: FetchedResults<GlowProfile>

    @State private var showReanalysisMessage = false

    private var profile: GlowProfile? {
        profiles.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground.twilightAura
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        infoGrid
                        confidenceHistory
                        reanalysisButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Glow Profile")
            .alert("Re-run analysis coming soon", isPresented: $showReanalysisMessage) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("We’ll refresh your profile with the next GPT-4 photo analysis session.")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("Your Glow Blueprint")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("All the lasting insights GPT-4 Vision has learned about your vibe.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
    }

    private var infoGrid: some View {
        VStack(spacing: 16) {
            profileRow(
                title: "Face Shape",
                value: profile?.faceShape ?? "We’ll identify this after your first analysis."
            )
            profileRow(
                title: "Skin Undertone",
                value: undertoneGuess
            )
            profileRow(
                title: "Seasonal Palette",
                value: profile?.colorPalette ?? "Warm, cool, or neutral? We’ll decode it soon."
            )
            profileRow(
                title: "Best Angles",
                value: bestAngleCopy
            )
            profileRow(
                title: "Lighting Mastery",
                value: profile?.optimalLightingDesc ?? "Your lighting plan unlocks after a few sessions."
            )
        }
    }

    private func profileRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }

    private var confidenceHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Confidence Score History")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Your glow score evolves with every photo session.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.97, green: 0.56, blue: 0.76),
                            Color(red: 0.62, green: 0.4, blue: 0.88)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 120)
                .overlay(
                    Text("Charts coming soon")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var reanalysisButton: some View {
        Button {
            showReanalysisMessage = true
        } label: {
            Text("Re-run Analysis")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(red: 0.94, green: 0.34, blue: 0.56))
                        .shadow(color: Color.black.opacity(0.2), radius: 16, y: 10)
                )
                .foregroundStyle(.white)
        }
        .padding(.top)
    }

    private var undertoneGuess: String {
        if let quiz = appModel.latestQuiz,
           let answers = quiz.answers as? [String: [String]],
           let undertone = answers["color_preferences"]?.first {
            switch undertone {
            case "warm":
                return "Warm undertone leaning sunlit gold."
            case "cool":
                return "Cool undertone with icy luminosity."
            case "neutral":
                return "Neutral undertone—flexible for any palette."
            default:
                return "We’ll dial in your undertone soon."
            }
        }
        return "We’ll dial in your undertone soon."
    }

    private var bestAngleCopy: String {
        if let tilt = profile?.bestAngleTilt {
            return "A \(Int(tilt))° chin tilt with soft shoulders unlocked your glow."
        }
        return "Your coach will learn your signature angles as you submit more photo analyses."
    }
}
