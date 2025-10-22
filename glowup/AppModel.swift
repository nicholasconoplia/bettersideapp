//
//  AppModel.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import Combine
import CoreData
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    let persistenceController: PersistenceController
    let subscriptionManager: SubscriptionManager

    @Published private(set) var userSettings: UserSettings?
    @Published private(set) var onboardingComplete = false
    @Published private(set) var isSubscribed = false
    @Published private(set) var isBootstrapping = true
    @Published var latestQuiz: OnboardingQuiz?
    @Published var quickActionAlert: QuickActionAlertContext?
    @Published var pendingPlacement: String?
    @Published var suppressDefaultPaywallForSession = false

    private var cancellables = Set<AnyCancellable>()

    init(persistenceController: PersistenceController, subscriptionManager: SubscriptionManager) {
        self.persistenceController = persistenceController
        self.subscriptionManager = subscriptionManager
        subscriptionManager.setDelegate(self)
        Task {
            await bootstrap()
        }

        subscriptionManager.$isSubscribed
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.handleSubscriptionChange(isSubscribed: value)
            }
            .store(in: &cancellables)
    }

    private func bootstrap() async {
        let context = persistenceController.viewContext
        let settings = persistenceController.ensureUserSettings(in: context)
        userSettings = settings
        onboardingComplete = settings.onboardingComplete
        isSubscribed = settings.isProSubscriber

        latestQuiz = fetchLatestQuiz()

        isBootstrapping = false
        await subscriptionManager.refreshProductsIfNeeded()
        await subscriptionManager.refreshEntitlementState()
    }

    func markOnboardingComplete() {
        guard let settings = userSettings else { return }
        settings.onboardingComplete = true
        onboardingComplete = true
        persistenceController.saveIfNeeded()
    }

    func resetOnboarding() {
        guard let settings = userSettings else { return }
        settings.onboardingComplete = false
        onboardingComplete = false
        persistenceController.saveIfNeeded()
    }

    func updateCoachPersona(_ persona: CoachPersona) {
        guard let settings = userSettings else { return }
        settings.coachPersonaID = persona.rawValue
        persistenceController.saveIfNeeded()
    }

    func saveQuizResult(_ result: QuizResult) {
        let context = persistenceController.viewContext
        let quiz = OnboardingQuiz(context: context)
        quiz.answers = result.answers as NSDictionary
        quiz.targetGoal = result.primaryGoal
        quiz.createdAt = Date()
        quiz.setValue(result.userName, forKey: "userName")
        if let age = result.age {
            quiz.setValue(Int16(age), forKey: "age")
        } else {
            quiz.setValue(Int16(0), forKey: "age")
        }
        latestQuiz = quiz
        persistenceController.saveIfNeeded()
    }

    func logSession(date: Date = Date()) {
        guard let settings = userSettings else { return }
        settings.lastSessionDate = date
        persistenceController.saveIfNeeded()
    }

    private func handleSubscriptionChange(isSubscribed: Bool) {
        guard let settings = userSettings else { return }
        if settings.isProSubscriber != isSubscribed {
            settings.isProSubscriber = isSubscribed
            persistenceController.saveIfNeeded()
        }
        self.isSubscribed = isSubscribed
        // If the user already has an active subscription, skip onboarding entirely
        if isSubscribed && !onboardingComplete {
            markOnboardingComplete()
        }
    }

    private func fetchLatestQuiz() -> OnboardingQuiz? {
        let request = NSFetchRequest<OnboardingQuiz>(entityName: "OnboardingQuiz")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = 1
        return try? persistenceController.viewContext.fetch(request).first
    }

    struct QuickActionAlertContext: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let confirmButtonTitle: String
        let url: URL
    }
}

extension AppModel: SubscriptionManagerDelegate {
    func subscriptionManagerDidCompletePurchase(_ manager: SubscriptionManager) {
        markOnboardingComplete()
    }
}

extension AppModel: GlowUpQuickActionHandling {
    @discardableResult
    func handleQuickAction(_ action: GlowUpQuickAction) -> Bool {
        switch action {
        case .homescreenLastChance:
            // Trigger the homescreen last chance Superwall placement
            Task { @MainActor in
                #if canImport(SuperwallKit)
                print("[AppModel] QuickAction: homescreen_last_chance tapped")
                // Bypass onboarding and other gates immediately
                if !onboardingComplete {
                    if let _ = userSettings {
                        markOnboardingComplete()
                    } else {
                        // Bootstrap not finished; set in-memory flag now
                        onboardingComplete = true
                    }
                }
                suppressDefaultPaywallForSession = true
                pendingPlacement = "homescreen_last_chance"
                // RootView will present this placement once the window is active
                #endif
            }
            return true
        }
    }
}
