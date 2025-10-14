//
//  SubscriptionGateView.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import SwiftUI

struct SubscriptionGateView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    let preview: PaywallPreview
    let primaryButtonTitle: String
    var showBack: Bool
    var onPrimary: @Sendable (_ product: GlowUpProduct) async throws -> Void
    var onBack: (() -> Void)?
    var onDecline: (() -> Void)?

    @State private var selectedPlan: PaywallPlan = .annual
    @State private var includeTrial = true
    @State private var isLoading = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    private let plans = PaywallPlan.all

    var body: some View {
        ZStack {
            GradientBackground.twilightAura
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    header
                    previewCard
                    planPicker
                    valueComparisonSection
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    primaryButton
                    restoreButton
                    declineButton
                }
                .padding(.top, 72)
                .padding(.bottom, 40)
            }
        }
        .overlay(alignment: .topLeading) {
            if showBack, let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.backward")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding()
                }
            }
        }
        .onAppear {
            includeTrial = selectedPlan.supportsTrial
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Your personalized glow plan is ready 🌟")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text("You told us exactly where glow feels hard—we’ll handle the roadmap. Pick the plan that matches your pace.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 24)
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(preview.headline)
                .font(.headline)
                .foregroundStyle(.white)

            if !preview.insightBullets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You shared")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
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
                    Text("GlowUp will")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    ForEach(preview.solutionBullets, id: \.self) { line in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkle")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.85))
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
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.2))
                )
        )
        .padding(.horizontal, 20)
    }

    private var planPicker: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your plan")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(plans) { plan in
                PaywallPlanCard(plan: plan, isSelected: plan == selectedPlan)
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            selectedPlan = plan
                            includeTrial = plan.supportsTrial ? true : false
                        }
                    }
            }

            if selectedPlan.supportsTrial {
                Toggle(isOn: $includeTrial) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activate 7-day free trial")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("We’ll only bill after your trial ends. Cancel anytime in Settings → Subscriptions.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.94, green: 0.34, blue: 0.56)))
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
            }

            Text("No commitment. Cancel anytime.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 20)
    }
    
    private var valueComparisonSection: some View {
        VStack(spacing: 12) {
            Text("💰 What you're actually spending")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            valueComparison
        }
        .padding(.horizontal, 20)
    }

    private var valueComparison: some View {
        let copy = priceComparison(for: selectedPlan)
        return VStack(alignment: .leading, spacing: 16) {
            Text(copy.headline)
                .font(.body.weight(.bold))
                .foregroundStyle(.white)

            Text(copy.subtitle)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .background(Color.white.opacity(0.3))
                .padding(.vertical, 4)

            HStack(alignment: .top, spacing: 12) {
                comparisonColumn(
                    title: copy.everydayTitle,
                    icon: "creditcard.fill",
                    lines: copy.everydaySpending,
                    accentColor: Color(red: 1.0, green: 0.6, blue: 0.4)
                )
                
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1)
                    .padding(.vertical, 4)
                
                comparisonColumn(
                    title: "GlowUp gives you",
                    icon: "star.fill",
                    lines: copy.glowupBenefits,
                    accentColor: Color(red: 0.94, green: 0.34, blue: 0.56)
                )
            }
            
            Text("Real talk: You'll spend way more on coffee this month than a year of GlowUp. But coffee lasts 20 minutes. This? This lasts forever. 💅")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .italic()
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }

    private func comparisonColumn(title: String, icon: String, lines: [String], accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .textCase(.uppercase)
            }
            .padding(.bottom, 2)
            
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(accentColor.opacity(0.8))
                        .frame(width: 4, height: 4)
                        .padding(.top, 5)
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func priceComparison(for plan: PaywallPlan) -> PriceComparison {
        switch plan.id {
        case "annual":
            return PriceComparison(
                headline: "Less than ONE iced matcha per month 🌿✨",
                subtitle: "You're already spending way more on things you'll forget tomorrow. GlowUp is \(plan.pricePerMonth)/month ($29.99 today) and pays you back every single day.",
                everydayTitle: "What you're already spending every month",
                everydaySpending: [
                    "$72 on matcha/coffee runs (3x/week habit you don't think about)",
                    "$45 on that \"quick\" Sephora trip for products you use once",
                    "$20 on impulse Amazon buys that show up and confuse you",
                    "$18 on the iced latte + pastry combo before brunch"
                ],
                glowupBenefits: [
                    "AI photo analysis in seconds—know EXACTLY what works on you",
                    "Your personal color palette so you stop buying things that wash you out",
                    "Posing, angles & lighting tips that make every pic glow-worthy",
                    "Confidence that compounds—you look better AND feel it"
                ]
            )
        case "monthly":
            return PriceComparison(
                headline: "Literally the price of ONE iced coffee ☕️",
                subtitle: "Think about how many lattes you grab per week without blinking. GlowUp is \(plan.pricePerMonth) total for the ENTIRE month. One coffee = 30 days of glow insights.",
                everydayTitle: "Things you buy without thinking twice",
                everydaySpending: [
                    "$6.50 iced latte at the cute cafe (you get like 3-4/week)",
                    "$8 açai bowl for the 'gram (eaten in 5 minutes, forgotten in 6)",
                    "$12 trending lip combo from TikTok (sits in your drawer)",
                    "$15 \"treat yourself\" Target haul of things you didn't need"
                ],
                glowupBenefits: [
                    "Instant photo breakdowns whenever you need them—dates, interviews, content",
                    "Know your exact seasonal colors so makeup and clothes actually work",
                    "Soft-max glow tips that cost $0 but boost your confidence 24/7",
                    "Stop guessing what looks good—the AI tells you based on YOUR face"
                ]
            )
        default:
            return PriceComparison(
                headline: "Your daily coffee habit costs more than this 💸",
                subtitle: "One month of GlowUp = less than your weekly coffee runs. But unlike coffee, this investment keeps paying off.",
                everydayTitle: "Money you spend on autopilot",
                everydaySpending: [
                    "$25-30/week on coffee & drinks you barely taste",
                    "$40-50/month on beauty products from viral TikToks",
                    "$15-20/month on subscriptions you forgot you have",
                    "$30+ on \"I'll definitely use this\" impulse buys"
                ],
                glowupBenefits: [
                    "AI coaching that adapts to YOU—not generic tips from the internet",
                    "Confidence in every photo, date, interview, and mirror check",
                    "Color theory, face shape analysis, and posing guides—all personalized",
                    "Knowledge that stays with you forever vs. products you'll replace monthly"
                ]
            )
        }
    }

    private struct PriceComparison {
        let headline: String
        let subtitle: String
        let everydayTitle: String
        let everydaySpending: [String]
        let glowupBenefits: [String]
    }

    private var primaryButton: some View {
        Button {
            guard !isLoading else { return }
            isLoading = true
            errorMessage = nil
            Task {
                do {
                    try await onPrimary(selectedPlan.product)
                } catch {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        } label: {
            let buttonTitle = (selectedPlan.supportsTrial && includeTrial) ? primaryButtonTitle : "Unlock GlowUp Today"
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(buttonTitle)
                        .font(.headline)
                    Text(selectedPlan.ctaSubtitle(includeTrial: includeTrial))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.94, green: 0.34, blue: 0.56))
                    .shadow(color: Color.black.opacity(0.3), radius: 18, y: 12)
            )
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
        }
    }

    private var restoreButton: some View {
        Button {
            guard !isLoading, !isRestoring else { return }
            isRestoring = true
            errorMessage = nil
            Task {
                do {
                    try await subscriptionManager.restorePurchases()
                } catch {
                    errorMessage = error.localizedDescription
                }
                isRestoring = false
            }
        } label: {
            HStack(spacing: 6) {
                if isRestoring {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                Text("Restore Purchase")
                    .font(.footnote.weight(.medium))
                    .underline()
            }
            .padding(.top, 4)
            .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 20)
    }

    private var declineButton: some View {
        Button {
            onDecline?()
        } label: {
            Text("Maybe later")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}

private struct PaywallPlanCard: View {
    let plan: PaywallPlan
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(plan.title)
                    .font(.headline)
                Spacer()
                if let badge = plan.badge {
                    Text(badge)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.25))
                        )
                }
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.9))

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(plan.pricePerMonth)
                    .font(.title2.bold())
                Text("per month")
                    .font(.footnote.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.85))

            if let original = plan.originalPrice {
                HStack(spacing: 6) {
                    Text(original)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .strikethrough(true)
                    Text(plan.savingsCopy)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Text(plan.billingDescription)
                .font(.footnote)
                .foregroundStyle(isSelected ? .white.opacity(0.85) : .white.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isSelected ? Color(red: 0.29, green: 0.15, blue: 0.48) : Color.white.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
    }
}

private struct PaywallPlan: Identifiable, Equatable {
    let id: String
    let title: String
    let pricePerMonth: String
    let billingDescription: String
    let originalPrice: String?
    let savingsCopy: String
    let badge: String?
    let supportsTrial: Bool
    let product: GlowUpProduct

    static let annual = PaywallPlan(
        id: "annual",
        title: "Annual Glow Plan",
        pricePerMonth: "$2.50",
        billingDescription: "Billed $29.99 today.",
        originalPrice: "$149.99",
        savingsCopy: "Save big vs. monthly",
        badge: "Best value",
        supportsTrial: true,
        product: .proAnnual
    )

    static let monthly = PaywallPlan(
        id: "monthly",
        title: "Monthly Glow Plan",
        pricePerMonth: "$4.99",
        billingDescription: "Billed $4.99 every month.",
        originalPrice: nil,
        savingsCopy: "",
        badge: nil,
        supportsTrial: false,
        product: .proMonthly
    )

    static let all: [PaywallPlan] = [.annual, .monthly]
}
private extension PaywallPlan {
    func ctaSubtitle(includeTrial: Bool) -> String {
        if supportsTrial && includeTrial {
            return "Trial ends before billing—reminders inside the app."
        }
        switch id {
        case "annual":
            return "Charged $29.99 today for 12 months of coaching."
        case "monthly":
            return "Charged $4.99 today—renews monthly."
        default:
            return "Secure checkout handled by Apple."
        }
    }
}
