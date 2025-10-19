//
//  OnboardingViews.swift
//  glowup
//
//  Reimagined three-screen onboarding that leans into motivational psychology
//  and high-conversion messaging.
//

import SwiftUI
import PhotosUI
import UIKit

struct OnboardingFlowView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    private enum Step: Equatable {
        case welcome
        case quiz(Int)
        case photo
        case preview
    }

    @State private var step: Step = .welcome
    @State private var selectedAnswers: [String: GlowQuickOption] = [:]
    @State private var quizResult: QuizResult?
    @State private var previewData: GlowPreviewData?
    @State private var limitedAnalysis: GlowLimitedAnalysis?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var isPurchasing = false
    @State private var isAnalyzingPhoto = false
    @State private var purchaseError: String?
    @State private var showPhotoImportError = false
    @State private var showReconsideration = false
    @State private var hasPreparedPreview = false
    @AppStorage("GlowFreeScanUsed") private var freeScanUsed = false

    private let quickQuestions = GlowQuickQuestion.bank

    var body: some View {
        ZStack {
            GradientBackground.primary
                .ignoresSafeArea()

            content
                .animation(.easeInOut, value: step)
        }
        .task {
            await subscriptionManager.refreshProductsIfNeeded()
        }
        .onChange(of: subscriptionManager.isSubscribed) { isSubscribed in
            if isSubscribed {
                appModel.markOnboardingComplete()
            }
        }
        .sheet(isPresented: $showReconsideration) {
            SubscriptionReconsiderationView(
                onReturnToPlans: {
                    showReconsideration = false
                },
                onExitToStart: {
                    showReconsideration = false
                    restart()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("Photo Import Failed", isPresented: $showPhotoImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("We couldn’t load that photo. Please try a different image or skip this step – you can add one later.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            GlowWelcomeScreen(
                onStart: { step = .quiz(0) },
                onSkip: {
                    goToPreview(runAnalysis: false)
                }
            )
        case .quiz(let index):
            GlowQuestionScreen(
                questionIndex: index,
                totalQuestions: quickQuestions.count,
                question: quickQuestions[index],
                selectedOption: selectedAnswers[quickQuestions[index].id],
                onSelect: { option in
                    selectedAnswers[quickQuestions[index].id] = option
                },
                onContinue: {
                    advanceFromQuestion(at: index)
                }
            )
        case .photo:
            GlowPhotoScreen(
                photoItem: $selectedPhotoItem,
                photoData: selectedPhotoData,
                isAnalyzing: isAnalyzingPhoto,
                freeScanUsed: freeScanUsed,
                onSkip: {
                    goToPreview(runAnalysis: false)
                },
                onContinue: {
                    goToPreview(runAnalysis: true)
                }
            )
            .onChange(of: selectedPhotoItem) { newValue in
                guard let item = newValue else { return }
                Task {
                    await importPhoto(item: item)
                }
            }
        case .preview:
            GlowPreviewPaywallScreen(
                preview: previewData ?? GlowPreviewData.placeholder(),
                limitedAnalysis: limitedAnalysis,
                selectedPlan: subscriptionManager.recommendedPlanSelection(),
                isProcessing: isPurchasing,
                statusMessage: subscriptionManager.statusMessage,
                purchaseError: purchaseError,
                onStartTrial: { product in
                    startTrial(for: product)
                },
                onMaybeLater: {
                    showReconsideration = true
                },
                onBack: {
                    step = .quiz(max(quickQuestions.count - 1, 0))
                }
            )
        }
    }

    private func advanceFromQuestion(at index: Int) {
        guard selectedAnswers[quickQuestions[index].id] != nil else { return }
        if index + 1 < quickQuestions.count {
            step = .quiz(index + 1)
        } else {
            hasPreparedPreview = false
            step = .photo
        }
    }

    private func goToPreview(runAnalysis: Bool) {
        Task {
            await preparePreviewIfNeeded(runAnalysis: runAnalysis)
            await MainActor.run {
                step = .preview
            }
        }
    }

    private func preparePreviewIfNeeded(runAnalysis: Bool) async {
        if hasPreparedPreview { return }
        let result = buildQuizResult()
        await MainActor.run {
            quizResult = result
            if !runAnalysis && !freeScanUsed {
                limitedAnalysis = nil
            }
        }

        if runAnalysis,
           let photoData = selectedPhotoData,
           !freeScanUsed {
            await MainActor.run {
                isAnalyzingPhoto = true
            }
            if let analysis = await performLimitedAnalysis(photoData: photoData, quiz: result) {
                await MainActor.run {
                    limitedAnalysis = analysis
                    freeScanUsed = true
                }
            }
            await MainActor.run {
                isAnalyzingPhoto = false
            }
        }

        await MainActor.run {
            previewData = GlowPreviewData.make(
                answers: selectedAnswers,
                hasPhoto: selectedPhotoData != nil
            )
            hasPreparedPreview = true
        }
    }

    private func buildQuizResult() -> QuizResult {
        var answers: [String: [String]] = [:]

        for question in quickQuestions {
            if let selection = selectedAnswers[question.id] {
                answers[question.id] = [selection.id]
            } else if let fallback = question.fallbackOption {
                answers[question.id] = [fallback.id]
                selectedAnswers[question.id] = fallback
            }
        }

        if answers["glow_motivation"] == nil {
            answers["glow_motivation"] = ["confidence"]
        }

        return QuizResult(
            answers: answers,
            selectedPhoto: selectedPhotoData
        )
    }

    private func restart() {
        selectedAnswers.removeAll()
        selectedPhotoItem = nil
        selectedPhotoData = nil
        quizResult = nil
        previewData = nil
        limitedAnalysis = nil
        purchaseError = nil
        isPurchasing = false
        isAnalyzingPhoto = false
        showPhotoImportError = false
        hasPreparedPreview = false
        step = .welcome
    }

    private func startTrial(for product: GlowUpProduct) {
        guard !isPurchasing else { return }
        purchaseError = nil
        isPurchasing = true
        Task {
            do {
                try await subscriptionManager.purchaseSubscription(for: product)
                await subscriptionManager.refreshEntitlementState()
            } catch {
                await MainActor.run {
                    purchaseError = error.localizedDescription
                }
            }
            await MainActor.run {
                isPurchasing = false
            }
        }
    }

    private func importPhoto(item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    selectedPhotoData = data
                    selectedPhotoItem = nil
                    hasPreparedPreview = false
                    limitedAnalysis = nil
                }
            }
        } catch {
            await MainActor.run {
                showPhotoImportError = true
            }
        }
    }

    private func performLimitedAnalysis(photoData: Data, quiz: QuizResult) async -> GlowLimitedAnalysis? {
        let bundle = PhotoAnalysisBundle(face: photoData, skin: photoData, eyes: photoData)
        let input = PhotoAnalysisInput(
            persona: .bestie,
            bundle: bundle,
            quizResult: quiz
        )
        let analysis = await OpenAIService.shared.analyzePhoto(input)
        if analysis.isFallback { return nil }
        return GlowLimitedAnalysis(from: analysis)
    }
}

// MARK: - Screen 1: Warm Welcome

private struct GlowWelcomeScreen: View {
    var onStart: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                Text("Glow From the Inside Out ✨")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.78, blue: 0.89),
                                Color(red: 0.74, green: 0.57, blue: 0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Ready to look and feel like your best self?")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.92))

                Text("Unlock daily confidence boosts and learn what makes you shine. No filters, no fads — just science, style, and real-time coaching.")
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.horizontal, 32)
            }

            GlowIllustration()
                .frame(width: 260, height: 260)
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                Button(action: onStart) {
                    Text("Let’s Begin")
                        .font(.headline.weight(.bold))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: Color.white.opacity(0.3), radius: 24, y: 16)
                        )
                        .foregroundStyle(Color(red: 0.25, green: 0.15, blue: 0.45))
                }

                Button(action: onSkip) {
                    Text("Skip")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Screen 2: Quick Personalization Quiz

private struct GlowQuestionScreen: View {
    let questionIndex: Int
    let totalQuestions: Int
    let question: GlowQuickQuestion
    let selectedOption: GlowQuickOption?
    var onSelect: (GlowQuickOption) -> Void
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                Text("Step 2 of 3")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            VStack(spacing: 12) {
                Text("Let’s Personalize Your Glow")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Question \(questionIndex + 1) of \(totalQuestions)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
            }

            VStack(spacing: 18) {
                Text(question.prompt)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 24)

                VStack(spacing: 14) {
                    ForEach(question.options) { option in
                        Button {
                            onSelect(option)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(option.title)
                                        .font(.body.weight(.semibold))
                                    if let cue = option.emotionCue {
                                        Text(cue)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.65))
                                    }
                                }
                                Spacer()
                                if selectedOption?.id == option.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.white)
                                        .font(.title3)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.white.opacity(0.4))
                                        .font(.title3)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Color.white.opacity(selectedOption?.id == option.id ? 0.28 : 0.16))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(
                                        Color.white.opacity(selectedOption?.id == option.id ? 0.75 : 0.3),
                                        lineWidth: 1.4
                                    )
                            )
                        }
                        .foregroundStyle(.white)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }

            Spacer()

            Button(action: onContinue) {
                Text(questionIndex + 1 == totalQuestions ? "Continue" : "Next")
                    .font(.headline.weight(.bold))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(selectedOption == nil ? 0.2 : 0.9))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.4), lineWidth: 1.2)
                    )
                    .foregroundStyle(selectedOption == nil ? .white.opacity(0.6) : Color(red: 0.27, green: 0.16, blue: 0.46))
            }
            .disabled(selectedOption == nil)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Optional Photo Capture

private struct GlowPhotoScreen: View {
    @Binding var photoItem: PhotosPickerItem?
    let photoData: Data?
    let isAnalyzing: Bool
    let freeScanUsed: Bool
    var onSkip: () -> Void
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 20)

            VStack(spacing: 12) {
                Text("Want an instant AI spark?")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("Upload a clear selfie so we can line up your lighting and angles. Totally optional—you can add one later.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.horizontal, 28)
                if freeScanUsed {
                    Text("You’ve already used your complimentary scan. Uploading a new photo now gives you a sneak peek once you join GlowUp.")
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.horizontal, 32)
                }
            }

            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 24, y: 16)
            } else {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 220, height: 220)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles.rectangle.stack")
                                .font(.system(size: 40))
                            Text("No photo yet")
                                .font(.callout.weight(.medium))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                    )
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                Text(photoData == nil ? "Upload a Photo" : "Replace Photo")
                    .font(.headline.weight(.bold))
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: Color.white.opacity(0.3), radius: 18, y: 12)
                    )
                    .foregroundStyle(Color(red: 0.27, green: 0.16, blue: 0.46))
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline.weight(.bold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.9))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .foregroundStyle(Color(red: 0.27, green: 0.16, blue: 0.46))
                }
                .disabled(isAnalyzing)

                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.bottom, 36)
            if isAnalyzing {
                ProgressView("Analyzing your glow…")
                    .font(.footnote.weight(.semibold))
                    .tint(.white)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding()
    }
}

// MARK: - Screen 3: Personalized Preview + Paywall

private struct GlowPreviewPaywallScreen: View {
    let preview: GlowPreviewData
    let limitedAnalysis: GlowLimitedAnalysis?
    @State private var selectedPlan: GlowPlanOption = .annual
    let isProcessing: Bool
    let statusMessage: String?
    let purchaseError: String?
    var onStartTrial: (GlowUpProduct) -> Void
    var onMaybeLater: () -> Void
    var onBack: () -> Void

    init(
        preview: GlowPreviewData,
        limitedAnalysis: GlowLimitedAnalysis?,
        selectedPlan: GlowPlanOption,
        isProcessing: Bool,
        statusMessage: String?,
        purchaseError: String?,
        onStartTrial: @escaping (GlowUpProduct) -> Void,
        onMaybeLater: @escaping () -> Void,
        onBack: @escaping () -> Void
    ) {
        self.preview = preview
        self.limitedAnalysis = limitedAnalysis
        self._selectedPlan = State(initialValue: selectedPlan)
        self.isProcessing = isProcessing
        self.statusMessage = statusMessage
        self.purchaseError = purchaseError
        self.onStartTrial = onStartTrial
        self.onMaybeLater = onMaybeLater
        self.onBack = onBack
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                previewHighlights
                valueStack
                lockedTeaser
                founderNote
                planPicker
                trialButton
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 16)
                }
                if let purchaseError {
                    Text(purchaseError)
                        .font(.caption.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.red.opacity(0.9))
                        .padding(.horizontal, 16)
                }
                matchaComparison
                maybeLaterLink
            }
            .padding(.horizontal, 20)
            .padding(.top, 36)
            .padding(.bottom, 60)
        }
        .overlay(alignment: .topLeading) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("Your Glow Plan is Ready 🌟")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            Text("Here’s the first look at what we’re unlocking together.")
                .font(.body.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 24)
            if limitedAnalysis != nil {
                Text("Complimentary scan complete — unlock the full glow dossier to see every metric.")
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 28)
            }
        }
    }

    private var previewHighlights: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Your personalized preview")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 4)

            if let limitedAnalysis {
                LimitedPreviewStack(limited: limitedAnalysis, fallback: preview)
            } else {
                VStack(spacing: 14) {
                    PreviewChip(
                        icon: "face.smiling",
                        title: preview.faceShape,
                        subtitle: "Your angles love gentle front lighting + soft jawline definition."
                    )
                    PreviewChip(
                        icon: "paintpalette.fill",
                        title: preview.colorFamily,
                        subtitle: preview.paletteNote
                    )
                    PreviewChip(
                        icon: "sparkles.tv",
                        title: "Celebrity vibe: \(preview.celebrity)",
                        subtitle: preview.celebrityNote
                    )
                }
            }
        }
    }

    private var lockedTeaser: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.white.opacity(0.85))
                Text("What unlocks with GlowUp+")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }

            let highlights = limitedAnalysis?.lockedHighlights ?? GlowLimitedAnalysis.defaultLockedHighlights
            ForEach(highlights, id: \.self) { highlight in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkle")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, 3)
                    Text(highlight)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
    }

    private var valueStack: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Here’s what you unlock")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
            }
            if let highlight = limitedAnalysis?.strengthHighlight {
                ValuePoint(
                    icon: "star.circle.fill",
                    title: "What we spotted instantly",
                    description: highlight
                )
            }
            ValuePoint(
                icon: "sun.and.horizon.fill",
                title: "Daily Glow Tips & Strategy",
                description: "Tiny actions and long-term guidance tuned to your energy, confidence, and lighting patterns."
            )
            ValuePoint(
                icon: "sparkles.rectangle.stack",
                title: "Real-Time AI Coaching",
                description: "Chat with your AI bestie to perfect lighting, angles, outfits, and expressions on demand."
            )
            ValuePoint(
                icon: "tray.full.fill",
                title: "Style Inspiration Library",
                description: "Celebrity vibe matches, Pinterest prompts, and wardrobe formulas matched to your palette."
            )
        }
    }

    private var founderNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Founder’s Note")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Text("“I built GlowUp because I struggled to feel confident in photos. This AI costs real money to run, so I priced it lower than a single matcha a month. Your subscription keeps the coaching reliable and lets us glow together.”")
                .italic()
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
    }

    private var planPicker: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Choose your plan")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            ForEach(GlowPlanOption.allCases) { plan in
                Button {
                    selectedPlan = plan
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(plan.title)
                                .font(.body.weight(.semibold))
                            Spacer()
                            Text(plan.priceDescription)
                                .font(.callout.weight(.bold))
                        }
                        Text(plan.subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(selectedPlan == plan ? 0.32 : 0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(selectedPlan == plan ? 0.8 : 0.35), lineWidth: selectedPlan == plan ? 1.6 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trialButton: some View {
        Button {
            onStartTrial(selectedPlan.product)
        } label: {
            HStack {
                if isProcessing {
                    ProgressView()
                        .tint(Color(red: 0.27, green: 0.16, blue: 0.46))
                        .progressViewStyle(.circular)
                        .padding(.trailing, 6)
                }
                Text("Start My Free Trial")
                    .font(.headline.weight(.bold))
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.white.opacity(0.28), radius: 28, y: 18)
            )
            .foregroundStyle(Color(red: 0.27, green: 0.16, blue: 0.46))
        }
        .disabled(isProcessing)
    }

    private var matchaComparison: some View {
        HStack(spacing: 12) {
            Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.85))
            VStack(alignment: .leading, spacing: 4) {
                Text("GlowUp: less than one iced matcha per month.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Cancel anytime. After the 7-day trial, your plan renews automatically unless cancelled.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(18)
    }

    private var maybeLaterLink: some View {
        Button(action: onMaybeLater) {
            Text("No thanks, maybe later")
                .font(.footnote.weight(.medium))
                .underline()
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.bottom, 36)
    }
}

// MARK: - Helper Components

private struct PreviewChip: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.12))
        .cornerRadius(20)
    }
}

private struct LimitedPreviewStack: View {
    let limited: GlowLimitedAnalysis
    let fallback: GlowPreviewData

    var body: some View {
        VStack(spacing: 14) {
            PreviewChip(
                icon: "face.smiling",
                title: limited.faceShapeDisplay ?? fallback.faceShape,
                subtitle: limited.faceShapeSubtitle
            )
            PreviewChip(
                icon: "lightbulb.max",
                title: String(format: "Lighting Score: %.1f/10", limited.lightingScore),
                subtitle: limited.lightingSummary
            )
            LockedPreviewChip(
                title: "Glow palette & celebrity vibe (locked)",
                subtitle: limited.colorTeaserSubtitle
            )
        }
    }
}

private struct LockedPreviewChip: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white.opacity(0.85))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(20)
    }
}

private struct ValuePoint: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.85))
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
    }
}

private struct GlowIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04)
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 120
                    )
                )
                .blur(radius: 12)

            Circle()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1.5)
                .frame(width: 220, height: 220)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(18))

            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 42))
                    .foregroundStyle(.white.opacity(0.9))
                Text("GlowUp AI")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Personalized glow coaching\ntailored to your vibe.")
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }
}

// MARK: - Data Models & Builders

private struct GlowQuickQuestion {
    let id: String
    let prompt: String
    let options: [GlowQuickOption]
    let fallbackOption: GlowQuickOption?

    static let bank: [GlowQuickQuestion] = [
        GlowQuickQuestion(
            id: "do_you_know_your_undertone",
            prompt: "Do you know your skin’s undertone?",
            options: [
                GlowQuickOption(id: "yes", title: "Yes – and I use it", emotionCue: "Ready to dial it in further."),
                GlowQuickOption(id: "no", title: "No idea yet", emotionCue: "I need someone to decode it for me."),
                GlowQuickOption(id: "not_sure", title: "Not sure / Sometimes", emotionCue: "I want clarity without the confusion.")
            ],
            fallbackOption: GlowQuickOption(id: "not_sure", title: "Not sure / Sometimes", emotionCue: nil)
        ),
        GlowQuickQuestion(
            id: "glow_motivation",
            prompt: "What’s your main goal?",
            options: [
                GlowQuickOption(id: "photos", title: "Glow on camera", emotionCue: "I want every photo to feel post-worthy."),
                GlowQuickOption(id: "confidence", title: "Boost real-life confidence", emotionCue: "I want to carry glow into daily life."),
                GlowQuickOption(id: "clarity", title: "Learn what suits me", emotionCue: "I’m tired of guessing wrong."),
                GlowQuickOption(id: "reinvention", title: "Total transformation", emotionCue: "I’m ready for a new chapter.")
            ],
            fallbackOption: GlowQuickOption(id: "confidence", title: "Boost real-life confidence", emotionCue: nil)
        ),
        GlowQuickQuestion(
            id: "compliment_frequency",
            prompt: "How often do you get compliments on your photos?",
            options: [
                GlowQuickOption(id: "often", title: "Often", emotionCue: "You know your spark—let’s amplify it."),
                GlowQuickOption(id: "sometimes", title: "Sometimes", emotionCue: "You’ve tasted it and want consistency."),
                GlowQuickOption(id: "rarely", title: "Rarely", emotionCue: "You’re done playing small and ready to shine.")
            ],
            fallbackOption: GlowQuickOption(id: "sometimes", title: "Sometimes", emotionCue: nil)
        )
    ]
}

private struct GlowQuickOption: Identifiable, Hashable {
    let id: String
    let title: String
    let emotionCue: String?
}

private struct GlowPreviewData {
    let faceShape: String
    let colorFamily: String
    let celebrity: String
    let paletteNote: String
    let celebrityNote: String
    let hasPhoto: Bool

    static func make(answers: [String: GlowQuickOption], hasPhoto: Bool) -> GlowPreviewData {
        let complimentID = answers["compliment_frequency"]?.id ?? "sometimes"
        let undertoneID = answers["do_you_know_your_undertone"]?.id ?? "not_sure"
        let goalID = answers["glow_motivation"]?.id ?? "confidence"

        let faceShape: String = {
            switch complimentID {
            case "often": return "Heart-Shaped Glow"
            case "rarely": return "Soft Diamond Potential"
            default: return "Balanced Oval Blueprint"
            }
        }()

        let colorFamily: String = {
            switch undertoneID {
            case "yes": return "Warm Tones"
            case "no": return "Custom Palette Incoming"
            default: return "Neutral Radiance"
            }
        }()

        let paletteNote: String = {
            switch undertoneID {
            case "yes": return "We’ll refine how you wear your known undertone so it photographs flawlessly."
            case "no": return "We’ll test undertones together and lock the ones that make your skin look lit from within."
            default: return "We’ll map warm vs cool moments so you always know what loves you back."
            }
        }()

        let celebrity: String = {
            switch goalID {
            case "photos": return "Zendaya"
            case "clarity": return "Dakota Johnson"
            case "reinvention": return "Janelle Monáe"
            default: return "Blake Lively"
            }
        }()

        let celebrityNote: String = {
            switch goalID {
            case "photos":
                return "Think high-contrast glam shots and magnetic red-carpet energy."
            case "clarity":
                return "Soft, intentional styling with clear guardrails for every outfit."
            case "reinvention":
                return "Bold, expressive silhouettes with playful color experiments."
            default:
                return "Effortlessly bright, modern confidence with polished glow cues."
            }
        }()

        return GlowPreviewData(
            faceShape: faceShape,
            colorFamily: colorFamily,
            celebrity: celebrity,
            paletteNote: paletteNote,
            celebrityNote: celebrityNote,
            hasPhoto: hasPhoto
        )
    }

    static func placeholder() -> GlowPreviewData {
        GlowPreviewData(
            faceShape: "Heart-Shaped Glow",
            colorFamily: "Warm Tones",
            celebrity: "Zendaya",
            paletteNote: "We’ll refine how you wear your known undertone so it photographs flawlessly.",
            celebrityNote: "Think high-contrast glam shots and magnetic red-carpet energy.",
            hasPhoto: false
        )
    }
}

private struct GlowLimitedAnalysis {
    let faceShape: String?
    let lightingScore: Double
    let lightingSummary: String
    let angleScore: Double
    let strengthHighlight: String?
    let colorTeaser: String?
    let lockedHighlights: [String]

    var faceShapeDisplay: String? {
        guard let faceShape else { return nil }
        return faceShape.capitalized
    }

    var faceShapeSubtitle: String {
        let angleString = String(format: "%.1f/10", angleScore)
        return "Your upload hints at a \(angleString) angle score—unlock the full posing and symmetry map."
    }

    var colorTeaserSubtitle: String {
        if let colorTeaser {
            return "\(colorTeaser) popped first. Unlock the full palette, avoid list, and outfit formulas."
        }
        return "Unlock your seasonal palette, avoid list, and celebrity vibe breakdown."
    }

    static let defaultLockedHighlights: [String] = [
        "Full seasonal palette with Glow Colors, avoid list, and wardrobe pairings.",
        "Complete Glow Plan roadmap with quick wins, long-term strategy, and foundational habits.",
        "Celebrity vibe matches, Pinterest search prompts, and visualization presets tuned to you.",
        "Unlimited AI coaching chat plus in-depth photo, skin, and makeup breakdowns."
    ]

    init(from analysis: DetailedPhotoAnalysis) {
        let vars = analysis.variables
        faceShape = vars.faceShape
        lightingScore = vars.lightingQuality
        lightingSummary = vars.lightingFeedback.firstSnippet(maxLength: 160)
        angleScore = vars.angleFlatter
        let highlightSource = vars.strengthAreas.first ?? analysis.personalizedTips.first
        strengthHighlight = highlightSource?.firstSnippet(maxLength: 140)
        colorTeaser = vars.bestColors.first
        lockedHighlights = GlowLimitedAnalysis.defaultLockedHighlights
    }
}

private enum GlowPlanOption: CaseIterable, Identifiable {
    case annual
    case monthly

    var id: String {
        switch self {
        case .annual: return "annual"
        case .monthly: return "monthly"
        }
    }

    var title: String {
        switch self {
        case .annual: return "GlowUp Annual • 7 days free"
        case .monthly: return "GlowUp Monthly • 7 days free"
        }
    }

    var priceDescription: String {
        switch self {
        case .annual: return "$49.99 / year"
        case .monthly: return "$4.99 / month"
        }
    }

    var subtitle: String {
        switch self {
        case .annual: return "Best value – stay glowing all year for less than one iced matcha a month."
        case .monthly: return "Stay flexible while you build momentum with weekly glow wins."
        }
    }

    var product: GlowUpProduct {
        switch self {
        case .annual: return .proAnnual
        case .monthly: return .proMonthly
        }
    }
}

private extension SubscriptionManager {
    func recommendedPlanSelection() -> GlowPlanOption {
        isSubscribed ? .annual : .annual
    }
}

private extension String {
    func firstSnippet(maxLength: Int = 140) -> String {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "We started mapping your lighting—unlock the full breakdown." }

        let delimiters: CharacterSet = CharacterSet(charactersIn: ".!?")
        if let range = trimmed.rangeOfCharacter(from: delimiters) {
            let sentence = trimmed[..<range.upperBound]
            if sentence.count <= maxLength {
                return String(sentence)
            }
        }

        if trimmed.count <= maxLength {
            return trimmed
        }

        let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        let snippet = trimmed[..<index]
        if let lastSpace = snippet.lastIndex(of: " ") {
            return String(snippet[..<lastSpace]) + "…"
        }
        return String(snippet) + "…"
    }
}
