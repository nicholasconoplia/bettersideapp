//
//  RootView.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Group {
            if appModel.isBootstrapping {
                SplashLoadingView()
            } else if !appModel.onboardingComplete {
                OnboardingFlowView()
            } else if !appModel.isSubscribed {
                SubscriptionGateContainerView()
            } else {
                GlowUpTabView()
            }
        }
        .animation(.easeInOut, value: appModel.onboardingComplete)
        .animation(.easeInOut, value: appModel.isSubscribed)
    }
}

private struct SplashLoadingView: View {
    var body: some View {
        ZStack {
            GradientBackground.lavenderRose
            VStack(spacing: 20) {
                Text("GlowUp")
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
