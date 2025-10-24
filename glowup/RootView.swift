//
//  RootView.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openURL) private var openURL
    @State private var attemptedAutoRoadmapGeneration = false

    var body: some View {
        Group {
            // No splash screen: immediately render primary content based on state.
            if !appModel.onboardingComplete {
                OnboardingFlowView()
            } else if appModel.isSubscribed && !appModel.hasActiveRoadmap {
                // Route user to the main app immediately after subscribing.
                // Generate the roadmap in the background so we never show a blank screen.
                GlowUpTabView()
                    .task {
                        guard !attemptedAutoRoadmapGeneration else { return }
                        attemptedAutoRoadmapGeneration = true
                        await appModel.generateRoadmapFromLatestAnalysis()
                        appModel.refreshRoadmapState()
                    }
            } else if !appModel.isSubscribed {
                if appModel.onboardingComplete {
                    // Limited mode: enter the app with one free scan.
                    GlowUpTabView()
                } else if appModel.suppressDefaultPaywallForSession {
                    Color.clear
                        .task {
                            print("[RootView] Suppressing default paywall host due to quick action")
                        }
                } else {
                    SuperwallPaywallHostView(
                        preview: PaywallPreviewBuilder.makePreview(from: appModel.latestQuiz.map { QuizResult(from: $0) })
                    )
                }
            } else {
                GlowUpTabView()
            }
        }
        // If a pending Superwall placement exists, trigger it in the background without blocking UI.
        .task(id: appModel.pendingPlacement) {
            if appModel.pendingPlacement != nil {
                print("[RootView] Pending placement detected; triggering in background...")
                await appModel.triggerPendingPlacementIfReady()
            }
        }
        .animation(.easeInOut, value: appModel.onboardingComplete)
        .animation(.easeInOut, value: appModel.isSubscribed)
        .alert(
            item: Binding<AppModel.QuickActionAlertContext?>(
                get: { appModel.quickActionAlert },
                set: { appModel.quickActionAlert = $0 }
            )
        ) { alertContext in
            Alert(
                title: Text(alertContext.title),
                message: Text(alertContext.message),
                primaryButton: .default(Text(alertContext.confirmButtonTitle)) {
                    _ = openURL(alertContext.url)
                    appModel.quickActionAlert = nil
                },
                secondaryButton: .cancel {
                    appModel.quickActionAlert = nil
                }
            )
        }
    }
}

private struct SplashLoadingView: View {
    var body: some View {
        ZStack {
            GradientBackground.lavenderRose
            VStack(spacing: 20) {
                Text("BetterSide")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
        }
        .ignoresSafeArea()
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        let subscriptionManager = SubscriptionManager()
        let appModel = AppModel(
            persistenceController: .preview,
            subscriptionManager: subscriptionManager
        )
        return RootView()
            .environmentObject(appModel)
            .environmentObject(subscriptionManager)
    }
}
