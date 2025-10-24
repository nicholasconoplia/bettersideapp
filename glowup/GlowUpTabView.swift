//
//  GlowUpTabView.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum GlowTab: Hashable {
    case home
    case analyze
    case roadmap
    case studio
}

struct GlowUpTabView: View {
    @State private var selection: GlowTab = .home
    @StateObject private var visualizationViewModel = VisualizationViewModel()
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @AppStorage("hasUsedFreeScan") private var hasUsedFreeScan = false

    init() {
        customizeTabBarAppearance()
    }

    var body: some View {
        ZStack {
            GradientBackground.primary
                .ignoresSafeArea()
            TabView(selection: $selection) {
                HomeView(selection: $selection)
                    .tabItem {
                        Label("Home", systemImage: "sparkles")
                    }
                    .tag(GlowTab.home)

                AnalyzeContainerView()
                    .tabItem {
                        Label("Analyze", systemImage: "photo.on.rectangle")
                    }
                    .tag(GlowTab.analyze)

                RoadmapView()
                    .tabItem {
                        Label("Roadmap", systemImage: "calendar.badge.checkmark")
                    }
                    .tag(GlowTab.roadmap)
                    .badge(appModel.shouldShowRoadmapBadge() ? "!" : nil)

                StudioContainerView()
                    .environmentObject(visualizationViewModel)
                    .tabItem {
                        Label("Studio", systemImage: "wand.and.stars.inverse")
                    }
                    .tag(GlowTab.studio)
                    
            }
            .tint(.white)
        }
    }

    private func customizeTabBarAppearance() {
        #if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.18, green: 0.16, blue: 0.32, alpha: 0.95)

        let normalColor = UIColor(white: 1.0, alpha: 0.55)
        let selectedColor = UIColor.white

        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        #endif
    }
}
