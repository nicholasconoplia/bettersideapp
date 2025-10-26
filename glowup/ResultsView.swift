//
//  ResultsView.swift
//  glowup
//
//  Created by Codex on 16/10/2025.
//

import SwiftUI
import CoreData
import UIKit

struct ResultsSheetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var visualizationViewModel: VisualizationViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @AppStorage("hasUsedFreeScan") private var hasUsedFreeScan = false

    @FetchRequest(
        entity: PhotoSession.entity(),
        sortDescriptors: [NSSortDescriptor(key: "startTime", ascending: false)],
        animation: .easeInOut
    ) private var sessions: FetchedResults<PhotoSession>

    @State private var expandedSessions: Set<NSManagedObjectID> = []
    @State private var showClearConfirmation = false

    init() {}

    var body: some View {
        NavigationStack {
            ZStack {
                GlowGradient.canvas
                    .ignoresSafeArea()

                if sessions.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(sessions, id: \.objectID) { session in
                                sessionCard(for: session)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationTitle("Previous Analyses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    clearHistoryButton
                }
            }
            .onAppear {
                if let first = sessions.first {
                    expandedSessions.insert(first.objectID)
                }
            }
            .alert("Clear All History?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clearAllHistory()
                }
            } message: {
                Text("This will permanently delete all \(sessions.count) saved analysis result\(sessions.count == 1 ? "" : "s"). This action cannot be undone.")
            }
        }
    }

    // MARK: - Session Cards

    private func sessionCard(for session: PhotoSession) -> some View {
        let binding = Binding(
            get: { expandedSessions.contains(session.objectID) },
            set: { expanded in
                if expanded {
                    expandedSessions.insert(session.objectID)
                } else {
                    expandedSessions.remove(session.objectID)
                }
            }
        )

        return DisclosureGroup(isExpanded: binding) {
            VStack(spacing: 16) {
                if let image = session.uploadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 14, y: 10)
                }

                if let analysis = session.decodedAnalysis {
                    DetailedFeedbackView(
                        analysis: analysis,
                        annotatedImage: nil,
                        showAnnotatedImage: false,
                        showsNavigationTitle: false
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    if subscriptionManager.isSubscribed {
                        visualizeButton(for: session)
                    }
                } else {
                    missingAnalysisSection
                }
            }
            .padding(.top, 12)
        } label: {
            sessionHeader(for: session)
        }
        .padding(20)
        .background(GlowPalette.softBeige)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(GlowPalette.roseGold.opacity(0.25), lineWidth: 1)
        )
    }

    private func sessionHeader(for session: PhotoSession) -> some View {
        HStack(alignment: .center, spacing: 16) {
            if let image = session.uploadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.2))
                    )
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(dateLabel(for: session))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.75))

                Text(session.sessionType ?? "Static Photo")
                    .font(.headline)
                    .foregroundStyle(GlowPalette.deepRose)

                if let summary = session.aiSummary {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.75))
                        .lineLimit(3)
                }
            }

            Spacer()

            let confidence = session.confidenceScore
            if confidence > 0 {
                VStack(spacing: 4) {
                    Text("\(Int(confidence * 100))")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(GlowPalette.deepRose)
                    Text("Glow")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.65))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(GlowPalette.blushPink.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    // MARK: - Toolbar

    private var clearHistoryButton: some View {
        Button {
            showClearConfirmation = true
        } label: {
            Image(systemName: "trash")
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
        }
        .disabled(sessions.isEmpty)
    }

    // MARK: - States & Helpers

    private func dateLabel(for session: PhotoSession) -> String {
        guard let date = session.startTime else { return "Unknown date" }
        return Self.dateFormatter.string(from: date)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.75))

            Text("No analyses yet")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Upload a photo and tap Start Analysis to unlock your glow insights. Every successful session will be saved here automatically.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 40)
        }
    }

    private var missingAnalysisSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.yellow)
            Text("Analysis unavailable for this session.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text("Run a fresh photo analysis to capture a complete result.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08))
        .cornerRadius(18)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func visualizeButton(for session: PhotoSession) -> some View {
        Button {
            if subscriptionManager.isSubscribed {
                visualizeSession(session)
            } else if hasUsedFreeScan {
                SuperwallService.shared.registerEvent("subscription_paywall")
            } else {
                visualizeSession(session)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.headline.weight(.semibold))
                Text("Visualize This Look")
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private func visualizeSession(_ session: PhotoSession) {
        visualizationViewModel.prepareLaunch(from: session)
    }

    private func clearAllHistory() {
        withAnimation {
            for session in sessions {
                viewContext.delete(session)
            }

            UserDefaults.standard.removeObject(forKey: "LatestDetailedAnalysis")
            UserDefaults.standard.removeObject(forKey: "LatestAnalysisIsFallback")
            UserDefaults.standard.removeObject(forKey: "LatestRecommendationPlan")
            UserDefaults.standard.removeObject(forKey: "LatestAnalysisSummary")
            UserDefaults.standard.removeObject(forKey: "LatestPersonalizedTips")
            UserDefaults.standard.removeObject(forKey: "LatestAnnotatedImage")

            do {
                try viewContext.save()
                expandedSessions.removeAll()
                print("[ResultsView] Successfully cleared all history")
            } catch {
                print("[ResultsView] Failed to clear history: \(error.localizedDescription)")
            }
        }
    }
}
