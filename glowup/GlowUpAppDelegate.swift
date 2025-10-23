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

final class GlowUpAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Quick Actions disabled for this release
        application.shortcutItems = []
        return true
    }
}
