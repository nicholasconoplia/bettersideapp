//
//  glowupApp.swift
//  glowup
//
//  Created by Nick Conoplia on 13/10/2025.
//

import SwiftUI

@main
struct glowupApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
