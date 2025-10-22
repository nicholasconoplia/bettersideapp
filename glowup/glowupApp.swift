//
//  glowupApp.swift
//  glowup
//
//  Created by Nick Conoplia on 13/10/2025.
//

import SwiftUI
import Foundation

@main
struct GlowUpApp: App {
    private let persistenceController = PersistenceController.shared
    @StateObject private var appModel: AppModel
    @UIApplicationDelegateAdaptor(GlowUpAppDelegate.self) private var appDelegate

    init() {
        let persistence = PersistenceController.shared
        let subscriptionManager = SubscriptionManager()
        let model = AppModel(
            persistenceController: persistence,
            subscriptionManager: subscriptionManager
        )
        _appModel = StateObject(wrappedValue: model)
        appDelegate.quickActionHandler = model

        // Configure Superwall early when possible
        SuperwallService.shared.configureIfPossible()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appModel)
                .environmentObject(appModel.subscriptionManager)
        }
    }
}
