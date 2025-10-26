//
//  OnboardingViews.swift
//  glowup
//
//  Created by Codex on 26/11/2025.
//

import SwiftUI
import PhotosUI
import UIKit

#if canImport(SuperwallKit)
import SuperwallKit
#endif

struct OnboardingFlowView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var flowModel = OnboardingExperienceViewModel()

    var body: some View {
        ZStack {
            GlowGradient.canvas
                .ignoresSafeArea()
            TabView(selection: $flowModel.currentStep) {
                OnboardingWelcomePlacementStep()
                    .tag(OnboardingExperienceViewModel.Step.welcome)

                SkinTypeStepView()
                    .tag(OnboardingExperienceViewModel.Step.skinType)

                BeautyGoalsStepView()
                    .tag(OnboardingExperienceViewModel.Step.beautyGoals)

                TimeCommitmentStepView()
                    .tag(OnboardingExperienceViewModel.Step.timeCommitment)

                LifestyleInputsStepView()
                    .tag(OnboardingExperienceViewModel.Step.lifestyle)

                SummaryConfirmationStepView()
                    .tag(OnboardingExperienceViewModel.Step.summary)

                NameCaptureStepView()
                    .tag(OnboardingExperienceViewModel.Step.name)

                PlanLoadingStepView()
                    .tag(OnboardingExperienceViewModel.Step.loading)

                ValueComparisonStepView()
                    .tag(OnboardingExperienceViewModel.Step.valueComparison)

                SocialProofStepView()
                    .tag(OnboardingExperienceViewModel.Step.socialProof)

                FaceScanStepView()
                    .tag(OnboardingExperienceViewModel.Step.faceScan)

                FinalCallToActionStepView()
                    .tag(OnboardingExperienceViewModel.Step.finale)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.35), value: flowModel.currentStep)
            .environmentObject(flowModel)
        }
        .onAppear {
            UIScrollView.appearance().isScrollEnabled = false
        }
        .onDisappear {
            UIScrollView.appearance().isScrollEnabled = true
        }
    }
}

// MARK: - View Model

@MainActor
final class OnboardingExperienceViewModel: ObservableObject {
    enum Step: Int, CaseIterable, Identifiable {
        case welcome
        case skinType
        case beautyGoals
        case timeCommitment
        case lifestyle
        case summary
        case name
        case loading
        case valueComparison
        case socialProof
        case faceScan
        case finale

        var id: Int { rawValue }
    }

    enum SkinTypeOption: String, CaseIterable, Identifiable {
        case dry
        case oily
        case combination
        case sensitive
        case normal
        case notSure

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .dry: return "Dry"
            case .oily: return "Oily"
            case .combination: return "Combination"
            case .sensitive: return "Sensitive"
            case .normal: return "Normal"
            case .notSure: return "Not Sure"
            }
        }

        var sortOrder: Int {
            switch self {
            case .dry: return 0
            case .oily: return 1
            case .combination: return 2
            case .sensitive: return 3
            case .normal: return 4
            case .notSure: return 5
            }
        }
    }

    enum BeautyGoalOption: String, CaseIterable, Identifiable {
        case clearerSkin
        case improveMakeup
        case colorConfidence
        case moreConfidence
        case workingSchedule

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .clearerSkin: return "Clearer skin"
            case .improveMakeup: return "Improve makeup"
            case .colorConfidence: return "Know what colors suit me best"
            case .moreConfidence: return "More confidence"
            case .workingSchedule: return "Have a schedule that actually works"
            }
        }

        var sortOrder: Int {
            switch self {
            case .clearerSkin: return 0
            case .improveMakeup: return 1
            case .colorConfidence: return 2
            case .moreConfidence: return 3
            case .workingSchedule: return 4
            }
        }
    }

    enum ConfidenceLevel: String, CaseIterable, Identifiable {
        case veryLow
        case low
        case neutral
        case high
        case veryHigh

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .veryLow: return "Very low"
            case .low: return "Low"
            case .neutral: return "Neutral"
            case .high: return "High"
            case .veryHigh: return "Very high"
            }
        }
    }

    enum LoadingState {
        case idle
        case animating
        case finished
    }

    enum FaceScanState {
        case idle
        case scanning
        case complete
        case skipped
    }

    struct SummaryItem: Identifiable {
        let id = UUID()
        let title: String
        let value: String
    }

    @Published var currentStep: Step = .welcome
    @Published var selectedSkinTypes: Set<SkinTypeOption> = []
    @Published var selectedGoals: Set<BeautyGoalOption> = []
    @Published var dailyTime: Double = 15
    @Published var sleepHours: Double = 7
    @Published var hasAdjustedSleep = false
    @Published var confidenceLevel: ConfidenceLevel?
    @Published var userName: String = ""

    @Published var loadingState: LoadingState = .idle
    @Published var loadingProgress: Double = 0
    @Published var completedChecklistIndices: Set<Int> = []

    @Published var facePhotoData: Data?
    @Published var faceScanState: FaceScanState = .idle
    @Published var faceScanProgress: Double = 0

    @Published var limitedModeOptIn = false

    private var loadingTask: Task<Void, Never>?
    private var faceScanTask: Task<Void, Never>?

    let loadingChecklistItems = [
        "Mapping skincare balance",
        "Matching survey to goals",
        "Creating daily routine",
        "Preparing roadmap"
    ]

    func toggleSkinType(_ option: SkinTypeOption) {
        if selectedSkinTypes.contains(option) {
            selectedSkinTypes.remove(option)
        } else {
            selectedSkinTypes.insert(option)
        }
    }

    func toggleGoal(_ option: BeautyGoalOption) {
        if selectedGoals.contains(option) {
            selectedGoals.remove(option)
        } else {
            selectedGoals.insert(option)
        }
    }

    func goToNextStep() {
        guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func goToStep(_ step: Step) {
        currentStep = step
    }

    var skinTypeSummary: String {
        guard !selectedSkinTypes.isEmpty else { return "Not set" }
        return selectedSkinTypes
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.displayName)
            .joined(separator: ", ")
    }

    var goalsSummary: String {
        guard !selectedGoals.isEmpty else { return "Not set" }
        return selectedGoals
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.displayName)
            .joined(separator: ", ")
    }

    var sleepSummary: String {
        guard hasAdjustedSleep else { return "Not provided" }
        if sleepHours >= 10 {
            return "10+ hours"
        }
        let rounded = String(format: "%.1f hours", sleepHours)
        return rounded.replacingOccurrences(of: ".0", with: "")
    }

    var timeSummary: String {
        "\(Int(dailyTime.rounded())) min"
    }

    var summaryItems: [SummaryItem] {
        [
            SummaryItem(title: "Skin Type", value: skinTypeSummary),
            SummaryItem(title: "Goals", value: goalsSummary),
            SummaryItem(title: "Daily Time", value: timeSummary),
            SummaryItem(title: "Sleep Hours", value: sleepSummary)
        ]
    }

    func beginPlanGeneration(appModel: AppModel) {
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        userName = trimmedName
        var result = buildQuizResult()
        result.userName = trimmedName.isEmpty ? nil : trimmedName
        appModel.saveQuizResult(result)
        goToStep(.loading)
        startLoadingSequence { [weak self] in
            guard let self else { return }
            self.goToStep(.valueComparison)
        }
    }

    func startLoadingSequence(onComplete: @escaping () -> Void) {
        guard loadingState == .idle else { return }
        loadingState = .animating
        loadingProgress = 0
        completedChecklistIndices.removeAll()

        loadingTask?.cancel()
        loadingTask = Task { [weak self] in
            guard let self else { return }
            let totalItems = loadingChecklistItems.count
            for index in 0..<totalItems {
                try? await Task.sleep(nanoseconds: 600_000_000)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        self.completedChecklistIndices.insert(index)
                        let base = Double(index + 1) / Double(totalItems + 1)
                        self.loadingProgress = max(self.loadingProgress, base)
                    }
                }
            }

            try? await Task.sleep(nanoseconds: 600_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.35)) {
                    self.loadingProgress = 1
                }
            }

            try? await Task.sleep(nanoseconds: 400_000_000)

            await MainActor.run {
                self.loadingState = .finished
                onComplete()
            }
        }
    }

    func resetLoadingState() {
        loadingTask?.cancel()
        loadingTask = nil
        loadingState = .idle
        loadingProgress = 0
        completedChecklistIndices.removeAll()
    }

    func updateFacePhoto(data: Data?) {
        facePhotoData = data
        faceScanState = .idle
        faceScanProgress = 0
    }

    func runFakeFaceScan() {
        faceScanTask?.cancel()
        faceScanProgress = 0
        faceScanState = .scanning

        faceScanTask = Task { [weak self] in
            guard let self else { return }
            let steps = 30
            for index in 0..<steps {
                try? await Task.sleep(nanoseconds: 120_000_000)
                await MainActor.run {
                    self.faceScanProgress = Double(index + 1) / Double(steps)
                }
            }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.35)) {
                    self.faceScanState = .complete
                    self.faceScanProgress = 1
                }
            }
        }
    }

    func skipFaceScan() {
        faceScanTask?.cancel()
        faceScanProgress = 0
        facePhotoData = nil
        faceScanState = .skipped
    }

    func buildQuizResult() -> QuizResult {
        var answers: [String: [String]] = [:]

        if !selectedSkinTypes.isEmpty {
            answers["skin_types"] = selectedSkinTypes
                .sorted { $0.sortOrder < $1.sortOrder }
                .map(\.rawValue)
        }

        if !selectedGoals.isEmpty {
            answers["beauty_goals"] = selectedGoals
                .sorted { $0.sortOrder < $1.sortOrder }
                .map(\.rawValue)
        }

        answers["daily_time_commitment_minutes"] = [String(Int(dailyTime.rounded()))]

        if hasAdjustedSleep {
            answers["sleep_hours"] = [String(format: "%.1f", sleepHours)]
        }

        if let confidenceLevel {
            answers["confidence_level"] = [confidenceLevel.rawValue]
        }

        answers["onboarding_version"] = ["2025_revamp"]

        return QuizResult(answers: answers, selectedPhoto: nil)
    }

    func markLimitedMode() {
        limitedModeOptIn = true
    }

    func resetForRetry() {
        selectedSkinTypes.removeAll()
        selectedGoals.removeAll()
        dailyTime = 15
        sleepHours = 7
        hasAdjustedSleep = false
        confidenceLevel = nil
        userName = ""
        resetLoadingState()
        updateFacePhoto(data: nil)
        limitedModeOptIn = false
        goToStep(.welcome)
    }

    func persistAvatar(appModel: AppModel) {
        appModel.updateAvatarImage(facePhotoData)
    }

    deinit {
        loadingTask?.cancel()
        faceScanTask?.cancel()
    }
}

// MARK: - Step Views

private struct OnboardingWelcomePlacementStep: View {
    @EnvironmentObject private var flowModel: OnboardingExperienceViewModel
    @State private var hasTriggeredPlacement = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(GlowPalette.deepRose)
                Text("Welcome to GlowUp")
                    .font(GlowTypography.heading(32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(GlowPalette.deepRose)
                Text("We’re loading your personalized experience.")
                    .font(GlowTypography.body())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .task {
            guard !hasTriggeredPlacement else { return }
            hasTriggeredPlacement = true
            await presentWelcomePlacement()
            await MainActor.run {
                flowModel.goToNextStep()
            }
        }
    }

    private func presentWelcomePlacement() async {
        _ = await SuperwallService.shared.presentAndAwaitDismissal("first_screen", timeoutSeconds: 6)
    }
}

private struct SkinTypeStepView: View {
    @EnvironmentObject private var flowModel: OnboardingExperienceViewModel

    var body: some View {
        GlowOnboardingScreen(
            title: "What best describes your skin type?",
            subtitle: "We use this to customize your plan’s balance and recommendations.",
            primaryTitle: "Continue",
            primaryEnabled: !flowModel.selectedSkinTypes.isEmpty,
            onPrimary: { flowModel.goToNextStep() }
        ) {
            VStack(spacing: 12) {
                ForEach(OnboardingExperienceViewModel.SkinTypeOption.allCases) { option in
                    OnboardingSelectableRow(
                        title: option.displayName,
                        isSelected: flowModel.selectedSkinTypes.contains(option),
                        action: { flowModel.toggleSkinType(option) }
                    )
                }
            }
        }
    }
}

private struct BeautyGoalsStepView: View {
    @EnvironmentObject private var flowModel: OnboardingExperienceViewModel

    var body: some View {
        GlowOnboardingScreen(
            title: "What are your top goals?",
            subtitle: "Select all that apply.",
            primaryTitle: "Continue",
            primaryEnabled: !flowModel.selectedGoals.isEmpty,
            onPrimary: { flowModel.goToNextStep() }
        ) {
            VStack(spacing: 12) {
                ForEach(OnboardingExperienceViewModel.BeautyGoalOption.allCases) { option in
                    OnboardingSelectableRow(
                        title: option.displayName,
                        isSelected: flowModel.selectedGoals.contains(option),
                        action: { flowModel.toggleGoal(option) }
                    )
                }
            }
        }
    }
}

private struct TimeCommitmentStepView: View {
    @EnvironmentObject private var flowModel: OnboardingExperienceViewModel

    var body: some View {
        GlowOnboardingScreen(
            title: "How much time can you dedicate daily?",
            subtitle: "We’ll match your plan depth to your schedule.",
            primaryTitle: "Continue",
            primaryEnabled: true,
            onPrimary: { flowModel.goToNextStep() }
        ) {
            VStack(spacing: 32) {
                Text("\(Int(flowModel.dailyTime.rounded())) min")
                    .font(GlowTypography.heading(48, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(GlowPalette.deepRose)

                Slider(value: $flowModel.dailyTime, in: 0...60, step: 5)
                    .tint(GlowPalette.blushPink)

                HStack {
                    Text("0 min")
                        .font(GlowTypography.body(14))
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
                    Spacer()
                    Text("60 min")
                        .font(GlowTypography.body(14))
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
                }
            }
        }
    }
}

private struct LifestyleInputsStepView: View {
    @EnvironmentObject private var flowModel: OnboardingExperienceViewModel

    var sleepBinding: Binding<Double> {
        Binding(
            get: { flowModel.sleepHours },
            set: { newValue in
                flowModel.sleepHours = newValue
                flowModel.hasAdjustedSleep = true
            }
        )
    }

    var body: some View {
        GlowOnboardingScreen(
            title: "Help us personalize your plan",
            subtitle: nil,
            primaryTitle: "Continue",
            primaryEnabled: flowModel.hasAdjustedSleep && flowModel.confidenceLevel != nil,
            onPrimary: { flowModel.goToNextStep() },
            layout: .center
        ) {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Average hours of sleep per night")
                        .font(GlowTypography.body(16, weight: .semibold))
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
                        .multilineTextAlignment(.center)

                    CircularSleepSlider(value: sleepBinding, range: 3...10)
                }

                VStack(spacing: 16) {
                    Text("Current confidence level")
                        .font(GlowTypography.body(16, weight: .semibold))
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
                        .multilineTextAlignment(.center)

                    ConfidenceSelector(
                        selection: flowModel.confidenceLevel,
                        options: OnboardingExperienceViewModel.ConfidenceLevel.allCases,
                        onSelect: { flowModel.confidenceLevel = $0 }
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct SummaryConfirmationStepView: View {
    @EnvironmentObject private var flowModel: OnboardingExperienceViewModel

    var body: some View {
        GlowOnboardingScreen(
            title: "Confirm your details",
            subtitle: "You can update this later in Profile. We’ll confirm your name next.",
            primaryTitle: "Generate my plan",
            primaryEnabled: true,
            onPrimary: { flowModel.goToNextStep() }
        ) {
            let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

            ViewThatFits {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(flowModel.summaryItems) { item in
                        SummaryCardView(item: item)
                    }
                }

                VStack(spacing: 16) {
                    ForEach(flowModel.summaryItems) { item in
                        SummaryCardView(item: item)
                    }
                }
            }
        }
    }
}

private struct NameCaptureStepView: View {
    @EnvironmentObject private var flowModel: OnboardingExperienceViewModel
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        GlowOnboardingScreen(
            title: "What should we call you?",
            subtitle: "Your name personalizes your dashboard and plan updates.",
            primaryTitle: "Generate my plan",
            primaryEnabled: !flowModel.userName.trimmingCharacters(in: .whitespaces).isEmpty,
            onPrimary: { flowModel.beginPlanGeneration(appModel: appModel) }
        ) {
            VStack(spacing: 16) {
                TextField("Your name", text: $flowModel.userName)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(GlowPalette.softBeige)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(GlowPalette.roseGold.opacity(0.3), lineWidth: 1)
                    )
                    .font(GlowTypography.body(18, weight: .medium))
                    .foregroundStyle(GlowPalette.deepRose)
            }
        }
    }
}

private struct PlanLoadingStepView: View {
    @EnvironmentObject private var flowModel: OnboardingExperienceViewModel

    var body: some View {
        GlowOnboardingScreen(
            title: "Building your Glow Plan",
            subtitle: nil,
            primaryTitle: "Continue",
            primaryEnabled: flowModel.loadingState == .finished,
            onPrimary: { flowModel.goToNextStep() }
        ) {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(flowModel.loadingChecklistItems.enumerated()), id: \.offset) { index, title in
                        HStack(spacing: 12) {
                            Image(systemName: flowModel.completedChecklistIndices.contains(index) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(flowModel.completedChecklistIndices.contains(index) ? GlowPalette.blushPink : GlowPalette.roseGold.opacity(0.4))
                                .font(.title3)
                                .animation(.easeInOut(duration: 0.35), value: flowModel.completedChecklistIndices)

                            Text(title)
                                .font(GlowTypography.body(16, weight: .medium))
                                .foregroundStyle(GlowPalette.deepRose.opacity(0.85))
                        }
                    }
                }

                ProgressView(value: flowModel.loadingProgress)
                    .tint(GlowPalette.blushPink)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.35), value: flowModel.loadingProgress)
            }
        }
        .onAppear {
            if flowModel.loadingState == .animating {
                return
            }
            if flowModel.loadingState == .idle {
                flowModel.startLoadingSequence {
                    flowModel.loadingState = .finished
                }
            }
        }
    }
}

private struct ValueComparisonStepView: View {
    @EnvironmentObject private var flowModel: OnboardingExperienceViewModel

    var body: some View {
        GlowOnboardingScreen(
            title: "Consistency creates results.",
            subtitle: nil,
            primaryTitle: "View my Glow map",
            primaryEnabled: true,
            secondaryTitle: "Skip for now",
            onPrimary: { presentPaywallAndAdvance() },
            onSecondary: {
                flowModel.markLimitedMode()
                flowModel.goToNextStep()
            }
        ) {
            ViewThatFits {
                HStack(spacing: 16) {
                    ValueComparisonCard(
                        title: "Unstructured Routine",
                        bulletPoints: [
                            "Inconsistent steps",
                            "Overwhelming choices",
                            "No tracking"
                        ],
                        isProminent: false
                    )
                    .frame(maxWidth: .infinity)

                    ValueComparisonCard(
                        title: "GlowUp Guided Plan",
                        bulletPoints: [
                            "Daily checklist",
                            "Measurable progress",
                            "Adaptive insights"
                        ],
                        isProminent: true
                    )
                    .frame(maxWidth: .infinity)
                }

                VStack(spacing: 16) {
                    ValueComparisonCard(
                        title: "Unstructured Routine",
                        bulletPoints: [
                            "Inconsistent steps",
                            "Overwhelming choices",
                            "No tracking"
                        ],
                        isProminent: false
                    )

                    ValueComparisonCard(
                        title: "GlowUp Guided Plan",
                        bulletPoints: [
                            "Daily checklist",
                            "Measurable progress",
                            "Adaptive insights"
                        ],
                        isProminent: true
                    )
                }
            }
        }
    }

    private func presentPaywallAndAdvance() {
        Task {
            _ = await SuperwallService.shared.presentAndAwaitDismissal("subscription_paywall", timeoutSeconds: 8)
            await MainActor.run {
                flowModel.goToNextStep()
            }
        }
    }
}

private struct SocialProofStepView: View {
    private let quotes: [SocialProofQuote] = SocialProofQuote.samples
    @EnvironmentObject private var flowModel: OnboardingExperienceViewModel

    var body: some View {
        GlowOnboardingScreen(
            title: "What users say",
            subtitle: nil,
            primaryTitle: "Continue",
            primaryEnabled: true,
            onPrimary: { flowModel.goToNextStep() }
        ) {
            VStack(spacing: 16) {
                ForEach(quotes) { quote in
                    SocialProofCard(quote: quote)
                }

                Button {
                    SuperwallService.shared.registerEvent("onboarding_review_intent")
                } label: {
                    Text("Share your story")
                        .font(GlowTypography.button)
                        .frame(maxWidth: .infinity)
                }
                .glowSecondaryButtonBackground()
            }
        }
    }
}

private struct FaceScanStepView: View {
    @EnvironmentObject private var flowModel: OnboardingExperienceViewModel
    @EnvironmentObject private var appModel: AppModel
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        GlowOnboardingScreen(
            title: "Face Scan",
            subtitle: "Enjoy one complimentary scan. Results stay blurred until you unlock the full experience.",
            primaryTitle: "Continue",
            primaryEnabled: flowModel.faceScanState == .complete || flowModel.faceScanState == .skipped,
            secondaryTitle: flowModel.faceScanState == .complete ? nil : "Skip scan",
            onPrimary: {
                flowModel.persistAvatar(appModel: appModel)
                flowModel.goToNextStep()
            },
            onSecondary: {
                flowModel.skipFaceScan()
                flowModel.persistAvatar(appModel: appModel)
                flowModel.goToNextStep()
            }
        ) {
            VStack(spacing: 20) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                        Text(flowModel.facePhotoData == nil ? "Upload or take a photo" : "Change photo")
                            .font(GlowTypography.body(16, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(GlowPalette.roseGold.opacity(0.4), lineWidth: 1.5)
                    )
                }
                .onChange(of: selectedPhotoItem) { newValue in
                    guard let item = newValue else {
                        flowModel.updateFacePhoto(data: nil)
                        return
                    }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            await MainActor.run {
                                flowModel.updateFacePhoto(data: data)
                            }
                        }
                    }
                }

                if let data = flowModel.facePhotoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(
                            color: GlowShadow.soft.color,
                            radius: GlowShadow.soft.radius,
                            x: GlowShadow.soft.x,
                            y: GlowShadow.soft.y
                        )
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(GlowPalette.softBeige.opacity(0.6))
                        .frame(height: 180)
                        .overlay {
                            Text("No photo selected")
                                .font(GlowTypography.body(15))
                                .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
                        }
                }

                if flowModel.faceScanState == .scanning {
                    VStack(spacing: 12) {
                        ProgressView(value: flowModel.faceScanProgress)
                            .tint(GlowPalette.blushPink)
                        Text("Scanning your photo…")
                            .font(GlowTypography.body(15, weight: .medium))
                            .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Button(action: flowModel.runFakeFaceScan) {
                        Text(flowModel.faceScanState == .complete ? "Re-run scan" : "Run face scan")
                            .font(GlowTypography.button)
                            .frame(maxWidth: .infinity)
                    }
                    .glowSecondaryButtonBackground()
                }

                if flowModel.faceScanState == .complete {
                    BlurredResultCard()
                }
            }
        }
    }
}

private struct FinalCallToActionStepView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var flowModel: OnboardingExperienceViewModel

    var body: some View {
        GlowOnboardingScreen(
            title: "Your personalized Glow Plan is ready",
            subtitle: "Your daily roadmap includes guided skincare, routines, and progress tracking.",
            primaryTitle: "Continue",
            primaryEnabled: true,
            secondaryTitle: "Try limited version",
            onPrimary: { presentSubscriptionPaywall() },
            onSecondary: {
                flowModel.markLimitedMode()
                appModel.markOnboardingComplete()
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                FeatureHighlightRow(
                    icon: "checkmark.seal.fill",
                    text: "Daily tasks tuned to your time commitment"
                )
                FeatureHighlightRow(
                    icon: "sparkles",
                    text: "Visual progress with every scan"
                )
                FeatureHighlightRow(
                    icon: "person.crop.circle.badge.checkmark",
                    text: "Guided confidence exercises and style cues"
                )
            }
        }
    }

    private func presentSubscriptionPaywall() {
        Task {
            _ = await SuperwallService.shared.presentAndAwaitDismissal("subscription_paywall", timeoutSeconds: 8)
        }
    }
}

// MARK: - Shared Components

private struct GlowOnboardingScreen<Content: View>: View {
    enum Layout {
        case leading
        case center
    }

    let title: String
    let subtitle: String?
    let primaryTitle: String
    let primaryEnabled: Bool
    let secondaryTitle: String?
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?
    let layout: Layout
    let content: Content

    init(
        title: String,
        subtitle: String?,
        primaryTitle: String,
        primaryEnabled: Bool,
        secondaryTitle: String? = nil,
        onPrimary: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil,
        layout: Layout = .leading,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.primaryTitle = primaryTitle
        self.primaryEnabled = primaryEnabled
        self.secondaryTitle = secondaryTitle
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
        self.layout = layout
        self.content = content()
    }

    var body: some View {
        let stackAlignment: HorizontalAlignment = layout == .leading ? .leading : .center
        let textAlignment: TextAlignment = layout == .leading ? .leading : .center
        let frameAlignment: Alignment = layout == .leading ? .topLeading : .top

        VStack(alignment: stackAlignment, spacing: 24) {
            VStack(alignment: stackAlignment, spacing: 12) {
                Text(title)
                    .font(GlowTypography.heading(30, weight: .bold))
                    .foregroundStyle(GlowPalette.deepRose)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: layout == .leading ? .leading : .center)
                if let subtitle {
                    Text(subtitle)
                        .font(GlowTypography.body(16))
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: layout == .leading ? .leading : .center)
                }
            }

            content
                .frame(maxWidth: .infinity, alignment: layout == .leading ? .leading : .center)

            Spacer(minLength: 16)

            if let secondaryTitle, let onSecondary {
                Button(action: onSecondary) {
                    Text(secondaryTitle)
                        .font(GlowTypography.button)
                        .frame(maxWidth: .infinity)
                }
                .glowSecondaryButtonBackground()
            }

            Button(action: onPrimary) {
                Text(primaryTitle)
                    .font(GlowTypography.button)
                    .frame(maxWidth: .infinity)
            }
            .glowRoundedButtonBackground(isEnabled: primaryEnabled)
            .disabled(!primaryEnabled)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
    }
}

private struct OnboardingSelectableRow: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(GlowTypography.body(16, weight: .semibold))
                        .foregroundStyle(GlowPalette.deepRose)
                    if let subtitle {
                        Text(subtitle)
                            .font(GlowTypography.caption)
                            .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(GlowPalette.roseGold.opacity(isSelected ? 0.8 : 0.4), lineWidth: 2)
                        .frame(width: 26, height: 26)
                    if isSelected {
                        Circle()
                            .fill(GlowPalette.blushPink)
                            .frame(width: 18, height: 18)
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? GlowPalette.softBeige : GlowPalette.softBeige.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(GlowPalette.roseGold.opacity(isSelected ? 0.6 : 0), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CircularSleepSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    private let step: Double = 0.25

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            ZStack {
                Circle()
                    .stroke(GlowPalette.softBeige.opacity(0.5), lineWidth: 14)

                let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        GlowPalette.blushPink,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text(formattedTime)
                        .font(GlowTypography.heading(32, weight: .bold))
                        .foregroundStyle(GlowPalette.deepRose)
                        .multilineTextAlignment(.center)
                    Text("sleep")
                        .font(GlowTypography.caption)
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
                }

                Circle()
                    .fill(GlowPalette.blushPink)
                    .frame(width: 26, height: 26)
                    .offset(x: 0, y: -radius)
                    .rotationEffect(.degrees(Double(progress) * 360))
            }
            .frame(width: size, height: size)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        handleDrag(location: gesture.location, in: proxy.size)
                    }
            )
        }
        .frame(height: 220)
    }

    private func handleDrag(location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let vector = CGVector(dx: location.x - center.x, dy: location.y - center.y)
        let angle = atan2(vector.dy, vector.dx) + .pi / 2
        var normalizedAngle = angle < 0 ? angle + (.pi * 2) : angle
        if normalizedAngle.isNaN { normalizedAngle = 0 }
        let progress = max(0, min(1, normalizedAngle / (2 * .pi)))
        let newValue = range.lowerBound + Double(progress) * (range.upperBound - range.lowerBound)
        let rounded = (newValue / step).rounded() * step
        value = max(range.lowerBound, min(range.upperBound, rounded))
    }

    private var formattedTime: String {
        let clampedValue = max(range.lowerBound, min(range.upperBound, value))
        let totalMinutes = Int(round(clampedValue * 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }
}

private struct ConfidenceSelector: View {
    var selection: OnboardingExperienceViewModel.ConfidenceLevel?
    let options: [OnboardingExperienceViewModel.ConfidenceLevel]
    let onSelect: (OnboardingExperienceViewModel.ConfidenceLevel) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options) { level in
                Button {
                    onSelect(level)
                } label: {
                    Text(level.displayName)
                        .font(GlowTypography.body(14, weight: .medium))
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(level == selection ? GlowPalette.blushPink : GlowPalette.softBeige.opacity(0.7))
                        )
                        .foregroundStyle(level == selection ? GlowPalette.deepRose : GlowPalette.deepRose.opacity(0.65))
                }
            }
        }
    }
}

private struct SummaryCardView: View {
    let item: OnboardingExperienceViewModel.SummaryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(GlowTypography.body(14, weight: .semibold))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
            Text(item.value)
                .font(GlowTypography.body(17, weight: .semibold))
                .foregroundStyle(GlowPalette.deepRose)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GlowPalette.softBeige)
        )
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
    }
}

private struct ValueComparisonCard: View {
    let title: String
    let bulletPoints: [String]
    let isProminent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(GlowTypography.body(18, weight: .semibold))
                .foregroundStyle(GlowPalette.deepRose)

            ForEach(bulletPoints, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(GlowPalette.roseGold.opacity(0.8))
                        .padding(.top, 6)
                    Text(bullet)
                        .font(GlowTypography.body(15))
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.75))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isProminent ? GlowPalette.blushPink.opacity(0.4) : GlowPalette.softBeige.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(GlowPalette.roseGold.opacity(isProminent ? 0.55 : 0.25), lineWidth: 1.4)
        )
    }
}

private struct SocialProofQuote: Identifiable {
    let id = UUID()
    let quote: String
    let name: String
    let age: Int

    static let samples: [SocialProofQuote] = [
        SocialProofQuote(
            quote: "I didn’t think it would work but after 2 weeks of being consistent I saw changes I never thought I would ever see.",
            name: "Sarah",
            age: 22
        ),
        SocialProofQuote(
            quote: "The Face Scan at the start told me instantly what to improve on, I didn't have to guess.",
            name: "Mia",
            age: 25
        ),
        SocialProofQuote(
            quote: "I never knew how to dress before, now it tells me which colors work best on me, and I can see what it looks like on me before I spend any money.",
            name: "Alina",
            age: 20
        )
    ]
}

private struct SocialProofCard: View {
    let quote: SocialProofQuote

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("\(quote.name), \(quote.age)")
                    .font(GlowTypography.body(16, weight: .semibold))
                    .foregroundStyle(GlowPalette.deepRose)
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.footnote)
                            .foregroundStyle(GlowPalette.roseGold)
                    }
                }
            }

            Text(quote.quote)
                .font(GlowTypography.body())
                .foregroundStyle(GlowPalette.deepRose.opacity(0.75))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(GlowPalette.softBeige)
        )
        .shadow(
            color: GlowShadow.soft.color,
            radius: GlowShadow.soft.radius,
            x: GlowShadow.soft.x,
            y: GlowShadow.soft.y
        )
    }
}

private struct BlurredResultCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your scan insights")
                .font(GlowTypography.body(16, weight: .semibold))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
            VStack(alignment: .leading, spacing: 8) {
                Text("• Skin texture balance improving")
                Text("• Lighting adjustments recommended")
                Text("• Palette match: Soft Autumn")
                Text("• Next steps queued in your roadmap")
            }
            .font(GlowTypography.body(15))
            .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
            .blur(radius: 6)

            Text("Unlock GlowUp+ to reveal every detail instantly.")
                .font(GlowTypography.caption)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.65))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(GlowPalette.softBeige)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(GlowPalette.roseGold.opacity(0.35), lineWidth: 1.2)
        )
    }
}

private struct FeatureHighlightRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(GlowPalette.roseGold)
                .font(.title3)
            Text(text)
                .font(GlowTypography.body(16, weight: .medium))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
        }
    }
}
