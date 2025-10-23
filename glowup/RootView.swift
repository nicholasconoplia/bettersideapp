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

    var body: some View {
        Group {
            // If a quick action set a pending Superwall placement, trigger it ASAP
            if appModel.isPresentingQuickActionPaywall {
                SplashLoadingView()
            } else if let _ = appModel.pendingPlacement {
                SplashLoadingView()
                    .task {
                        print("[RootView] Pending placement detected; waiting for Superwall readiness...")
                        await SuperwallService.shared.waitForConfiguration()
                        print("[RootView] Superwall ready, triggering placement...")
                        await appModel.triggerPendingPlacementIfReady()
                    }
            } else if appModel.isBootstrapping {
                SplashLoadingView()
            } else if !appModel.onboardingComplete {
                OnboardingFlowView()
            } else if !appModel.isSubscribed {
                if appModel.suppressDefaultPaywallForSession {
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
