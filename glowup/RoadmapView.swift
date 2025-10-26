//
//  RoadmapView.swift
//  glowup
//
//  Created by Codex on 02/11/2025.
//

import SwiftUI

struct RoadmapView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var viewModel = RoadmapViewModel()
    @State private var isRequestingGeneration = false
    @AppStorage("hasUsedFreeScan") private var hasUsedFreeScan = false

    private let accentGradient = LinearGradient(
        colors: [
            GlowPalette.blushPink,
            GlowPalette.roseGold.opacity(0.85)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        ZStack {
            GlowGradient.canvas
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if appModel.isGeneratingRoadmap {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(GlowPalette.blushPink)
                            .scaleEffect(1.5)
                        Text("Analyzing your scan and building your Glow Plan ✨")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(GlowPalette.deepRose)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                } else {
                    if subscriptionManager.isSubscribed {
                        content
                    } else {
                        lockedOverlay
                    }
                }
            }
                .padding(.horizontal, 20)
                .padding(.top, 32)
        }
        .task {
            viewModel.configure(
                appModel: appModel,
                subscriptionManager: subscriptionManager,
                context: context
            )
            RoadmapNotificationManager.shared.requestAuthorizationIfNeeded()
        }
        .task(id: appModel.isGeneratingRoadmap) {
            if !appModel.isGeneratingRoadmap {
                await viewModel.reload()
            }
        }
        .refreshable {
            await viewModel.reload()
        }
        .sheet(item: $viewModel.selectedWeek) { week in
            RoadmapWeekDetailView(
                week: week,
                onToggleTask: { task in
                    viewModel.toggleTaskCompletion(task, in: week)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showingSubscriptionPaywall) {
            SubscriptionGateContainerView()
                .environmentObject(appModel)
                .environmentObject(subscriptionManager)
        }
        .alert(
            item: Binding<AppModel.RoadmapAlertContext?>(
                get: { appModel.roadmapAlert },
                set: { appModel.roadmapAlert = $0 }
            )
        ) { context in
            Alert(
                title: Text(context.title),
                message: Text(context.message),
                dismissButton: .default(Text("Got it"))
            )
        }
    }

    private var lockedOverlay: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Glow Plan (Locked)")
                    .font(.title2.bold())
                    .foregroundStyle(GlowPalette.deepRose)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    Text("What this tab gives you")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("A week-by-week, auto-prioritized plan built from your analysis. It includes instant fixes, long-term upgrades, reminders, and personalized tips.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(18)

                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(GlowPalette.softBeige)
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(GlowPalette.deepRose)
                        Text("Your personalized Glow Plan is part of Full Analysis")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GlowPalette.deepRose)
                            .multilineTextAlignment(.center)
                        Button {
                            if hasUsedFreeScan {
                                SuperwallService.shared.registerEvent("subscription_paywall")
                            } else {
                                SuperwallService.shared.registerEvent("post_paywall_education")
                            }
                        } label: {
                            Text("Unlock Full Analysis")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GlowPrimaryButtonStyle())
                        .padding(.top, 6)
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            VStack(spacing: 16) {
                ProgressView("Loading your roadmap…")
                    .tint(.white)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            emptyState
        case .ready:
            readyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.65))
            Text("Weekly Glow Roadmap")
                .font(.title.bold())
                .foregroundStyle(.white)
            let canGenerate = appModel.latestAnalysis != nil
            Text(canGenerate ? viewModel.emptyStateMessage : "Run a fresh photo analysis to unlock your personalized plan.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: 320)

            Button {
                Task {
                    isRequestingGeneration = true
                    defer { isRequestingGeneration = false }
                    await appModel.generateRoadmapFromLatestAnalysis()
                    await viewModel.reload()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                    Text("Generate from Latest Analysis")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: 320)
                .background(accentGradient)
                .cornerRadius(20)
            }
            .buttonStyle(.plain)
            .opacity((isRequestingGeneration || appModel.latestAnalysis == nil) ? 0.4 : 1.0)
            .disabled(isRequestingGeneration || appModel.latestAnalysis == nil)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var readyState: some View {
        let currentWeekNumber = viewModel.weeks.first?.number ?? (viewModel.weeks.last?.number ?? 1)
        let currentWeek = viewModel.weeks.first(where: { $0.number == currentWeekNumber })
        let canRescan = (currentWeek?.progress ?? 0) >= 0.999

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header

                LazyVStack(spacing: 20, pinnedViews: []) {
                    ForEach(viewModel.weeks) { week in
                        RoadmapWeekCard(
                            week: week,
                            onOpenDetail: {
                                viewModel.presentWeekDetail(week)
                            },
                            onLockedTap: {
                                viewModel.requestSubscriptionUpsell(source: "week_card_\(week.number)")
                            }
                        )
                    }
                }
            }
            .padding(.bottom, 48)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeInOut) { appModel.isGeneratingRoadmap = true }
                    Task {
                        await viewModel.reload()
                        appModel.navigateToAnalyzeRequested = true
                        withAnimation(.easeInOut) { appModel.isGeneratingRoadmap = false }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                        Text("Rescan for Week \(currentWeekNumber + 1)")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canRescan)
                .opacity(canRescan ? 1.0 : 0.35)

                if !canRescan {
                    Text("Complete every task to unlock Week \(currentWeekNumber + 1).")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial.opacity(0.08))
        }
    }

    private var header: some View {
        let currentWeekNumber = viewModel.weeks.first?.number ?? (viewModel.weeks.last?.number ?? 1)
        return VStack(alignment: .leading, spacing: 16) {
            Text("My Roadmap")
                .font(.largeTitle.bold())
                .foregroundStyle(GlowPalette.deepRose)
                .fixedSize(horizontal: false, vertical: true)

            Text("Your daily checklist")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.8))

            Text("Tap any card to open the full weekly action plan with step-by-step coaching.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.65))

            Text("Finish everything on this list, then rescan to unlock Week \(currentWeekNumber + 1).")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Plan Progress")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.65))
                    Spacer()
                    Text("\(Int(round(viewModel.overallProgress * 100)))%")
                        .font(.caption.bold())
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.85))
                }
                GlowProgressBar(value: viewModel.overallProgress)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(GlowPalette.softBeige)
            )
        }
    }
}
