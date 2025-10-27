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
        ZStack {
            GradientBackground.twilightAura
                .ignoresSafeArea()

            content

            if isPresenting && !shouldShowFallback && !subscriptionManager.isSubscribed && !appModel.onboardingComplete {
                loadingOverlay
            }
        }
        .task(id: isPresenting) {
            // Safety exit: if we appear to be presenting for too long without conversion, enter limited mode.
            guard isPresenting else { return }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if isPresenting && !subscriptionManager.isSubscribed && !appModel.onboardingComplete {
                print("[SuperwallHost] Safety timeout reached; entering limited mode.")
                isPresenting = false
                appModel.markOnboardingComplete()
            }
        }
    }

    private func presentSuperwallOrFallback() async {
        guard !isPresenting else { return }
        isPresenting = true
        defer { isPresenting = false }

        if !SuperwallService.shared.isAvailable {
            print("[SuperwallHost] Superwall unavailable; showing fallback paywall.")
            shouldShowFallback = true
            return
        }

        // If a quick action explicitly asked to suppress chaining, stop here
        if appModel.suppressDefaultPaywallForSession {
            print("[SuperwallHost] Suppressing default paywall chain due to quick action")
            return
        }

        let placements = [
            "subscription_paywall"
        ]

        var anyAttempted = false

        for placement in placements {
            let didAttempt = await SuperwallService.shared.presentAndAwaitDismissal(placement, timeoutSeconds: 2)
            anyAttempted = anyAttempted || didAttempt
            await subscriptionManager.refreshEntitlementState()
            if subscriptionManager.isSubscribed {
                appModel.markOnboardingComplete()
                return
            }
        }

        await subscriptionManager.refreshEntitlementState()
        if subscriptionManager.isSubscribed {
            appModel.markOnboardingComplete()
        } else {
            if anyAttempted {
                // User dismissed without subscribing; proceed to limited mode (one free scan) and finish onboarding.
                print("[SuperwallHost] Paywall dismissed without conversion; entering limited mode.")
                appModel.markOnboardingComplete()
                return
            } else {
                print("[SuperwallHost] No Superwall placements executed; presenting fallback paywall.")
                shouldShowFallback = true
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if subscriptionManager.isSubscribed {
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
                    appModel.resetOnboarding()
                }
            )
        } else if appModel.onboardingComplete {
            // Onboarding finished (limited mode). Do not present anything.
            Color.clear
        } else {
            Color.clear
                .task {
                    guard !appModel.onboardingComplete else { return }
                    print("[SuperwallHost] Starting paywall chain (suppress=\(appModel.suppressDefaultPaywallForSession))")
                    await presentSuperwallOrFallback()
                }
                .onChange(of: subscriptionManager.isSubscribed) { isSub in
                    if isSub {
                        print("[SuperwallHost] Detected subscription during chain; finishing onboarding")
                        appModel.markOnboardingComplete()
                        isPresenting = false
                    }
                }
                .onChange(of: appModel.onboardingComplete) { complete in
                    if complete {
                        // Ensure any loading overlay is hidden immediately when we enter limited mode
                        isPresenting = false
                    }
                }
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(GlowPalette.roseGold)
                .scaleEffect(1.15)
            Text("Preparing your GlowUp offers…")
                .font(.glowSubheading)
                .deepRoseText()
            Text("If Superwall is unavailable we’ll show the built-in trial screen automatically.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
        }
        .padding(24)
        .background(.ultraThinMaterial.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding()
    }
}

