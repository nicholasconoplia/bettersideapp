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
    case dashboard
    case analyze
    case roadmap
    case visualize
    case diary
}

struct GlowUpTabView: View {
    @State private var selection: GlowTab = .dashboard
    @StateObject private var visualizationViewModel = VisualizationViewModel()
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @AppStorage("hasUsedFreeScan") private var hasUsedFreeScan = false

    init() {
        customizeTabBarAppearance()
    }

    var body: some View {
        ZStack {
            GlowGradient.canvas
                .ignoresSafeArea()
            TabView(selection: $selection) {
                DashboardView(selection: $selection)
                    .tabItem {
                        Label("Dashboard", systemImage: "square.grid.2x2.fill")
                    }
                    .tag(GlowTab.dashboard)

                AnalyzeContainerView()
                    .tabItem {
                        Label("Analyze", systemImage: "camera.aperture")
                    }
                    .tag(GlowTab.analyze)

                RoadmapView()
                    .tabItem {
                        Label("Roadmap", systemImage: "calendar.badge.checkmark")
                    }
                    .tag(GlowTab.roadmap)
                    .badge(appModel.shouldShowRoadmapBadge() ? "!" : nil)

                VisualizeView()
                    .environmentObject(visualizationViewModel)
                    .tabItem {
                        Label("Visualize", systemImage: "wand.and.stars")
                    }
                    .tag(GlowTab.visualize)

                DiaryView()
                    .tabItem {
                        Label("Diary", systemImage: "book.closed")
                    }
                    .tag(GlowTab.diary)
                    
            }
            .tint(GlowPalette.deepRose)
        }
        .onChange(of: appModel.navigateToAnalyzeRequested) { go in
            if go {
                selection = .analyze
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    appModel.navigateToAnalyzeRequested = false
                }
            }
        }
    }

    private func customizeTabBarAppearance() {
        #if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.9843, green: 0.9804, blue: 0.9608, alpha: 0.95)

        let normalColor = UIColor(red: 0.5765, green: 0.3098, blue: 0.3608, alpha: 0.45)
        let selectedColor = UIColor(red: 0.5765, green: 0.3098, blue: 0.3608, alpha: 1.0)

        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        appearance.inlineLayoutAppearance = appearance.stackedLayoutAppearance
        appearance.compactInlineLayoutAppearance = appearance.stackedLayoutAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        #endif
    }
}
