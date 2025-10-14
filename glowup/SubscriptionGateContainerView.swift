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

    var body: some View {
        SubscriptionGateView(
            preview: currentPreview,
            primaryButtonTitle: "Start 7-Day Free Trial",
            showBack: false,
            onPrimary: { product in
                try await subscriptionManager.purchaseSubscription(for: product)
                await subscriptionManager.refreshEntitlementState()
            },
            onBack: nil,
            onDecline: { }
        )
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
