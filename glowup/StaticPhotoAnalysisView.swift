//
//  StaticPhotoAnalysisView.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import Combine
import SwiftUI
import UIKit

struct StaticPhotoAnalysisView: View {
    @EnvironmentObject private var appModel: AppModel
    let persona: CoachPersona
    let bundle: PhotoAnalysisBundle

    @State private var session: PhotoSession?
    @State private var analysisResult: DetailedPhotoAnalysis?
    @State private var isLoading = true
    @State private var isAnalyzing = false
    @State private var lastAttemptFailed = false
    @State private var currentStage = "Preparing images…"
    @State private var loadingStartDate: Date?
    @State private var isStageTimerActive = false
    
    private let stageTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let stageTimeline: [(threshold: TimeInterval, label: String)] = [
        (0, "Preparing images…"),
        (5, "Analyzing facial features…"),
        (30, "Processing skin texture…"),
        (60, "Generating personalized insights…"),
        (90, "Finalizing recommendations…")
    ]
    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground.twilightAura
                    .ignoresSafeArea()
                VStack(spacing: 24) {
                    if let image = UIImage(data: bundle.face) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Color.white.opacity(0.2))
                            )
                            .shadow(color: .black.opacity(0.2), radius: 20, y: 12)
                    }

                    if isLoading {
                        AnalysisLoadingView(currentStage: currentStage)
                            .padding(.top, 12)
                    } else if shouldShowStartPrompt {
                        startAnalysisPrompt
                    } else {
                        analysisSummary
                    }

                    Spacer()
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Analysis Result")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
        .task {
            await analyzePhoto()
        }
        .onReceive(stageTimer) { _ in
            guard isStageTimerActive, let start = loadingStartDate else { return }
            let elapsed = Date().timeIntervalSince(start)
            let nextStage = stageLabel(for: elapsed)
            if nextStage != currentStage {
                currentStage = nextStage
            }
        }
        .onDisappear {
            endLoadingFeedback()
        }
    }

    private var shouldShowStartPrompt: Bool { lastAttemptFailed }

    private var startAnalysisPrompt: some View {
        VStack(spacing: 20) {
            Text("Let's start your glow analysis.")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button {
                Task { await analyzePhoto() }
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Start Analysis")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.94, green: 0.34, blue: 0.56),
                            Color(red: 1.0, green: 0.6, blue: 0.78)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .disabled(isAnalyzing)
            .opacity(isAnalyzing ? 0.6 : 1.0)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }

    @ViewBuilder
    private var analysisSummary: some View {
        if let session {
            VStack(alignment: .leading, spacing: 20) {
                // Glow Score
                HStack {
                    Text("Glow Score")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("\(Int((session.confidenceScore ?? 0) * 100))%")
                        .font(.title2.bold())
                        .foregroundStyle(Color(red: 0.94, green: 0.34, blue: 0.56))
                }

                // AI Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Analysis")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(session.aiSummary ?? "Your glow plan is ready.")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
                
                // Detailed Analysis Button
                if let analysisResult {
                    NavigationLink {
                        DetailedFeedbackView(analysis: analysisResult)
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("View Detailed Analysis")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.94, green: 0.34, blue: 0.56),
                                    Color(red: 1.0, green: 0.6, blue: 0.78)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                } else {
                    Text("Detailed insights will appear once the analysis completes successfully.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
        } else {
            Text("Tap Start Analysis to generate your personalized glow breakdown.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func analyzePhoto() async {
        guard !isAnalyzing else { return }
        lastAttemptFailed = false
        isAnalyzing = true
        isLoading = true
        beginLoadingFeedback()
        session = nil
        analysisResult = nil
        
        let service = PhotoAnalysisService(persistenceController: appModel.persistenceController)
        let quiz = appModel.latestQuiz.map(QuizResult.init(from:))
        let delays: [TimeInterval] = [0, 2, 4]
        var finalResult: AnalysisPipelineResult?
        
        for attempt in 0..<delays.count {
            if attempt > 0 {
                let delay = delays[attempt]
                let nanos = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
            }
            
            let result = await service.analyzePhoto(bundle: bundle, persona: persona, quiz: quiz)
            finalResult = result
            
            if result.analysis.isFallback == false {
                break
            }
        }
        
        if let finalResult {
            if finalResult.analysis.isFallback {
                lastAttemptFailed = true
            } else {
                session = finalResult.session
                analysisResult = finalResult.analysis
                lastAttemptFailed = false
                appModel.logSession()
            }
        } else {
            lastAttemptFailed = true
        }
        isLoading = false
        isAnalyzing = false
        endLoadingFeedback()
    }
    
    private func beginLoadingFeedback() {
        loadingStartDate = Date()
        currentStage = stageTimeline.first?.label ?? "Preparing images…"
        isStageTimerActive = true
    }
    
    private func endLoadingFeedback() {
        isStageTimerActive = false
        loadingStartDate = nil
    }
    
    private func stageLabel(for elapsed: TimeInterval) -> String {
        var label = stageTimeline.first?.label ?? "Preparing images…"
        for entry in stageTimeline {
            if elapsed >= entry.threshold {
                label = entry.label
            } else {
                break
            }
        }
        return label
    }
}
