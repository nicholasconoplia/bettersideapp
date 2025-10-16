//
//  TipEngine.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import CoreData
import Foundation

enum TipMode: String, CaseIterable, Identifiable {
    case shortTerm
    case longTerm
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .shortTerm: return "Short-Term Glow"
        case .longTerm: return "Long-Term Strategy"
        }
    }
}

@MainActor
final class TipEngine {
    private let persistenceController: PersistenceController
    private let openAIService: OpenAIService

    init(
        persistenceController: PersistenceController,
        openAIService: OpenAIService = .shared
    ) {
        self.persistenceController = persistenceController
        self.openAIService = openAIService
    }

    func refreshTips(mode: TipMode, quiz: QuizResult?) async {
        let context = persistenceController.viewContext
        
        let generatedTips: [GeneratedTip]
        if let plan = loadLatestPlan() {
            let actions = mode == .shortTerm ? plan.shortTerm : plan.longTerm
            generatedTips = actions.map { action in
                GeneratedTip(
                    id: action.id,
                    title: action.title,
                    body: action.body,
                    source: "BetterSide Coach",
                    type: mode.storageType
                )
            }
        } else {
            let profile = fetchCurrentProfile(in: context)
            generatedTips = await openAIService.generateTips(profile: profile, quiz: quiz, mode: mode)
        }

        removeExistingTips(ofType: mode.storageType, in: context)
        for tip in generatedTips {
            let entry = TipEntry(context: context)
            entry.id = tip.id
            entry.type = tip.type
            entry.title = tip.title
            entry.body = tip.body
            entry.source = tip.source
            entry.completed = false
            entry.createdAt = Date()
        }

        persistenceController.saveIfNeeded(context)
    }

    private func removeExistingTips(ofType type: String, in context: NSManagedObjectContext) {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "TipEntry")
        request.predicate = NSPredicate(format: "type == %@", type)
        let batchDelete = NSBatchDeleteRequest(fetchRequest: request)
        do {
            try context.execute(batchDelete)
        } catch {
            print("Failed to clear tips: \(error.localizedDescription)")
        }
    }

    private func fetchCurrentProfile(in context: NSManagedObjectContext) -> GlowProfile? {
        let request = NSFetchRequest<GlowProfile>(entityName: "GlowProfile")
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
    
    private func loadLatestPlan() -> PersonalizedRecommendationPlan? {
        guard let data = UserDefaults.standard.data(forKey: "LatestRecommendationPlan") else {
            return nil
        }
        return try? JSONDecoder().decode(PersonalizedRecommendationPlan.self, from: data)
    }
}

extension TipMode {
    var storageType: String {
        switch self {
        case .shortTerm:
            return "short"
        case .longTerm:
            return "long"
        }
    }
}
