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
    @Published var isPresentingQuickActionPaywall = false

    private var cancellables = Set<AnyCancellable>()
    private var shouldMarkOnboardingCompleteAfterBootstrap = false

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
        if shouldMarkOnboardingCompleteAfterBootstrap {
            settings.onboardingComplete = true
            onboardingComplete = true
            shouldMarkOnboardingCompleteAfterBootstrap = false
            persistenceController.saveIfNeeded()
        } else {
            onboardingComplete = settings.onboardingComplete
        }
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

// Quick action handling removed for this release build

extension AppModel {
    @MainActor
    func triggerPendingPlacementIfReady() async {
        guard let placement = pendingPlacement else { return }
        isPresentingQuickActionPaywall = true

        var attempts = 0
        while isBootstrapping && attempts < 20 {
            attempts += 1
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        await SuperwallService.shared.waitForConfiguration()

        // Allow a brief moment for the SwiftUI hierarchy to finish mounting
        try? await Task.sleep(nanoseconds: 150_000_000)

        print("[AppModel] Triggering pending placement after readiness: \(placement)")
        SuperwallService.shared.registerEvent(placement)
        pendingPlacement = nil

        // Release the splash after a short grace period; the paywall will be on top
        try? await Task.sleep(nanoseconds: 900_000_000) // 0.9s
        isPresentingQuickActionPaywall = false
    }
}
