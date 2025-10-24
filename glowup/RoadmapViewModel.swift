//
//  RoadmapViewModel.swift
//  glowup
//
//  Created by Codex on 02/11/2025.
//

import Combine
import CoreData
import Foundation

@MainActor
final class RoadmapViewModel: ObservableObject {
    enum ViewState {
        case loading
        case empty
        case ready
    }

    struct Week: Identifiable {
        struct Task: Identifiable, Equatable {
            let id: UUID
            let weekID: UUID
            let objectID: NSManagedObjectID
            let weekNumber: Int
            let title: String
            let body: String
            let category: String
            let timeframe: String
            let isCompleted: Bool
            let productSuggestions: [String]
            let subscriptionLocked: Bool
        }

        let id: UUID
        let objectID: NSManagedObjectID
        let number: Int
        let title: String
        let summary: String
        let isUnlocked: Bool
        let isCompleted: Bool
        let unlockedAt: Date?
        let expectedUnlockDate: Date?
        let progress: Double
        let tasks: [Task]
        let subscriptionLocked: Bool
        let isCurrent: Bool
        let lockMessage: String?
    }

    @Published private(set) var state: ViewState = .loading
    @Published private(set) var headerSubtitle: String = ""
    @Published private(set) var overallProgress: Double = 0
    @Published private(set) var weeks: [Week] = []
    @Published var selectedWeek: Week?
    @Published var showingSubscriptionPaywall = false
    @Published private(set) var emptyStateMessage: String = "Complete your first photo analysis to generate your roadmap."

    private weak var appModel: AppModel?
    private weak var subscriptionManager: SubscriptionManager?
    private var context: NSManagedObjectContext?
    private var cancellables = Set<AnyCancellable>()
    private var isConfigured = false

    func configure(
        appModel: AppModel,
        subscriptionManager: SubscriptionManager,
        context: NSManagedObjectContext
    ) {
        guard !isConfigured else { return }
        self.appModel = appModel
        self.subscriptionManager = subscriptionManager
        self.context = context
        isConfigured = true

        subscriptionManager.$isSubscribed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSubscribed in
                guard let self else { return }
                if !isSubscribed {
                    RoadmapNotificationManager.shared.cancelRoadmapReminders()
                }
                Task { await self.reload() }
            }
            .store(in: &cancellables)

        Task { await reload() }
    }

    func reload() async {
        guard let context else { return }
        state = .loading

        let request = NSFetchRequest<RoadmapPlan>(entityName: "RoadmapPlan")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = 1

        do {
            if let plan = try context.fetch(request).first {
                evaluateUnlocks(for: plan)
                updatePlanMetadata(plan)
                try context.save()
                applySnapshot(from: plan)
            } else {
                setEmptyState()
            }
        } catch {
            print("[RoadmapViewModel] Failed to load roadmap: \(error)")
            setEmptyState()
        }
    }

    private func setEmptyState() {
        weeks = []
        headerSubtitle = "Generate your roadmap"
        overallProgress = 0
        selectedWeek = nil
        state = .empty
    }

    func presentWeekDetail(_ week: Week) {
        guard canInteract(with: week) else {
            requestSubscriptionUpsell(source: "week_detail_\(week.number)")
            return
        }
        selectedWeek = week
    }

    func toggleTaskCompletion(_ task: Week.Task, in week: Week) {
        guard canInteract(with: week) else {
            requestSubscriptionUpsell(source: "task_toggle_week_\(week.number)")
            return
        }
        guard let context,
              let coreTask = try? context.existingObject(with: task.objectID) as? RoadmapTask,
              let roadmapWeek = coreTask.week,
              let plan = roadmapWeek.plan
        else { return }

        let wasCompleted = coreTask.isCompleted
        let newValue = !wasCompleted
        coreTask.isCompleted = newValue
        coreTask.completedAt = newValue ? Date() : nil

        let tasks = (roadmapWeek.tasks?.allObjects as? [RoadmapTask]) ?? []
        let completedCount = tasks.filter { $0.isCompleted }.count
        let allCompleted = !tasks.isEmpty && completedCount == tasks.count
        let weekWasCompleted = roadmapWeek.isCompleted

        roadmapWeek.isCompleted = allCompleted
        roadmapWeek.completedAt = allCompleted ? (roadmapWeek.completedAt ?? Date()) : nil

        evaluateUnlocks(for: plan)
        plan.lastUpdatedAt = Date()

        do {
            try context.save()
        } catch {
            print("[RoadmapViewModel] Failed saving task toggle: \(error)")
        }

        if newValue {
            appModel?.trackTaskCompletion(weekNumber: Int(roadmapWeek.weekNumber))
        }

        if allCompleted, !weekWasCompleted {
            appModel?.trackWeekCompleted(weekNumber: Int(roadmapWeek.weekNumber))
            scheduleNextNotification(afterCompleting: roadmapWeek)
        }

        Task { await reload() }
    }

    func requestSubscriptionUpsell(source: String) {
        appModel?.trackSubscriptionUpsell(source: source)
        showingSubscriptionPaywall = true
    }

    // MARK: - Internal Helpers

    private func canInteract(with week: Week) -> Bool {
        guard week.isUnlocked else { return false }
        if week.subscriptionLocked {
            return false
        }
        return true
    }

    private func evaluateUnlocks(for plan: RoadmapPlan) {
        let sortedWeeks = sortedWeeks(from: plan)
        guard !sortedWeeks.isEmpty else { return }

        for index in sortedWeeks.indices where index > 0 {
            let current = sortedWeeks[index]
            if current.isUnlocked { continue }

            let previous = sortedWeeks[index - 1]
            let previousComplete = previous.isCompleted
            let sevenDays: TimeInterval = 7 * 24 * 60 * 60
            var shouldUnlock = false

            if previousComplete {
                shouldUnlock = true
            } else if let unlockedAt = previous.unlockedAt, Date().timeIntervalSince(unlockedAt) >= sevenDays {
                shouldUnlock = true
            }

            if shouldUnlock {
                current.isUnlocked = true
                current.unlockedAt = current.unlockedAt ?? Date()
            }
        }
    }

    private func updatePlanMetadata(_ plan: RoadmapPlan) {
        let weeks = sortedWeeks(from: plan)
        let currentWeekNumber = determineCurrentWeekNumber(from: weeks)
        plan.totalWeeks = Int16(currentWeekNumber)
        plan.currentWeek = Int16(currentWeekNumber)
        plan.lastUpdatedAt = Date()
    }

    private func applySnapshot(from plan: RoadmapPlan) {
        let weeks = makeWeekModels(from: plan)
        let tasks = weeks.flatMap(\.tasks)
        let completedCount = tasks.filter(\.isCompleted).count
        let totalCount = tasks.count
        overallProgress = totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)

        headerSubtitle = makeHeaderSubtitle(
            currentWeek: Int(plan.currentWeek),
            completedTasks: completedCount,
            totalTasks: totalCount
        )

        if let activeWeek = selectedWeek {
            selectedWeek = weeks.first(where: { $0.id == activeWeek.id })
        } else if let current = weeks.first(where: { $0.isCurrent }) {
            selectedWeek = current
        }

        self.weeks = weeks
        state = weeks.isEmpty ? .empty : .ready
    }

    private func determineCurrentWeekNumber(from weeks: [RoadmapWeek]) -> Int {
        guard let highest = weeks.map({ Int($0.weekNumber) }).max() else {
            return 1
        }
        return max(1, highest)
    }

    private func sortedWeeks(from plan: RoadmapPlan) -> [RoadmapWeek] {
        let weeks = plan.weeks?.allObjects as? [RoadmapWeek] ?? []
        return weeks.sorted { $0.weekNumber < $1.weekNumber }
    }

    private func makeWeekModels(from plan: RoadmapPlan) -> [Week] {
        let weeks = sortedWeeks(from: plan)
        let currentWeekNumber = determineCurrentWeekNumber(from: weeks)

        var models: [Week] = []

        for week in weeks {
            let tasks = (week.tasks?.allObjects as? [RoadmapTask] ?? [])
                .sorted { $0.priority < $1.priority }

            let completedCount = tasks.filter(\.isCompleted).count
            let totalCount = tasks.count
            let progress = totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)

            let subscriptionLocked = false

            let weekID = week.id ?? UUID()

            let taskModels: [Week.Task] = tasks.map { task in
                let suggestions = (task.productSuggestions ?? "")
                    .components(separatedBy: CharacterSet.newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                return Week.Task(
                    id: task.id ?? UUID(),
                    weekID: weekID,
                    objectID: task.objectID,
                    weekNumber: Int(week.weekNumber),
                    title: task.title ?? "Task",
                    body: task.body ?? "",
                    category: task.category ?? "General",
                    timeframe: task.timeframe ?? "",
                    isCompleted: task.isCompleted,
                    productSuggestions: suggestions,
                    subscriptionLocked: subscriptionLocked
                )
            }

            let isCurrent = Int(week.weekNumber) == currentWeekNumber

            let model = Week(
                id: weekID,
                objectID: week.objectID,
                number: Int(week.weekNumber),
                title: week.title ?? "Week \(week.weekNumber)",
                summary: week.summary ?? "",
                isUnlocked: true,
                isCompleted: week.isCompleted,
                unlockedAt: week.unlockedAt,
                expectedUnlockDate: nil,
                progress: progress,
                tasks: taskModels,
                subscriptionLocked: subscriptionLocked,
                isCurrent: isCurrent,
                lockMessage: nil
            )
            models.append(model)
        }

        return models
    }

    private func makeHeaderSubtitle(
        currentWeek: Int,
        completedTasks: Int,
        totalTasks: Int
    ) -> String {
        let safeCurrent = max(1, currentWeek)
        let taskSummary: String
        if totalTasks == 0 {
            taskSummary = "No tasks yet"
        } else {
            taskSummary = "\(completedTasks) of \(totalTasks) tasks complete"
        }
        return "Week \(safeCurrent) • \(taskSummary)"
    }

    private func scheduleNextNotification(afterCompleting week: RoadmapWeek) {
        let nextWeekNumber = Int(week.weekNumber) + 1
        RoadmapNotificationManager.shared.scheduleWeeklyCheckIn(forWeek: nextWeekNumber)
    }
}
