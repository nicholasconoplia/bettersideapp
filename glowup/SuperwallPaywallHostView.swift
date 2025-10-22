//
//  SuperwallPaywallHostView.swift
//  glowup
//
//  Attempts to present Superwall. Falls back to existing SubscriptionGateView if unavailable.
//

import SwiftUI

struct SuperwallPaywallHostView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    // When true, we show our custom fallback paywall
    @State private var shouldShowFallback = false
    @State private var isPresenting = false

    let preview: PaywallPreview

    var body: some View {
        Group {
            if subscriptionManager.isSubscribed {
                // If already subscribed, go straight to app
                Color.clear.onAppear {
                    print("[SuperwallHost] Subscribed; completing onboarding and skipping paywall chain")
                    appModel.markOnboardingComplete()
                }
            } else if shouldShowFallback {
                SubscriptionGateView(
                    preview: preview,
                    primaryButtonTitle: "Start 3-Day Free Trial",
                    showBack: false,
                    onPrimary: { product in
                        try await subscriptionManager.purchaseSubscription(for: product)
                        await subscriptionManager.refreshEntitlementState()
                    },
                    onBack: nil,
                    onDecline: {
                        shouldShowFallback = false
                    }
                )
            } else {
                // Invisible view that triggers presentation
                Color.clear
                    .task {
                        print("[SuperwallHost] Starting paywall chain (suppress=\(appModel.suppressDefaultPaywallForSession))")
                        await presentSuperwallOrFallback()
                    }
                    .onChange(of: subscriptionManager.isSubscribed) { isSub in
                        if isSub {
                            print("[SuperwallHost] Detected subscription during chain; finishing onboarding")
                            appModel.markOnboardingComplete()
                        }
                    }
            }
        }
        .background(GradientBackground.twilightAura.ignoresSafeArea())
    }

    private func presentSuperwallOrFallback() async {
        guard !isPresenting else { return }
        isPresenting = true
        // If a quick action explicitly asked to suppress chaining, stop here
        if appModel.suppressDefaultPaywallForSession {
            print("[SuperwallHost] Suppressing default paywall chain due to quick action")
            isPresenting = false
            return
        }

        // 1) Main paywall
        await SuperwallService.shared.presentAndAwaitDismissal("subscription_paywall", timeoutSeconds: 1)
        await subscriptionManager.refreshEntitlementState()
        if subscriptionManager.isSubscribed {
            appModel.markOnboardingComplete()
            isPresenting = false
            return
        }

        // 2) Education paywall (if configured)
        await SuperwallService.shared.presentAndAwaitDismissal("post_paywall_education", timeoutSeconds: 1)
        await subscriptionManager.refreshEntitlementState()
        if subscriptionManager.isSubscribed {
            appModel.markOnboardingComplete()
            isPresenting = false
            return
        }

        // 3) Sorry paywall (if configured)
        await SuperwallService.shared.presentAndAwaitDismissal("post_paywall_sorry", timeoutSeconds: 1)
        await subscriptionManager.refreshEntitlementState()
        if subscriptionManager.isSubscribed {
            appModel.markOnboardingComplete()
        } else {
            // iOS apps cannot quit programmatically; route back to start instead
            appModel.resetOnboarding()
        }
        isPresenting = false
    }
}


