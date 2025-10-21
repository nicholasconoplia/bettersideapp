//
//  SubscriptionGateContainerView.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import SwiftUI

struct SubscriptionGateContainerView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showingReconsideration = false
    @State private var isProcessing = false

    var body: some View {
        ZStack {
            Group {
                if showingReconsideration {
                    SubscriptionReconsiderationView(
                        onReturnToPlans: {
                            withAnimation(.easeInOut) {
                                showingReconsideration = false
                            }
                        },
                        onExitToStart: {
                            withAnimation(.easeInOut) {
                                showingReconsideration = false
                            }
                            appModel.resetOnboarding()
                        }
                    )
                } else {
                    SubscriptionGateView(
                        preview: currentPreview,
                        primaryButtonTitle: "Start 3-Day Free Trial",
                        showBack: false,
                        onPrimary: { product in
                            isProcessing = true
                            do {
                                try await subscriptionManager.purchaseSubscription(for: product)
                                await subscriptionManager.refreshEntitlementState()
                            } catch {
                                print("❌ Purchase failed:", error.localizedDescription)
                            }
                            isProcessing = false
                        },
                        onBack: nil,
                        onDecline: {
                            withAnimation(.easeInOut) {
                                showingReconsideration = true
                            }
                        }
                    )
                }
            }

            // Optional loading overlay
            if isProcessing || subscriptionManager.isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView("Processing…")
                    .font(.headline)
                    .tint(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
            }
        }
        // Automatically proceed when subscription becomes active
        .onChange(of: subscriptionManager.isSubscribed) { isSubscribed in
            if isSubscribed {
                print("✅ Subscription active – moving to main app.")
                withAnimation(.easeInOut) {
                    // Call whatever method transitions your app forward:
                    appModel.markOnboardingComplete()
     // ✅ If you have this function
                    // OR appModel.finishOnboarding()   // ✅ Adjust to your actual name
                    // OR appModel.route = .main        // ✅ If your AppModel uses routing
                }
            }
        }
        .task {
            // Refresh entitlement state when this screen appears
            await subscriptionManager.refreshEntitlementState()
        }
    }

    private var currentPreview: PaywallPreview {
        if let quiz = appModel.latestQuiz {
            let result = QuizResult(from: quiz)
            return PaywallPreviewBuilder.makePreview(from: result)
        } else {
            return PaywallPreviewBuilder.makePreview(from: nil)
        }
    }
}
