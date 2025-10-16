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
    case coach
    case results
    case visualize
    case notes
}

struct GlowUpTabView: View {
    @State private var selection: GlowTab = .home
    @StateObject private var visualizationViewModel = VisualizationViewModel()

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

                AICoachOptionsView()
                    .tabItem {
                        Label("Analyze", systemImage: "photo.on.rectangle")
                    }
                    .tag(GlowTab.coach)

                ResultsView(selection: $selection)
                    .environmentObject(visualizationViewModel)
                    .tabItem {
                        Label("Results", systemImage: "clock.fill")
                    }
                    .tag(GlowTab.results)

                VisualizeView()
                    .environmentObject(visualizationViewModel)
                    .tabItem {
                        Label("Visualize", systemImage: "wand.and.stars.inverse")
                    }
                    .tag(GlowTab.visualize)

                NotesView()
                    .environmentObject(visualizationViewModel)
                    .tabItem {
                        Label("Notes", systemImage: "note.text")
                    }
                    .tag(GlowTab.notes)
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
