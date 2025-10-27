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
    @State private var showFutureWeekAlert = false
    @State private var futureWeekMessage: String?

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
                            .font(.glowSubheading)
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
        .alert("Keep progressing", isPresented: $showFutureWeekAlert, actions: {
            Button("Got it", role: .cancel) { futureWeekMessage = nil }
        }, message: {
            Text(futureWeekMessage ?? "Once this week is done and you log a new scan, the next week will unlock for you.")
        })
        .sheet(isPresented: Binding(
            get: { viewModel.showCompletionModal },
            set: { value in viewModel.showCompletionModal = value }
        )) {
            completionCelebrationView
                .presentationDetents([.medium])
        }
        .sheet(isPresented: Binding(
            get: { viewModel.milestoneMessage != nil },
            set: { value in if !value { viewModel.milestoneMessage = nil } }
        )) {
            milestoneCelebrationView
                .presentationDetents([.fraction(0.35)])
        }
    }

    private var lockedOverlay: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Glow Plan (Locked)")
                    .font(GlowTypography.glowHeading)
                    .foregroundStyle(GlowPalette.deepRose)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    Text("What this tab gives you")
                        .font(GlowTypography.glowSubheading)
                        .foregroundStyle(GlowPalette.deepRose)
                    Text("A week-by-week, auto-prioritized plan built from your analysis. It includes instant fixes, long-term upgrades, reminders, and personalized tips.")
                        .font(GlowTypography.glowBody)
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(GlowPalette.softBeige)
                .cornerRadius(18)

                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(GlowPalette.softBeige)
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(GlowPalette.deepRose)
                        Text("Your personalized Glow Plan is part of Full Analysis")
                            .font(GlowTypography.glowBody)
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
                    .tint(GlowPalette.roseGold)
                    .deepRoseText()
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
                .foregroundStyle(GlowPalette.deepRose.opacity(0.65))
            Text("Weekly Glow Roadmap")
                .font(.title.bold())
                .deepRoseText()
            let canGenerate = appModel.latestAnalysis != nil
            Text(canGenerate ? viewModel.emptyStateMessage : "Run a fresh photo analysis to unlock your personalized plan.")
                .font(.glowBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.75))
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
                .font(.glowSubheading)
                .deepRoseText()
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

                if let activeWeek = viewModel.currentWeek {
                    dailyChecklist(for: activeWeek)
                } else {
                    Text("Run a fresh scan to build today’s personalized checklist.")
                        .font(.callout)
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
                        .padding()
                        .background(GlowPalette.softOverlay(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(GlowPalette.roseStroke(0.25), lineWidth: 1)
                        )
                }

                weeklyProgressSection
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
                    .deepRoseText()
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(GlowPalette.softOverlay(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(GlowPalette.roseStroke(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canRescan)
                .opacity(canRescan ? 1.0 : 0.35)

                if !canRescan {
                    Text("Complete every task to unlock Week \(currentWeekNumber + 1).")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(GlowPalette.creamyWhite.opacity(0.92))
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
                    .fill(GlowPalette.softOverlay(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(GlowPalette.roseStroke(0.35), lineWidth: 1)
            )
        }
    }

    private func dailyChecklist(for week: RoadmapViewModel.Week) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(week.tasks) { task in
                Button {
                    withAnimation(.easeInOut) {
                        viewModel.toggleTaskCompletion(task)
                    }
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(task.isCompleted ? GlowPalette.roseGold : GlowPalette.roseStroke(0.4))
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(task.title)
                                .font(.glowSubheading)
                                .foregroundStyle(GlowPalette.deepRose)
                            if !task.body.isEmpty {
                                Text(task.body)
                                    .font(.glowBody)
                                    .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
                            }
                            if !task.timeframe.isEmpty {
                                Text(task.timeframe)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(GlowPalette.roseGold.opacity(0.8))
                            }
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(GlowPalette.softOverlay(task.isCompleted ? 0.7 : 0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(GlowPalette.roseStroke(task.isCompleted ? 0.45 : 0.3), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(GlowPalette.softOverlay(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(GlowPalette.roseStroke(0.3), lineWidth: 1)
        )
    }

    private var weeklyProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Progress")
                .font(.glowSubheading)
                .deepRoseText()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.weeks) { week in
                        RoadmapWeekCard(
                            week: week,
                            onOpenDetail: {
                                viewModel.presentWeekDetail(week)
                            },
                            onLockedTap: { reason in
                                switch reason {
                                case .subscription:
                                    viewModel.requestSubscriptionUpsell(source: "week_card_\(week.number)")
                                case .future:
                                    futureWeekMessage = "I know some people like to rush ahead to see all of the week’s tasks, but progress takes time. Once you finish this week and run a new scan, the next week will unlock for you."
                                    showFutureWeekAlert = true
                                }
                            }
                        )
                        .frame(width: 280)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var completionCelebrationView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(GlowPalette.roseGold)

            Text("Plan complete")
                .font(.title2.bold())
                .foregroundStyle(GlowPalette.deepRose)

            Text("Your consistency drives visible improvement.")
                .font(.glowBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.75))
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Button {
                    appModel.navigateToAnalyzeRequested = true
                    viewModel.showCompletionModal = false
                } label: {
                    Text("View Insights")
                        .font(.glowButton)
                        .frame(maxWidth: .infinity)
                }
                .glowRoundedButtonBackground(isEnabled: true)

                Button("Maybe later") {
                    viewModel.showCompletionModal = false
                }
                .font(.glowBody.weight(.semibold))
                .foregroundStyle(GlowPalette.roseGold)
            }
        }
        .padding(28)
        .presentationDragIndicator(.visible)
    }

    private var milestoneCelebrationView: some View {
        VStack(spacing: 20) {
            Image(systemName: "seal.fill")
                .font(.system(size: 46))
                .foregroundStyle(GlowPalette.roseGold)

            Text("Glow Milestone")
                .font(.title3.bold())
                .foregroundStyle(GlowPalette.deepRose)

            Text(viewModel.milestoneMessage ?? "Seven days of dedication! Keep your streak alive.")
                .font(.glowBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.75))
                .padding(.horizontal, 24)

            Button("Celebrate") {
                viewModel.milestoneMessage = nil
            }
            .font(.glowButton)
            .glowRoundedButtonBackground(isEnabled: true)
        }
        .padding(28)
        .presentationDragIndicator(.visible)
    }
}
