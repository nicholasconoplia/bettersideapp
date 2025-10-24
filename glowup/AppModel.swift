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
    @Published private(set) var hasActiveRoadmap = false
    @Published private(set) var latestPhotoSession: PhotoSession?
    @Published private(set) var latestAnalysis: DetailedPhotoAnalysis?
    @Published var latestQuiz: OnboardingQuiz?
    @Published var quickActionAlert: QuickActionAlertContext?
    @Published var roadmapAlert: RoadmapAlertContext?
    @Published var pendingPlacement: String?
    @Published var suppressDefaultPaywallForSession = false
    @Published var isPresentingQuickActionPaywall = false
    @Published var isGeneratingRoadmap = false
    @Published var navigateToAnalyzeRequested = false

    private var cancellables = Set<AnyCancellable>()
    private var shouldMarkOnboardingCompleteAfterBootstrap = false

    private static let roadmapDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init(persistenceController: PersistenceController, subscriptionManager: SubscriptionManager) {
        self.persistenceController = persistenceController
        self.subscriptionManager = subscriptionManager
        subscriptionManager.setDelegate(self)
        // Seed state synchronously so UI renders correct screen immediately on cold launch
        let context = persistenceController.viewContext
        let settings = persistenceController.ensureUserSettings(in: context)
        userSettings = settings
        onboardingComplete = settings.onboardingComplete
        isSubscribed = settings.isProSubscriber
        latestQuiz = fetchLatestQuiz()
        latestPhotoSession = fetchLatestPhotoSession()
        latestAnalysis = latestPhotoSession?.decodedAnalysis
        hasActiveRoadmap = fetchActiveRoadmapPlan() != nil
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
        latestPhotoSession = fetchLatestPhotoSession()
        latestAnalysis = latestPhotoSession?.decodedAnalysis
        hasActiveRoadmap = fetchActiveRoadmapPlan() != nil

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
        if !isSubscribed {
            RoadmapNotificationManager.shared.cancelRoadmapReminders()
        }
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

    private func fetchLatestPhotoSession() -> PhotoSession? {
        let request = NSFetchRequest<PhotoSession>(entityName: "PhotoSession")
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        request.fetchLimit = 1
        return try? persistenceController.viewContext.fetch(request).first
    }

    private func fetchActiveRoadmapPlan() -> RoadmapPlan? {
        let request = NSFetchRequest<RoadmapPlan>(entityName: "RoadmapPlan")
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

    struct RoadmapAlertContext: Identifiable {
        let id = UUID()
        let title: String
        let message: String
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

    func registerCompletedAnalysis(session: PhotoSession, analysis: DetailedPhotoAnalysis) {
        latestPhotoSession = session
        latestAnalysis = analysis
    }

    func refreshRoadmapState() {
        hasActiveRoadmap = fetchActiveRoadmapPlan() != nil
    }

    func shouldShowRoadmapBadge() -> Bool {
        guard hasActiveRoadmap else { return false }
        guard let plan = fetchActiveRoadmapPlan() else { return false }
        let weeks = plan.weeks?.allObjects as? [RoadmapWeek] ?? []
        let sortedWeeks = weeks.sorted { $0.weekNumber < $1.weekNumber }
        guard let current = sortedWeeks.first(where: { $0.isUnlocked && !$0.isCompleted }) else {
            return false
        }
        let tasks = current.tasks?.allObjects as? [RoadmapTask] ?? []
        return tasks.contains { !$0.isCompleted }
    }

    func trackWeekCompleted(weekNumber: Int) {
        print("[Analytics] Roadmap week completed:", weekNumber)
    }

    func trackTaskCompletion(weekNumber: Int) {
        print("[Analytics] Roadmap task checked off in week:", weekNumber)
    }

    func trackSubscriptionUpsell(source: String) {
        print("[Analytics] Roadmap upsell triggered from:", source)
    }

    @MainActor
    func generateRoadmapFromLatestAnalysis() async {
        guard let analysis = latestAnalysis ?? latestPhotoSession?.decodedAnalysis else {
            print("[AppModel] No analysis available to generate roadmap.")
            return
        }
        isGeneratingRoadmap = true
        defer { isGeneratingRoadmap = false }
        let sessionID = latestPhotoSession?.id
        let context = persistenceController.viewContext
        let outcome = await RoadmapGenerator.generate(from: analysis, sourceSessionID: sessionID, context: context)
        handleRoadmapGenerationOutcome(outcome)
    }

    @MainActor
    func regenerateRoadmap(after analysis: DetailedPhotoAnalysis) async {
        isGeneratingRoadmap = true
        defer { isGeneratingRoadmap = false }
        let sessionID = latestPhotoSession?.id
        let context = persistenceController.viewContext
        let outcome = await RoadmapGenerator.generate(from: analysis, sourceSessionID: sessionID, context: context)
        handleRoadmapGenerationOutcome(outcome)
    }

    private func handleRoadmapGenerationOutcome(_ outcome: RoadmapGenerator.GenerationOutcome) {
        hasActiveRoadmap = outcome.planExists
        guard outcome.planExists else { return }

        roadmapAlert = nil

        if outcome.addedNewWeek {
            if isSubscribed {
                RoadmapNotificationManager.shared.scheduleWeeklyCheckIn(forWeek: outcome.currentWeekNumber)
                RoadmapNotificationManager.shared.scheduleMonthlyRescanReminder()
            } else {
                RoadmapNotificationManager.shared.cancelRoadmapReminders()
            }

            roadmapAlert = RoadmapAlertContext(
                title: "Week \(outcome.currentWeekNumber) unlocked",
                message: "Your next Glow Plan is ready. Open the Roadmap to review this week's action list."
            )
            return
        }

        guard let reason = outcome.reason else { return }

        switch reason {
        case .incompleteWeek(let progress):
            let percent = Int(round(progress * 100))
            roadmapAlert = RoadmapAlertContext(
                title: "Keep working your plan",
                message: "Finish all of this week's actions (currently \(percent)% complete) before scanning again to unlock Week \(outcome.currentWeekNumber + 1)."
            )
        case .waitingPeriod(let nextUnlockDate):
            let formatted = AppModel.roadmapDateFormatter.string(from: nextUnlockDate)
            roadmapAlert = RoadmapAlertContext(
                title: "Next week unlocks soon",
                message: "Great work! Come back after \(formatted) to rescan and unlock Week \(outcome.currentWeekNumber + 1)."
            )
        }
    }
}
