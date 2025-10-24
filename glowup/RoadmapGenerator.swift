//
//  RoadmapGenerator.swift
//  glowup
//
//  Created by Codex on 02/11/2025.
//

import CoreData
import Foundation

@MainActor
enum RoadmapGenerator {
    struct GenerationOutcome {
        enum Reason {
            case incompleteWeek(progress: Double)
            case waitingPeriod(nextUnlockDate: Date)
        }

        let addedNewWeek: Bool
        let currentWeekNumber: Int
        let planExists: Bool
        let reason: Reason?
    }

    static func generate(
        from analysis: DetailedPhotoAnalysis,
        sourceSessionID: UUID? = nil,
        context: NSManagedObjectContext
    ) async -> GenerationOutcome {
        let request = NSFetchRequest<RoadmapPlan>(entityName: "RoadmapPlan")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = 1

        let existingPlan = try? context.fetch(request).first

        if let plan = existingPlan {
            return await appendWeekIfEligible(
                to: plan,
                with: analysis.variables,
                sourceSessionID: sourceSessionID,
                context: context
            )
        } else {
            return await createInitialPlan(
                using: analysis.variables,
                sourceSessionID: sourceSessionID,
                context: context
            )
        }
    }

    // MARK: - Plan Creation

    private static func createInitialPlan(
        using variables: PhotoAnalysisVariables,
        sourceSessionID: UUID?,
        context: NSManagedObjectContext
    ) async -> GenerationOutcome {
        var weekDraft = buildSingleWeek(number: 1, using: variables)
        if weekDraft.tasks.isEmpty {
            weekDraft = makeFallbackWeek(number: 1)
        }

        let plan = RoadmapPlan(context: context)
        plan.id = UUID()
        plan.createdAt = Date()
        plan.lastUpdatedAt = Date()
        plan.currentWeek = 1
        plan.totalWeeks = 1
        plan.sourceAnalysisID = sourceSessionID

        appendWeek(weekDraft, to: plan, context: context)

        do {
            try context.save()
            print("[RoadmapGenerator] Created initial roadmap plan.")
        } catch {
            print("[RoadmapGenerator] Failed to create initial plan: \(error)")
        }

        return GenerationOutcome(
            addedNewWeek: true,
            currentWeekNumber: 1,
            planExists: true,
            reason: nil
        )
    }

    private static func appendWeekIfEligible(
        to plan: RoadmapPlan,
        with variables: PhotoAnalysisVariables,
        sourceSessionID: UUID?,
        context: NSManagedObjectContext
    ) async -> GenerationOutcome {
        plan.sourceAnalysisID = sourceSessionID

        let weeks = sortedWeeks(in: plan)
        let currentWeekNumber = max(Int(plan.currentWeek), weeks.map { Int($0.weekNumber) }.max() ?? 1)

        guard let latestWeek = weeks.last else {
            // Plan exists but has no weeks; create the first one.
            return await createInitialPlan(using: variables, sourceSessionID: sourceSessionID, context: context)
        }

        let tasks = (latestWeek.tasks?.allObjects as? [RoadmapTask]) ?? []
        let totalCount = tasks.count
        let completedCount = tasks.filter { $0.isCompleted }.count
        let allCompleted = totalCount == 0 || completedCount == totalCount

        if !allCompleted {
            let progress = totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
            return GenerationOutcome(
                addedNewWeek: false,
                currentWeekNumber: currentWeekNumber,
                planExists: true,
                reason: .incompleteWeek(progress: progress)
            )
        }

        let sevenDays: TimeInterval = 7 * 24 * 60 * 60
        let unlockReference = latestWeek.unlockedAt ?? plan.createdAt ?? plan.lastUpdatedAt ?? Date()
        let nextUnlockDate = unlockReference.addingTimeInterval(sevenDays)
        if Date() < nextUnlockDate {
            return GenerationOutcome(
                addedNewWeek: false,
                currentWeekNumber: currentWeekNumber,
                planExists: true,
                reason: .waitingPeriod(nextUnlockDate: nextUnlockDate)
            )
        }

        let nextWeekNumber = currentWeekNumber + 1
        var weekDraft = buildSingleWeek(number: nextWeekNumber, using: variables)
        if weekDraft.tasks.isEmpty {
            weekDraft = makeFallbackWeek(number: nextWeekNumber)
        }

        appendWeek(weekDraft, to: plan, context: context)

        plan.totalWeeks = Int16(nextWeekNumber)
        plan.currentWeek = Int16(nextWeekNumber)
        plan.lastUpdatedAt = Date()

        do {
            try context.save()
            print("[RoadmapGenerator] Appended week \(nextWeekNumber) to roadmap.")
        } catch {
            print("[RoadmapGenerator] Failed to append week \(nextWeekNumber): \(error)")
        }

        return GenerationOutcome(
            addedNewWeek: true,
            currentWeekNumber: nextWeekNumber,
            planExists: true,
            reason: nil
        )
    }

    private static func appendWeek(
        _ draft: RoadmapWeekDraft,
        to plan: RoadmapPlan,
        context: NSManagedObjectContext
    ) {
        let week = RoadmapWeek(context: context)
        week.id = draft.id
        week.weekNumber = Int16(draft.number)
        week.title = draft.title
        week.summary = draft.summary
        week.isUnlocked = true
        week.isCompleted = false
        week.unlockedAt = Date()
        week.completedAt = nil
        week.plan = plan

        for taskDraft in draft.tasks {
            let task = RoadmapTask(context: context)
            task.id = taskDraft.id
            task.title = taskDraft.title
            task.body = taskDraft.body ?? makeFallbackBody(for: taskDraft.context)
            task.category = taskDraft.category
            task.timeframe = taskDraft.timeframe
            task.priority = Int16(taskDraft.priority)
            task.isCompleted = false
            task.completedAt = nil
            if let suggestions = taskDraft.productSuggestions, !suggestions.isEmpty {
                task.productSuggestions = suggestions.joined(separator: "\n")
            } else {
                task.productSuggestions = nil
            }
            task.week = week
        }
    }

    private static func sortedWeeks(in plan: RoadmapPlan) -> [RoadmapWeek] {
        let weeks = plan.weeks?.allObjects as? [RoadmapWeek] ?? []
        return weeks.sorted { $0.weekNumber < $1.weekNumber }
    }

    // MARK: - Blueprint (Focus Areas)

    private struct MetricFocus {
        let key: String
        let displayTitle: String
        let category: String
        let score: Double
        let notes: String
    }

    private struct FocusAdvice {
        struct Task {
            let title: String
            let timeframe: String
            let body: String
            let productSuggestions: [String]
        }

        let tasks: [Task]
    }

    private static func buildSingleWeek(number: Int, using vars: PhotoAnalysisVariables) -> RoadmapWeekDraft {
        var candidates: [MetricFocus] = []

        func addCandidate(
            key: String,
            title: String,
            category: String,
            score: Double,
            notes: String
        ) {
            guard score > 0 else { return }
            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalNotes = trimmed.isEmpty ? "No additional notes." : trimmed
            candidates.append(
                MetricFocus(
                    key: key,
                    displayTitle: title,
                    category: category,
                    score: score,
                    notes: finalNotes
                )
            )
        }

        addCandidate(
            key: "Skin Texture",
            title: "Skin Texture",
            category: "Skin",
            score: vars.skinTextureScore,
            notes: [
                vars.skinTextureDescription,
                makeListSummary(vars.skinConcernHighlights, limit: 3, fallback: "")
            ].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        )
        addCandidate(
            key: "Eyebrow Density",
            title: "Eyebrow Density",
            category: "Brows",
            score: vars.eyebrowDensityScore,
            notes: vars.eyebrowFeedback
        )
        addCandidate(
            key: "Facial Harmony",
            title: "Facial Harmony",
            category: "Structure",
            score: vars.facialHarmonyScore,
            notes: vars.featureBalanceDescription
        )
        addCandidate(
            key: "Lighting Quality",
            title: "Lighting Quality",
            category: "Lighting",
            score: vars.lightingQuality,
            notes: vars.lightingFeedback
        )
        addCandidate(
            key: "Makeup Suitability",
            title: "Makeup Suitability",
            category: "Makeup",
            score: vars.makeupSuitability,
            notes: [
                "Style: \(vars.makeupStyle)",
                vars.makeupFeedback
            ].joined(separator: "\n")
        )
        addCandidate(
            key: "Pose Naturalness",
            title: "Pose Naturalness",
            category: "Pose",
            score: vars.poseNaturalness,
            notes: vars.poseFeedback
        )
        addCandidate(
            key: "Color Harmony",
            title: "Color Harmony",
            category: "Style",
            score: vars.colorHarmony,
            notes: makeListSummary(vars.bestColors, limit: 5, fallback: "Palette pending")
        )

        let needingHelp = candidates.filter { $0.score <= 7.0 }
        let sorted = (needingHelp.isEmpty ? candidates : needingHelp).sorted { $0.score < $1.score }
        let topFocuses = Array(sorted.prefix(3))

        guard !topFocuses.isEmpty else {
            return makeFallbackWeek(number: number)
        }

        let primaryFocus = topFocuses.first!.displayTitle
        let focusNames = topFocuses.map(\.displayTitle)
        let focusList = listSummary(for: focusNames)

        var week = RoadmapWeekDraft(
            number: number,
            title: "Week \(number): \(primaryFocus) Sprint",
            summary: "This week zeroes in on \(focusList). Finish every move, then rescan in seven days to unlock the next plan.",
            isUnlocked: true
        )

        var taskCounter = 0
        let maximumTasks = 6

        for focus in topFocuses {
            let advice = makeAdvice(for: focus, using: vars, weekNumber: number)
            for task in advice.tasks {
                week.addTask(
                    title: task.title,
                    category: focus.category,
                    timeframe: task.timeframe,
                    priority: taskCounter + 1,
                    context: "Focus: \(focus.displayTitle)\nScore: \(formatScore(focus.score))\nNotes: \(focus.notes)",
                    body: task.body,
                    productSuggestions: task.productSuggestions
                )
                taskCounter += 1
                if taskCounter >= maximumTasks {
                    break
                }
            }
            if taskCounter >= maximumTasks {
                break
            }
        }

        return week
    }

    private static func makeFallbackWeek(number: Int) -> RoadmapWeekDraft {
        var fallbackWeek = RoadmapWeekDraft(
            number: number,
            title: "Week \(number): Glow Momentum",
            summary: "Your analysis looks balanced. Use this maintenance checklist, then rescan in seven days to build the next stage.",
            isUnlocked: true
        )
        fallbackWeek.addTask(
            title: "Daily glow check",
            category: "Lifestyle",
            timeframe: "Each morning",
            priority: 1,
            context: "Fallback plan",
            body: """
Face a window, take a 30-second selfie video, and note hydration, lighting, and energy. Drink a glass of water and apply SPF 30+ before leaving the house.
""",
            productSuggestions: [
                "Search 'daily SPF dewy finish'",
                "Search 'habit tracker water intake'"
            ]
        )
        fallbackWeek.addTask(
            title: "Mid-week refresh",
            category: "Lifestyle",
            timeframe: "Every Wednesday",
            priority: 2,
            context: "Fallback plan",
            body: """
Clean makeup brushes, swap your pillowcase, and plan outfits pulling from your three best colors. These micro resets prevent dullness from creeping back.
""",
            productSuggestions: [
                "Search 'silk pillowcase benefits skin'",
                "Search 'how to clean makeup brushes fast'"
            ]
        )
        fallbackWeek.addTask(
            title: "Weekend highlight session",
            category: "Lifestyle",
            timeframe: "Every Sunday",
            priority: 3,
            context: "Fallback plan",
            body: """
Spend 15 minutes practicing a new lighting setup or pose, capture 5 shots, and save the favorite to track improvements week over week.
""",
            productSuggestions: [
                "Search 'at-home portrait lighting tips'"
            ]
        )
        return fallbackWeek
    }

    // MARK: - Advice Builder

    private static func makeAdvice(
        for focus: MetricFocus,
        using vars: PhotoAnalysisVariables,
        weekNumber: Int
    ) -> FocusAdvice {
        let trimmedNotes = focus.notes
            .replacingOccurrences(of: "\n\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch focus.key {
        case "Skin Texture":
            let tasks: [FocusAdvice.Task] = [
                .init(
                    title: "Daily texture reset",
                    timeframe: "Morning & night",
                    body: """
Morning:
- Cleanse with lukewarm water and a gel cleanser.
- Pat in a hydrating toner, then apply vitamin C or antioxidant serum.
Night:
- Double cleanse, then swipe a 0.5%-1% polyhydroxy or lactic acid toner over uneven patches.
- Seal with a ceramide-rich moisturizer so the barrier stays calm.
Why it matters: \(trimmedNotes)
""",
                    productSuggestions: [
                        "Search 'polyhydroxy acid toner sensitive skin'",
                        "Search 'ceramide barrier repair moisturizer'"
                    ]
                ),
                .init(
                    title: "Twice-weekly resurfacing night",
                    timeframe: "2 evenings per week",
                    body: """
Choose two evenings spaced three nights apart. After cleansing, apply a gentle BHA or enzyme mask for 8-10 minutes, rinse, mist with thermal water, and finish with a sleeping mask. Expect noticeably smoother texture within 2-3 weeks.
""",
                    productSuggestions: [
                        "Search 'enzyme mask for dull skin'",
                        "Search 'overnight sleeping mask hydration'"
                    ]
                ),
                .init(
                    title: "Sunday glow check-in",
                    timeframe: "Weekly wrap",
                    body: """
Shoot a selfie in consistent window light, compare it to last week, and jot quick notes on any rough patches. End with a two-minute upward massage using facial oil to boost circulation and keep progress rolling.
""",
                    productSuggestions: [
                        "Search 'facial massage oil techniques'"
                    ]
                )
            ]
            return FocusAdvice(tasks: tasks)

        case "Eyebrow Density":
            let tasks: [FocusAdvice.Task] = [
                .init(
                    title: "Daily brow refresh",
                    timeframe: "Every morning",
                    body: """
Brush brows upward with a spoolie, fill sparse gaps using hair-like strokes, then set with a tinted gel. Highlight the brow bone with a cream stick so the arch pops on camera.
""",
                    productSuggestions: [
                        "Search 'tinted brow gel before and after'",
                        "Search 'brow pencil hairlike strokes tutorial'"
                    ]
                ),
                .init(
                    title: "Weekly brow mapping",
                    timeframe: "Every Sunday",
                    body: """
Use a brow pencil to mark the start, arch, and tail before tweezing. Trim only hairs that fall clearly outside the guide so density keeps improving instead of thinning.
""",
                    productSuggestions: [
                        "Search 'how to map brows at home'"
                    ]
                ),
                .init(
                    title: "Nightly growth ritual",
                    timeframe: "Nightly",
                    body: """
Massage a drop of castor or peptide serum into each brow for 60 seconds. Pair it with a five-minute gentle forehead gua sha pass to stimulate circulation.
""",
                    productSuggestions: [
                        "Search 'castor oil brow growth routine'",
                        "Search 'gua sha for eyebrows tutorial'"
                    ]
                )
            ]
            return FocusAdvice(tasks: tasks)

        case "Facial Harmony":
            let faceShape = vars.faceShape ?? "your face shape"
            let tasks: [FocusAdvice.Task] = [
                .init(
                    title: "Angle practice session",
                    timeframe: "Three sessions",
                    body: """
Record a 60-second selfie video turning chin down 5 degrees, up 5 degrees, and toward your best side. Pause where cheekbones catch light evenly and save screenshots for pose references.
""",
                    productSuggestions: [
                        "Search 'best selfie angles for \(faceShape.lowercased()) face'",
                        "Search 'triangle lighting selfie setup'"
                    ]
                ),
                .init(
                    title: "Framing refresh",
                    timeframe: "Mid-week",
                    body: """
Adjust your hair part one finger toward the fuller side, add crown volume with dry shampoo, and tuck one side to show more jawline. These tweaks counter \(vars.faceFullnessDescriptor.lowercased()) features.
""",
                    productSuggestions: [
                        "Search 'dry shampoo for lift tutorial'",
                        "Search 'face framing layers styling tips'"
                    ]
                ),
                .init(
                    title: "Highlight & contour drill",
                    timeframe: "Weekend",
                    body: """
Map concealer above cheekbones and blend a soft contour under them, stopping mid-cheek. Snap before/after photos to confirm the planes look even without harsh lines.
""",
                    productSuggestions: [
                        "Search 'subtle cream contour tutorial'",
                        "Search 'highlight placement for symmetry'"
                    ]
                )
            ]
            return FocusAdvice(tasks: tasks)

        case "Lighting Quality":
            let tasks: [FocusAdvice.Task] = [
                .init(
                    title: "Find your window zone",
                    timeframe: "Today",
                    body: """
Test three window spots at the same time of day. Hold your phone front-facing, note where eye whites look brightest, and mark the floor with painter's tape for future shoots.
""",
                    productSuggestions: [
                        "Search 'window lighting portrait guide'"
                    ]
                ),
                .init(
                    title: "Five-minute test shoot",
                    timeframe: "Every other day",
                    body: """
Set a timer, capture five poses rotating 45 degrees each shot. Review which direction kills shadows under the chin. Keep the best clip to reuse for future content.
""",
                    productSuggestions: [
                        "Search 'self portrait lighting tips at home'",
                        "Search 'phone reflector diy tutorial'"
                    ]
                ),
                .init(
                    title: "Travel-ready lighting kit",
                    timeframe: "Before next outing",
                    body: """
Pack a foldable white napkin or mini foam board as a bounce card plus a pocket-sized clip light. Practice clipping it slightly above eye level to replicate your ideal window glow anywhere.
""",
                    productSuggestions: [
                        "Search 'portable selfie light comparison'",
                        "Search 'foam board bounce card diy'"
                    ]
                )
            ]
            return FocusAdvice(tasks: tasks)

        case "Makeup Suitability":
            let style = vars.makeupStyle.lowercased()
            let undertone = (vars.skinUndertone ?? "your undertone").lowercased()
            let tasks: [FocusAdvice.Task] = [
                .init(
                    title: "Prep & base upgrade",
                    timeframe: "Each makeup day",
                    body: """
Layer hydrating primer on glow zones, color-correct discoloration, then stipple foundation with a damp sponge. Finish with a sheer powder only on the T-zone to keep highlights alive.
""",
                    productSuggestions: [
                        "Search 'color corrector for \(undertone) skin'",
                        "Search 'hydrating primer vs mattifying comparison'"
                    ]
                ),
                .init(
                    title: "Palette sync test",
                    timeframe: "Mid-week",
                    body: """
Create two monochrome looks: one in \(makeListSummary(vars.bestColors, limit: 1, fallback: "your best color")) and one in \(makeListSummary(vars.avoidColors, limit: 1, fallback: "a high-contrast shade")). Photograph both in daylight to see which brightens your complexion.
""",
                    productSuggestions: [
                        "Search 'monochrome makeup tutorial \(style)'",
                        "Search 'best blush for \(undertone) undertone'"
                    ]
                ),
                .init(
                    title: "Weekend rehearsal",
                    timeframe: "Weekend",
                    body: """
Recreate your go-to look on camera in real time, narrating each step. Watching it back reveals where blending or shade tweaks will make the finish more camera-friendly.
""",
                    productSuggestions: [
                        "Search 'soft glam makeup practice routine'",
                        "Search 'everyday makeup tutorial \(style)'"
                    ]
                )
            ]
            return FocusAdvice(tasks: tasks)

        case "Pose Naturalness":
            let tasks: [FocusAdvice.Task] = [
                .init(
                    title: "Micro-expression practice",
                    timeframe: "Three sessions",
                    body: """
Film a 90-second clip cycling through soft smile, smize, and relaxed jaw. Count to three between each shift. Rewatch at half speed to memorize which looks most natural.
""",
                    productSuggestions: [
                        "Search 'posing micro expression drill'",
                        "Search 'smize practice tips'"
                    ]
                ),
                .init(
                    title: "Posture anchor",
                    timeframe: "Daily",
                    body: """
Stand against a wall, engage core, roll shoulders back, and lengthen neck for 30 seconds. Replicate the stance in front of a mirror holding your phone to lock in muscle memory.
""",
                    productSuggestions: [
                        "Search 'posture exercises for photos'",
                        "Search 'standing pose tips for beginners'"
                    ]
                ),
                .init(
                    title: "Five-shot routine",
                    timeframe: "Before every photo",
                    body: """
Set your camera timer for bursts of five. Flow through chin down, chin out, over-shoulder, hand-to-face, and laugh shot. Keep the best frame and note which angles felt effortless.
""",
                    productSuggestions: [
                        "Search 'self timer posing sequence'",
                        "Search 'hand placement pose ideas'"
                    ]
                )
            ]
            return FocusAdvice(tasks: tasks)

        case "Color Harmony":
            let palette = vars.seasonalPalette ?? "seasonal"
            let topColors = makeListSummary(vars.bestColors, limit: 3, fallback: "your top colors")
            let tasks: [FocusAdvice.Task] = [
                .init(
                    title: "Closet pull",
                    timeframe: "Today",
                    body: """
Pull three items in \(topColors) and steam them so they are ready. Hang them at the front of your closet for easy access whenever you shoot content.
""",
                    productSuggestions: [
                        "Search 'outfit ideas \(palette.lowercased()) palette'",
                        "Search 'color palette wardrobe edit tips'"
                    ]
                ),
                .init(
                    title: "Two-tone outfit lab",
                    timeframe: "Twice this week",
                    body: """
Style outfits that layer one hero color with a neutral anchor. Snap mirror photos and compare how each combo lifts your complexion compared to last week's go-to looks.
""",
                    productSuggestions: [
                        "Search 'color blocking \(palette.lowercased()) palette'",
                        "Search 'neutral base outfit ideas women'"
                    ]
                ),
                .init(
                    title: "Shoot-ready flatlay",
                    timeframe: "Weekend",
                    body: """
Plan next week's outfit by arranging clothes on the bed, adding jewelry and lipstick. Take a flatlay photo to reference before you get dressed, ensuring everything stays on palette.
""",
                    productSuggestions: [
                        "Search 'flatlay outfit planning tips'",
                        "Search 'wardrobe planner template'"
                    ]
                )
            ]
            return FocusAdvice(tasks: tasks)

        default:
            let tasks: [FocusAdvice.Task] = [
                .init(
                    title: "Clarify the issue",
                    timeframe: "Today",
                    body: """
Write down what you notice most: \(trimmedNotes). Snap a photo capturing the issue so you can compare progress halfway through the week.
""",
                    productSuggestions: [
                        "Search 'how to audit \(focus.displayTitle.lowercased())'"
                    ]
                ),
                .init(
                    title: "Daily adjustment",
                    timeframe: "Daily",
                    body: """
Dedicate five focused minutes each day to a corrective habit tied to \(focus.displayTitle.lowercased()). Track it in your notes app to reinforce consistency.
""",
                    productSuggestions: [
                        "Search 'daily habit tracker app ideas'"
                    ]
                ),
                .init(
                    title: "End-of-week reflection",
                    timeframe: "End of week",
                    body: """
Review your progress photos and jot what improved, what held you back, and one tweak to try next week. Keeping receipts keeps momentum high.
""",
                    productSuggestions: [
                        "Search 'weekly reflection template aesthetic'"
                    ]
                )
            ]
            return FocusAdvice(tasks: tasks)
        }
    }

    // MARK: - Helpers

    private static func makeListSummary(_ items: [String], limit: Int = 2, fallback: String) -> String {
        let trimmed = items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if trimmed.isEmpty { return fallback }
        return trimmed.prefix(limit).joined(separator: ", ")
    }

    private static func listSummary(for items: [String]) -> String {
        guard !items.isEmpty else { return "your overall glow" }
        if items.count == 1 { return items[0] }
        let head = items.dropLast().joined(separator: ", ")
        return "\(head), and \(items.last!)"
    }

    private static func formatScore(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func makeFallbackBody(for context: String) -> String {
        "Here’s your focus: \n\(context)\n\nStart with consistent, gentle improvements this week and reassess in 4 weeks."
    }
}

// MARK: - Draft Models

private struct RoadmapWeekDraft {
    let id = UUID()
    let number: Int
    var title: String
    var summary: String
    var isUnlocked: Bool
    var tasks: [RoadmapTaskDraft] = []

    mutating func addTask(
        title: String,
        category: String,
        timeframe: String,
        priority: Int,
        context: String,
        body: String?,
        productSuggestions: [String] = []
    ) {
        var task = RoadmapTaskDraft(
            id: UUID(),
            title: title,
            category: category,
            timeframe: timeframe,
            priority: priority,
            context: context
        )
        task.body = body
        task.productSuggestions = productSuggestions.isEmpty ? nil : productSuggestions
        tasks.append(task)
    }
}

private struct RoadmapTaskDraft {
    let id: UUID
    var title: String
    var category: String
    var timeframe: String
    var priority: Int
    var context: String
    var body: String?
    var productSuggestions: [String]?

    init(
        id: UUID,
        title: String,
        category: String,
        timeframe: String,
        priority: Int,
        context: String
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.timeframe = timeframe
        self.priority = priority
        self.context = context
        self.body = nil
        self.productSuggestions = nil
    }
}
