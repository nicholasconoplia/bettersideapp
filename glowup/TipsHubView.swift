//
//  TipsHubView.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import SwiftUI
import UIKit

struct TipsHubView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.managedObjectContext) private var context
    @Environment(\.openURL) private var openURL

    @FetchRequest(
        entity: TipEntry.entity(),
        sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
        animation: .easeInOut
    ) private var tips: FetchedResults<TipEntry>

    @State private var selectedMode: TipMode = .shortTerm
    @State private var isRefreshing = false
    @State private var recommendationPlan: PersonalizedRecommendationPlan?

    private var filteredTips: [TipEntry] {
        tips.filter { $0.type == selectedMode.storageType }
    }

    private var currentActionTips: [AppearanceActionTip] {
        guard let plan = recommendationPlan else { return [] }
        switch selectedMode {
        case .shortTerm:
            return plan.shortTerm
        case .longTerm:
            return plan.longTerm
        }
    }

    private var vibeMatches: [CelebrityMatchSuggestion] {
        recommendationPlan?.celebrityMatches ?? []
    }

    private var pinterestIdeas: [PinterestSearchIdea] {
        recommendationPlan?.pinterestIdeas ?? []
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground.primary
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    modePicker
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if filteredTips.isEmpty {
                                if !currentActionTips.isEmpty {
                                    ForEach(currentActionTips) { tip in
                                        actionTipPreviewCard(tip)
                                    }
                                } else {
                                    emptyState
                                }
                            } else {
                                ForEach(filteredTips) { tip in
                                    tipCard(tip)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                        if !vibeMatches.isEmpty {
                            celebrityVibeSection
                                .padding(.horizontal, 16)
                                .padding(.bottom, 32)
                        }
                        if !pinterestIdeas.isEmpty {
                            pinterestSection
                                .padding(.horizontal, 16)
                                .padding(.bottom, 80)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await refreshTips() }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(GlowPalette.deepRose)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .deepRoseText()
                        }
                    }
                }
            }
            .navigationTitle("Tips Hub")
            .onAppear {
                loadPlan()
            }
        }
    }

    private var modePicker: some View {
        Picker("", selection: $selectedMode) {
            Text("Short-Term Glow").tag(TipMode.shortTerm)
            Text("Long-Term Strategy").tag(TipMode.longTerm)
        }
        .pickerStyle(.segmented)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(GlowPalette.deepRose.opacity(0.12))
        )
        .padding(.horizontal)
    }

    private func tipCard(_ tip: TipEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tip.title ?? "Glow Tip")
                .font(.glowSubheading)
                .deepRoseText()
            Text(tip.body ?? "")
                .font(.glowBody)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.85))
            if let action = matchingAction(for: tip), !action.relatedQueries.isEmpty {
                queryChipStack(action.relatedQueries)
            }
            HStack {
                Button {
                    tip.completed.toggle()
                    appModel.persistenceController.saveIfNeeded(context)
                } label: {
                    Label(
                        tip.completed ? "Completed" : "Mark complete",
                        systemImage: tip.completed ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.footnote.weight(.semibold))
                }
                .buttonStyle(GlowFilledButtonStyle())
                .tint(GlowPalette.creamyWhite.opacity(0.2))

                Spacer()

                Button {
                    UIPasteboard.general.string = tip.body ?? ""
                } label: {
                    Label {
                        Text("Copy")
                            .font(GlowTypography.glowCaption.weight(.semibold))
                    } icon: {
                        Image(systemName: "doc.on.doc")
                    }
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }

    private func actionTipPreviewCard(_ tip: AppearanceActionTip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tip.title)
                .font(.glowSubheading)
                .deepRoseText()
            Text(tip.body)
                .font(.glowBody)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.85))
            if !tip.relatedQueries.isEmpty {
                queryChipStack(tip.relatedQueries)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }

    private func matchingAction(for entry: TipEntry) -> AppearanceActionTip? {
        guard let id = entry.id else { return nil }
        if let short = recommendationPlan?.shortTerm.first(where: { $0.id == id }) {
            return short
        }
        return recommendationPlan?.longTerm.first(where: { $0.id == id })
    }

    private func queryChipStack(_ queries: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(queries, id: \.self) { query in
                    Text(query.capitalized)
                        .font(GlowTypography.glowCaption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(GlowPalette.deepRose.opacity(0.12))
                        .cornerRadius(12)
                }
            }
        }
    }

    private var celebrityVibeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.3.sequence")
                    .foregroundStyle(GlowPalette.roseGold)
                Text("Celebrity Vibe Matches")
                    .font(.glowSubheading)
                    .deepRoseText()
            }
            ForEach(vibeMatches) { match in
                VStack(alignment: .leading, spacing: 10) {
                    Text(match.name)
                        .font(.glowBody.weight(.semibold))
                        .deepRoseText()
                    Text(match.descriptor)
                        .font(GlowTypography.glowCaption)
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
                    Text(match.whyItWorks)
                        .font(GlowTypography.glowCaption)
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.85))
                }
                .padding()
                .background(GlowPalette.deepRose.opacity(0.08))
                .cornerRadius(18)
            }
        }
        .padding()
        .background(GlowPalette.deepRose.opacity(0.08))
        .cornerRadius(20)
    }

    private var pinterestSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "safari")
                    .foregroundStyle(GlowPalette.roseGold)
                Text("Pinterest Search Generator")
                    .font(.glowSubheading)
                    .deepRoseText()
            }
            VStack(spacing: 12) {
                ForEach(pinterestIdeas) { idea in
                    pinterestIdeaCard(idea)
                }
            }
        }
        .padding()
        .background(GlowPalette.deepRose.opacity(0.08))
        .cornerRadius(20)
    }

    private func pinterestIdeaCard(_ idea: PinterestSearchIdea) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(idea.label)
                .font(.glowBody.weight(.semibold))
                .deepRoseText()
            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = idea.query
                } label: {
                    Label {
                        Text("Copy")
                            .font(GlowTypography.glowCaption.weight(.semibold))
                    } icon: {
                        Image(systemName: "doc.on.doc")
                    }
                }
                .buttonStyle(GlowFilledButtonStyle())
                .tint(GlowPalette.creamyWhite.opacity(0.18))

                if let url = idea.encodedURL {
                    Button {
                        openURL(url)
                    } label: {
                        Label {
                            Text("Open in Pinterest")
                                .font(GlowTypography.glowCaption.weight(.semibold))
                        } icon: {
                            Image(systemName: "arrow.up.right")
                        }
                    }
                    .buttonStyle(GlowFilledButtonStyle())
                    .tint(Color(red: 0.94, green: 0.34, blue: 0.56).opacity(0.6))
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.22))
        .cornerRadius(16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
            Text("Tap refresh to generate your \(selectedMode == .shortTerm ? "daily" : "long-term") glow plan.")
                .font(.glowBody.weight(.medium))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func refreshTips() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        let engine = TipEngine(persistenceController: appModel.persistenceController)
        let quiz = appModel.latestQuiz.map(QuizResult.init(from:))
        await engine.refreshTips(mode: selectedMode, quiz: quiz)
        isRefreshing = false
        loadPlan()
    }

    private func loadPlan() {
        if let data = UserDefaults.standard.data(forKey: "LatestRecommendationPlan"),
           let decoded = try? JSONDecoder().decode(PersonalizedRecommendationPlan.self, from: data) {
            recommendationPlan = decoded
        } else {
            recommendationPlan = nil
        }
    }
}
