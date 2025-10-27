//
//  GlowUpAppDelegate.swift
//  glowup
//
//  Created by Codex on 22/10/2025.
//

import SwiftUI
import UIKit

// Quick Action temporarily disabled for release
// enum GlowUpQuickAction: String {
//     case homescreenLastChance = "com.betterside.glowup.quickaction.lastchance"
//
//     var shortcutItem: UIApplicationShortcutItem {
//         switch self {
//         case .homescreenLastChance:
//             let icon = UIApplicationShortcutIcon(type: .favorite)
//             return UIApplicationShortcutItem(
//                 type: rawValue,
//                 localizedTitle: "🚨 Try for Free",
//                 localizedSubtitle: "Get unlimited access to the BetterSide app",
//                 icon: icon,
//                 userInfo: nil
//             )
//         }
//     }
//
//     init?(shortcutItem: UIApplicationShortcutItem) {
//         self.init(rawValue: shortcutItem.type)
//     }
// }

// @MainActor
// protocol GlowUpQuickActionHandling: AnyObject {
//     @discardableResult
//     func handleQuickAction(_ action: GlowUpQuickAction) -> Bool
// }

func configureAppearances() {
    let nav = UINavigationBarAppearance()
    nav.configureWithOpaqueBackground()
    nav.backgroundColor = UIColor(Color(hex: "#FBFAF5"))
    nav.titleTextAttributes = [
        .foregroundColor: UIColor(Color(hex: "#934F5C")),
        .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
    ]
    UINavigationBar.appearance().standardAppearance = nav
    UINavigationBar.appearance().scrollEdgeAppearance = nav
    UINavigationBar.appearance().tintColor = UIColor(Color(hex: "#B76E79"))

    let tab = UITabBarAppearance()
    tab.configureWithOpaqueBackground()
    tab.backgroundColor = UIColor(Color(hex: "#FBFAF5"))
    tab.stackedLayoutAppearance.normal.iconColor  = UIColor(Color(hex: "#934F5C")).withAlphaComponent(0.6)
    tab.stackedLayoutAppearance.selected.iconColor = UIColor(Color(hex: "#934F5C"))
    tab.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color(hex: "#934F5C")).withAlphaComponent(0.6)]
    tab.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color(hex: "#934F5C"))]
    UITabBar.appearance().standardAppearance = tab
    UITabBar.appearance().scrollEdgeAppearance = tab
}

final class GlowUpAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure app-wide appearances
        configureAppearances()
        
        // Quick Actions disabled for this release
        application.shortcutItems = []
        return true
    }
}
