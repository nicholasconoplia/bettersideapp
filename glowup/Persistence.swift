//
//  Persistence.swift
//  glowup
//
//  Created by Nick Conoplia on 13/10/2025.
//
import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        _ = controller.ensureUserSettings(in: context)

        let profile = GlowProfile(context: context)
        profile.faceShape = "Oval"
        profile.colorPalette = "Warm"
        profile.bestAngleTilt = 12
        profile.optimalLightingDesc = "Soft daylight near a window"
        profile.theme = "Glow Revival"

        let tip = TipEntry(context: context)
        tip.id = UUID().uuidString
        tip.type = "short"
        tip.title = "Face the light"
        tip.body = "Take a half-step toward your light source and drop your shoulder."
        tip.completed = false
        tip.createdAt = Date()
        tip.source = "preview"

        do {
            try context.save()
        } catch {
            assertionFailure("Preview store failed: \(error)")
        }
        return controller
    }()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "glowup")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }

    @discardableResult
    @MainActor
    func ensureUserSettings(in context: NSManagedObjectContext? = nil) -> UserSettings {
        let context = context ?? viewContext
        let request = NSFetchRequest<UserSettings>(entityName: "UserSettings")
        request.fetchLimit = 1
        if let existing = try? context.fetch(request).first {
            return existing
        }

        let settings = UserSettings(context: context)
        settings.coachPersonaID = CoachPersona.bestie.rawValue
        settings.isProSubscriber = false
        settings.onboardingComplete = false
        settings.lastSessionDate = nil

        do {
            try context.save()
        } catch {
            assertionFailure("Failed to seed UserSettings: \(error)")
        }
        return settings
    }

    @MainActor
    func saveIfNeeded(_ context: NSManagedObjectContext? = nil) {
        let context = context ?? viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save context: \(error)")
        }
    }
}
