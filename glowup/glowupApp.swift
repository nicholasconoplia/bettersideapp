//
//  glowupApp.swift
//  glowup
//
//  Created by Nick Conoplia on 13/10/2025.
//

import SwiftUI

@main
struct GlowUpApp: App {
    private let persistenceController = PersistenceController.shared
    @StateObject private var appModel: AppModel

    init() {
        let persistence = PersistenceController.shared
        let subscriptionManager = SubscriptionManager()
        _appModel = StateObject(
            wrappedValue: AppModel(
                persistenceController: persistence,
                subscriptionManager: subscriptionManager
            )
        )
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
