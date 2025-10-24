//
//  OnboardingViews.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var quizViewModel = QuizViewModel()

    private enum Step: Equatable {
        case intro
        case warmup
        case question(Int)
        case identity
        case loading
        case analysis
        case consequence(Int)
        case celebration
        case subscription
        case reconsideration
    }

    @State private var step: Step = .intro
    @State private var selectedLanguage = SupportedLanguage.default
    @State private var quizResult: QuizResult?
    @State private var nameInput = ""
    @State private var ageInput = ""
    @State private var loadingProgress: Double = 0
    @State private var loadingTimer: Timer?
    @State private var analysisPreview: PaywallPreview?

    private let consequenceSlides = OnboardingSlide.defaultSlides
    private let reviewQuotes = ReviewQuote.influencerVoices

    var body: some View {
        ZStack {
            backgroundForStep(step)
                .ignoresSafeArea()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .intro:
            IntroStepView {
                withAnimation(.easeInOut) {
                    step = .warmup
                }
            }
        case .warmup:
            WarmupStepView {
                withAnimation(.easeInOut) {
                    step = .question(0)
                }
            }
        case .question(let index):
            QuestionStepView(
                question: quizViewModel.question(at: index),
                stepIndex: index,
                totalSteps: quizViewModel.totalQuestions,
                selectedLanguage: selectedLanguage,
                onLanguageChange: { selectedLanguage = $0 },
                onAnswer: { option in
                    handleAnswerSelection(option, questionIndex: index)
                },
                onSkip: skipQuiz
            )
        case .identity:
            IdentityCaptureView(
                name: $nameInput,
                age: $ageInput,
                onComplete: completeIdentity
            )
        case .loading:
            LoadingPlanView(progress: loadingProgress)
                .onAppear(perform: beginLoadingSequence)
        case .analysis:
            AnalysisSummaryView(
                preview: analysisPreview,
                userName: quizResult?.userName
            ) {
                withAnimation(.easeInOut) {
                    step = .consequence(0)
                }
            }
        case .consequence(let index):
            ConsequenceSlideView(
                slide: consequenceSlides[index],
                userName: quizResult?.userName
            ) {
                if index + 1 < consequenceSlides.count {
                    withAnimation(.easeInOut) {
                        step = .consequence(index + 1)
                    }
                } else {
                    withAnimation(.easeInOut) {
                        step = .celebration
                    }
                }
            } onSkip: {
                withAnimation(.easeInOut) {
                    step = .celebration
                }
            }
        case .celebration:
            FinalWelcomeView(
                quotes: reviewQuotes,
                onCallToAction: {
                    withAnimation(.easeInOut) {
                        step = .subscription
                    }
                }
            )
        case .subscription:
            SuperwallPaywallHostView(
                preview: analysisPreview ?? PaywallPreviewBuilder.makePreview(from: quizResult)
            )
            .task {
                // Register onboarding_end for analytics/rules, presentation handled by host view.
                SuperwallService.shared.registerEvent("onboarding_end")
            }
        case .reconsideration:
            SubscriptionReconsiderationView(
                onReturnToPlans: {
                    withAnimation(.easeInOut) {
                        step = .subscription
                    }
                },
                onExitToStart: {
                    restartFlow()
                    withAnimation(.easeInOut) {
                        step = .intro
                    }
                }
            )
        }
    }

    private func backgroundForStep(_ step: Step) -> LinearGradient {
        GradientBackground.primary
    }

    private func handleAnswerSelection(_ option: QuizOption, questionIndex: Int) {
        let question = quizViewModel.question(at: questionIndex)
        quizViewModel.toggle(option: option, for: question)
        let isLast = questionIndex + 1 >= quizViewModel.totalQuestions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if isLast {
                quizResult = quizViewModel.buildResult()
                withAnimation(.easeInOut) {
                    step = .identity
                }
            } else {
                withAnimation(.easeInOut) {
                    step = .question(questionIndex + 1)
                }
            }
        }
    }

    private func skipQuiz() {
        quizViewModel.resetSelections()
        quizResult = quizViewModel.buildResult()
        withAnimation(.easeInOut) {
            step = .identity
        }
    }

    private func completeIdentity() {
        guard !nameInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        var result = quizResult ?? quizViewModel.buildResult()
        result.userName = nameInput.trimmingCharacters(in: .whitespaces)
        
        // Age is optional - only set if provided and valid
        if let ageValue = Int(ageInput), ageValue > 0 {
            result.age = ageValue
        } else {
            result.age = nil
        }
        
        quizResult = result
        appModel.saveQuizResult(result)

        withAnimation(.easeInOut) {
            step = .loading
        }
    }

    private func beginLoadingSequence() {
        loadingTimer?.invalidate()
        loadingProgress = 0
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.035, repeats: true) { timer in
            if loadingProgress >= 1 {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    analysisPreview = PaywallPreviewBuilder.makePreview(from: quizResult)
                    withAnimation(.easeInOut) {
                        step = .analysis
                    }
                }
            } else {
                loadingProgress += 0.02
            }
        }
        RunLoop.main.add(loadingTimer!, forMode: .common)
    }

    private func restartFlow() {
        loadingTimer?.invalidate()
        loadingTimer = nil
        loadingProgress = 0
        quizViewModel.resetSelections()
        quizResult = nil
        analysisPreview = nil
        nameInput = ""
        ageInput = ""
        selectedLanguage = SupportedLanguage.default
        appModel.resetOnboarding()
    }

}

// MARK: - Intro & Warmup

private struct IntroStepView: View {
    var onStart: () -> Void

    var body: some View {
        VStack(spacing: 36) {
            VStack(spacing: 12) {
                Text("Welcome to BetterSide")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white.opacity(0.95))
                Text("Let’s start by learning how you feel about your glow right now.")
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 24)
            }

            Button(action: onStart) {
                Text("Start Quiz")
                    .font(.headline)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: Color.white.opacity(0.4), radius: 18, y: 10)
                    )
                    .foregroundStyle(Color(red: 0.29, green: 0.15, blue: 0.48))
            }
        }
        .padding()
    }
}

private struct WarmupStepView: View {
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 16) {
                Text("BetterSide will help you look and feel like your best self.")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text("Now let’s build the app around you.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            Button(action: onNext) {
                Text("Next")
                    .font(.headline)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                            )
                    )
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 60)
        }
        .padding()
    }
}

// MARK: - Question Step

private struct QuestionStepView: View {
    let question: QuizQuestion
    let stepIndex: Int
    let totalSteps: Int
    let selectedLanguage: SupportedLanguage
    var onLanguageChange: (SupportedLanguage) -> Void
    var onAnswer: (QuizOption) -> Void
    var onSkip: () -> Void

    private let languages = SupportedLanguage.all

    var body: some View {
        VStack(spacing: 24) {
            ProgressView(value: Double(stepIndex + 1), total: Double(totalSteps))
                .tint(.white)
                .padding(.top, 16)
                .padding(.horizontal, 24)

            HStack {
                Text("Question \(stepIndex + 1) of \(totalSteps)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Menu {
                    ForEach(languages) { language in
                        Button(action: { onLanguageChange(language) }) {
                            Label(language.displayName, systemImage: language == selectedLanguage ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                        Text(selectedLanguage.shortCode)
                            .font(.footnote.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                    )
                    .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 24)

            VStack(spacing: 20) {
                Text(question.prompt)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    ForEach(question.options) { option in
                        Button(action: { onAnswer(option) }) {
                            HStack {
                                Text(option.title)
                                    .font(.body.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.body.weight(.semibold))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white.opacity(0.18))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
                            )
                        }
                        .foregroundStyle(.white)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }

            Spacer()

            Button(role: .cancel, action: onSkip) {
                Text("Skip quiz")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.bottom, 32)
        }
    }

}

private struct IdentityCaptureView: View {
    @Binding var name: String
    @Binding var age: String
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Finally.")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("A little more about you.")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))

            VStack(spacing: 16) {
                TextField("First name", text: $name)
                    .textInputAutocapitalization(.words)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                    )
                    .foregroundStyle(.white)

                TextField("Age (optional)", text: $age)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                    )
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onComplete) {
                Text("Complete quiz")
                    .font(.headline)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(canSubmit ? Color.white : Color.white.opacity(0.25))
                    )
                    .foregroundStyle(canSubmit ? Color(red: 0.29, green: 0.15, blue: 0.48) : .white.opacity(0.6))
            }
            .disabled(!canSubmit)
            .padding(.bottom, 48)
        }
        .padding()
    }

    private var canSubmit: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return false
        }
        // Age is optional, so we don't validate it
        return true
    }
}

// MARK: - Loading

private struct LoadingPlanView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Making plan…")
                .font(.title.bold())
                .foregroundStyle(.white)

            ProgressView(value: progress)
                .tint(.white)
                .scaleEffect(x: 1, y: 3, anchor: .center)
                .padding(.horizontal, 48)

            Text("\(Int(min(progress, 1) * 100))%")
                .font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
        .padding()
    }
}

// MARK: - Analysis

private struct AnalysisSummaryView: View {
    let preview: PaywallPreview?
    let userName: String?
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Analysis complete.")
                .font(.title.bold())
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                if let preview {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(preview.headline)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)

                        if !preview.insightBullets.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("What you told us")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.8))
                                ForEach(preview.insightBullets, id: \.self) { line in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle()
                                            .fill(Color.white.opacity(0.6))
                                            .frame(width: 6, height: 6)
                                            .padding(.top, 6)
                                        Text(line)
                                            .font(.footnote)
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                }
                            }
                        }

                        if !preview.solutionBullets.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("How BetterSide will solve it")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.8))
                                ForEach(preview.solutionBullets, id: \.self) { line in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "sparkle")
                                            .font(.footnote)
                                            .foregroundStyle(.white.opacity(0.8))
                                            .padding(.top, 4)
                                        Text(line)
                                            .font(.footnote)
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
                } else {
                    Text("Your personalized glow game plan is queued and ready.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onContinue) {
                Text("Keep going")
                    .font(.headline)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1.2)
                            )
                    )
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 40)
        }
        .padding()
    }
}

// MARK: - Consequences

private struct ConsequenceSlideView: View {
    let slide: OnboardingSlide
    let userName: String?
    var onNext: () -> Void
    var onSkip: () -> Void

    private var displayName: String {
        guard let name = userName, !name.isEmpty else { return "you" }
        return name
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(slide.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)

            Text(String(format: slide.message, displayName))
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 16) {
                Button(action: onNext) {
                    Text("Next")
                        .font(.headline)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                        )
                        .foregroundStyle(.white)
                }

                Button(role: .cancel, action: onSkip) {
                    Text("Skip")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.bottom, 48)
        }
        .padding()
    }
}

// MARK: - Celebration

private struct FinalWelcomeView: View {
    let quotes: [ReviewQuote]
    var onCallToAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Text("Welcome to BetterSide")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .padding(.top, 48)

                Text("People you already trust believe in looking like the best version of yourself—every single day.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 16) {
                    ForEach(quotes) { quote in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("“\(quote.quote)”")
                                .font(.subheadline.italic())
                                .foregroundStyle(.white.opacity(0.9))
                            Text("— \(quote.name)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                    }
                }
                .padding(.horizontal, 20)

                Button(action: onCallToAction) {
                    Text("Start my journey today")
                        .font(.headline)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.25), radius: 18, y: 14)
                        )
                        .foregroundStyle(Color(red: 0.29, green: 0.15, blue: 0.48))
                }
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Supporting Models

private struct SupportedLanguage: Identifiable, Equatable {
    let id = UUID()
    let displayName: String
    let shortCode: String

    static let all: [SupportedLanguage] = [
        SupportedLanguage(displayName: "English", shortCode: "EN"),
        SupportedLanguage(displayName: "Español", shortCode: "ES"),
        SupportedLanguage(displayName: "Français", shortCode: "FR")
    ]

    static let `default` = SupportedLanguage.all.first!
}

private struct OnboardingSlide: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let message: String

    static let defaultSlides: [OnboardingSlide] = [
        OnboardingSlide(
            id: "slide1",
            emoji: "😔",
            title: "Without BetterSide",
            message: "Posting a selfie and cringing at how different you look from the mirror. Wondering why your angles feel off no matter how hard you try, %@."
        ),
        OnboardingSlide(
            id: "slide2",
            emoji: "🤔",
            title: "Without BetterSide",
            message: "Spending $$$ on skincare, makeup, and new outfits—but still feeling like something's missing. Like you're guessing instead of knowing what works, %@."
        ),
        OnboardingSlide(
            id: "slide3",
            emoji: "😰",
            title: "Without BetterSide",
            message: "Getting ready for an event and feeling that familiar panic: 'Do I actually look good or am I lying to myself?' The uncertainty ruins the vibe before you even leave, %@."
        )
    ]
}

private struct ReviewQuote: Identifiable {
    let id: String
    let quote: String
    let name: String

    static let influencerVoices: [ReviewQuote] = [
        ReviewQuote(
            id: "q1",
            quote: "This app literally told me why certain photos work and others don't. I've been guessing my whole life.",
            name: "Emma, 22"
        ),
        ReviewQuote(
            id: "q2",
            quote: "I used to buy so much random makeup. Now I know my exact colors and I look better spending less.",
            name: "Sophia, 19"
        ),
        ReviewQuote(
            id: "q3",
            quote: "The posing tips alone changed my entire Instagram. People keep asking if I got work done lol.",
            name: "Mia, 24"
        )
    ]
}

// MARK: - Missing View Components

// MARK: - PlanSelectionSheet Removed

// Note: PlanSelectionSheet was removed as the plan selection is now handled by SubscriptionGateView
// in full screen mode instead of as a sheet popup during onboarding.
