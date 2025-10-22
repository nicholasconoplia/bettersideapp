//
//  GlowUpAppDelegate.swift
//  glowup
//
//  Created by Codex on 22/10/2025.
//

import SwiftUI
import UIKit

enum GlowUpQuickAction: String {
    case homescreenLastChance = "com.betterside.glowup.quickaction.lastchance"

    var shortcutItem: UIApplicationShortcutItem {
        switch self {
        case .homescreenLastChance:
            let icon = UIApplicationShortcutIcon(type: .favorite)
            return UIApplicationShortcutItem(
                type: rawValue,
                localizedTitle: "🚨 Try for Free",
                localizedSubtitle: "Get unlimited access to the BetterSide app",
                icon: icon,
                userInfo: nil
            )
        }
    }

    init?(shortcutItem: UIApplicationShortcutItem) {
        self.init(rawValue: shortcutItem.type)
    }
}

@MainActor
protocol GlowUpQuickActionHandling: AnyObject {
    @discardableResult
    func handleQuickAction(_ action: GlowUpQuickAction) -> Bool
}

final class GlowUpAppDelegate: NSObject, UIApplicationDelegate {
    weak var quickActionHandler: GlowUpQuickActionHandling?

    private var pendingShortcutItem: UIApplicationShortcutItem?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.shortcutItems = [GlowUpQuickAction.homescreenLastChance.shortcutItem]

        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            pendingShortcutItem = shortcutItem
            return false
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        application.shortcutItems = [GlowUpQuickAction.homescreenLastChance.shortcutItem]
        guard let shortcutItem = pendingShortcutItem else { return }
        handle(shortcutItem)
        pendingShortcutItem = nil
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(handle(shortcutItem))
    }

    @discardableResult
    private func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = GlowUpQuickAction(shortcutItem: shortcutItem) else {
            return false
        }

        Task { @MainActor [weak self] in
            _ = self?.quickActionHandler?.handleQuickAction(action)
        }

        return true
    }
}
