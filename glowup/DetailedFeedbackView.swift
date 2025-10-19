//
//  DetailedFeedbackView.swift
//  glowup
//
//  Created by AI Assistant
//

import SwiftUI
import UIKit

/// Shows annotated image with detailed, conversational feedback
struct DetailedFeedbackView: View {
    private let presetAnalysis: DetailedPhotoAnalysis?
    private let presetAnnotatedImage: UIImage?
    private let showAnnotatedImage: Bool
    private let showsNavigationTitle: Bool

    @Environment(\.openURL) private var openURL
    @State private var annotatedImage: UIImage?
    @State private var analysis: PhotoAnalysisVariables?
    @State private var summaryText: String?
    @State private var personalizedTips: [String] = []
    @State private var isFallbackAnalysis = false
    @State private var recommendationPlan: PersonalizedRecommendationPlan?

    init(
        analysis: DetailedPhotoAnalysis? = nil,
        annotatedImage: UIImage? = nil,
        showAnnotatedImage: Bool = true,
        showsNavigationTitle: Bool = true
    ) {
        self.presetAnalysis = analysis
        self.presetAnnotatedImage = annotatedImage
        self.showAnnotatedImage = showAnnotatedImage
        self.showsNavigationTitle = showsNavigationTitle

        let initialAnalysis = analysis?.variables
        let initialSummary = analysis?.summary
        let plan: PersonalizedRecommendationPlan?
        if let detailed = analysis {
            if detailed.isFallback {
                plan = nil
                _personalizedTips = State(initialValue: detailed.personalizedTips)
            } else {
                let builtPlan = PersonalizedRecommendationBuilder(analysis: detailed).buildPlan()
                plan = builtPlan
                if !builtPlan.shortTerm.isEmpty {
                    _personalizedTips = State(initialValue: builtPlan.shortTerm.map { $0.body })
                } else {
                    _personalizedTips = State(initialValue: detailed.personalizedTips)
                }
            }
        } else {
            plan = nil
            _personalizedTips = State(initialValue: [])
        }

        _annotatedImage = State(initialValue: annotatedImage)
        _analysis = State(initialValue: initialAnalysis)
        _summaryText = State(initialValue: initialSummary)
        _isFallbackAnalysis = State(initialValue: analysis?.isFallback ?? false)
        _recommendationPlan = State(initialValue: plan)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Annotated Image with Face Overlay
                if showAnnotatedImage, let image = annotatedImage {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Photo Analysis")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                        
                        Text("Glowing overlay traces your detected face shape and key landmarks.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                if isFallbackAnalysis {
                    fallbackMessage
                } else if let analysis = analysis {
                    overviewSection(analysis)
                    detailedFeedbackSections(analysis)
                }
            }
            .padding()
        }
        .background(GradientBackground.twilightAura.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .modifier(ConditionalNavigationTitleModifier(showsTitle: showsNavigationTitle))
        .onAppear {
            if presetAnnotatedImage == nil && showAnnotatedImage {
                loadAnnotatedImage()
            }
            if presetAnalysis == nil {
                loadAnalysis()
            }
        }
    }
    
    private func overviewSection(_ analysis: PhotoAnalysisVariables) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let summary = summaryText?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Summary")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.7))
                    Text(summary)
                        .font(.body.weight(.medium))
                        .foregroundColor(.white)
                }
            }
            
            metricsGrid(for: analysis)
            
            if !personalizedTips.isEmpty {
                legacyPersonalizedTipsSection()
            }
        }
        .padding()
        .background(Color.white.opacity(0.12))
        .cornerRadius(24)
    }
    
    private var fallbackMessage: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundColor(.yellow)
            Text(summaryText ?? "We couldn't build a live analysis just now.")
                .font(.body.weight(.medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(personalizedTips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkle")
                            .foregroundColor(.pink)
                        Text(tip)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.white.opacity(0.12))
        .cornerRadius(24)
    }
    
    @ViewBuilder
    private func detailedFeedbackSections(_ analysis: PhotoAnalysisVariables) -> some View {
        VStack(spacing: 20) {
            facialStructureSection(analysis)
            skinTextureSection(analysis)
            browDensitySection(analysis)
            
            if !analysis.bestTraits.isEmpty || !analysis.traitsToImprove.isEmpty || !analysis.holdingBackFactors.isEmpty {
                traitBreakdownSection(analysis)
            }
            
            if !analysis.roadmap.isEmpty {
                roadmapSection(analysis.roadmap)
            }
            
            // Lighting Feedback (always show)
            feedbackCard(
                icon: "light.max",
                color: .yellow,
                title: "Lighting",
                feedback: analysis.lightingFeedback,
                score: analysis.lightingQuality
            )
            
            // Eye Color & Palette (only if AI detected eye color)
            if let eyeFeedback = analysis.eyeColorFeedback {
                feedbackCard(
                    icon: "eye.fill",
                    color: .blue,
                    title: "Eye Color & Color Palette",
                    feedback: eyeFeedback,
                    score: nil
                )
            }
            
            // Seasonal palette, skin tone, and hair harmony
            if hasPaletteInsights(for: analysis) {
                colorPaletteSection(analysis)
            }
            
            // Pose & Angle (always show)
            feedbackCard(
                icon: "figure.stand",
                color: .green,
                title: "Pose & Angle",
                feedback: analysis.poseFeedback,
                score: analysis.angleFlatter
            )
            
            // Makeup & Style (always show)
            feedbackCard(
                icon: "wand.and.stars",
                color: .orange,
                title: "Makeup & Style",
                feedback: analysis.makeupFeedback,
                score: analysis.makeupSuitability
            )
            
            // Composition (always show)
            feedbackCard(
                icon: "viewfinder",
                color: .cyan,
                title: "Composition & Background",
                feedback: analysis.compositionFeedback,
                score: analysis.overallComposition
            )
            
            // Quick Wins
            if !analysis.quickWins.isEmpty {
                quickWinsCard(analysis)
            }
            
            let habits = lifestyleHabits(for: analysis)
            if !habits.isEmpty {
                foundationalHabitsSection(
                    habits,
                    isAIProvided: !analysis.foundationalHabits.isEmpty
                )
            }
            
            if let plan = recommendationPlan {
                if !plan.shortTerm.isEmpty {
                    actionTipsSection(
                        title: "Instant Fixes",
                        icon: "sparkle",
                        tips: plan.shortTerm,
                        accent: Color(red: 0.94, green: 0.34, blue: 0.56)
                    )
                }
                if !plan.longTerm.isEmpty {
                    actionTipsSection(
                        title: "Long-Term Upgrades",
                        icon: "calendar",
                        tips: plan.longTerm,
                        accent: .cyan
                    )
                }
                if !plan.celebrityMatches.isEmpty {
                    celebrityVibeSection(plan.celebrityMatches)
                }
                if !plan.pinterestIdeas.isEmpty {
                    pinterestSearchSection(plan.pinterestIdeas)
                }
            } else if !personalizedTips.isEmpty {
                legacyPersonalizedTipsSection()
            }
        }
    }
    
    // MARK: - UI Components
    
    private func metricsGrid(for analysis: PhotoAnalysisVariables) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        let lightingScore = String(format: "%.1f/10", analysis.lightingQuality)
        let glowScore = String(format: "%.1f/10", analysis.overallGlowScore)
        let makeupScore = String(format: "%.1f/10", analysis.makeupSuitability)
        let harmonyScore = String(format: "%.1f/10", analysis.facialHarmonyScore)
        let angularityScore = String(format: "%.1f/10", analysis.facialAngularityScore)
        let skinScore = String(format: "%.1f/10", analysis.skinTextureScore)
        let browScore = String(format: "%.1f/10", analysis.eyebrowDensityScore)
        
        var metrics: [(String, String, String, String?)] = [
            ("lightbulb.max", "Lighting", lightingScore, analysis.lightingType),
            ("sparkles", "Glow Score", glowScore, nil),
            ("ruler.fill", "Harmony", harmonyScore, analysis.genderDimorphism),
            ("triangle.circle.fill", "Angles", angularityScore, analysis.faceFullnessDescriptor),
            ("drop.fill", "Skin", skinScore, nil),
            ("eyeglasses", "Brows", browScore, nil)
        ]
        
        // Only add metrics if values were detected
        if let faceShape = analysis.faceShape {
            metrics.append(("face.smiling", "Face Shape", faceShape, nil))
        }
        if let palette = analysis.seasonalPalette {
            metrics.append(("paintpalette.fill", "Palette", palette, analysis.bestColors.first))
        }
        if let eyeColor = analysis.eyeColor {
            metrics.append(("eye.fill", "Eye Color", eyeColor, analysis.eyeContact))
        }
        metrics.append(("wand.and.stars.inverse", "Makeup", analysis.makeupStyle, makeupScore))
        
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { item in
                let metric = item.element
                quickMetricCard(icon: metric.0, title: metric.1, value: metric.2, detail: metric.3)
            }
        }
    }
    
    private func quickMetricCard(icon: String, title: String, value: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .symbolVariant(.fill)
                    .foregroundColor(.white)
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white.opacity(0.6))
            }
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.22))
        .cornerRadius(18)
    }
    
    private func facialStructureSection(_ analysis: PhotoAnalysisVariables) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "ruler.fill")
                    .foregroundColor(.pink)
                Text("Facial Harmony Map")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            Text(analysis.featureBalanceDescription)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
            
            HStack(spacing: 12) {
                scoreBadge(title: "Harmony", value: analysis.facialHarmonyScore, accent: .pink)
                scoreBadge(title: "Angularity", value: analysis.facialAngularityScore, accent: .purple)
            }
            
            HStack(spacing: 12) {
                infoChip(title: "Dimorphism", detail: analysis.genderDimorphism)
                infoChip(title: "Fullness", detail: analysis.faceFullnessDescriptor)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(22)
    }
    
    private func skinTextureSection(_ analysis: PhotoAnalysisVariables) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.cyan)
                Text("Skin Texture Insight")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            scoreBadge(title: "Texture Score", value: analysis.skinTextureScore, accent: .cyan)
            Text(analysis.skinTextureDescription)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            if !analysis.skinConcernHighlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(analysis.skinConcernHighlights, id: \.self) { concern in
                        bulletRow(icon: "exclamationmark.circle.fill", accent: .yellow, text: concern)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
    }
    
    private func browDensitySection(_ analysis: PhotoAnalysisVariables) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "eyeglasses")
                    .foregroundColor(.mint)
                Text("Brows & Framing")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            scoreBadge(title: "Density Score", value: analysis.eyebrowDensityScore, accent: .mint)
            Text(analysis.eyebrowFeedback)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
    }
    
    private func traitBreakdownSection(_ analysis: PhotoAnalysisVariables) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.orange)
                Text("Trait Breakdown")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            if !analysis.bestTraits.isEmpty {
                bulletList(title: "Best Traits", icon: "star.fill", accent: .green, items: analysis.bestTraits)
            }
            if !analysis.traitsToImprove.isEmpty {
                bulletList(title: "Traits to Refine", icon: "wand.and.stars", accent: .orange, items: analysis.traitsToImprove)
            }
            if !analysis.holdingBackFactors.isEmpty {
                bulletList(title: "Holding You Back", icon: "flag.fill", accent: .red, items: analysis.holdingBackFactors)
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
    }
    
    private func roadmapSection(_ steps: [ImprovementRoadmapStep]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(.purple)
                Text("Soft-Max Roadmap")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            ForEach(steps) { step in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        infoChip(title: step.timeframe, detail: step.focus)
                        Spacer()
                    }
                    ForEach(Array(step.actions.enumerated()), id: \.offset) { index, action in
                        bulletRow(icon: "checkmark.seal.fill", accent: .purple, text: action, number: index + 1)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.07))
                .cornerRadius(18)
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(22)
    }
    
    private func scoreBadge(title: String, value: Double, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.6))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", value))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(accent)
                Text("/10")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.18))
        .cornerRadius(16)
    }
    
    private func infoChip(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.55))
            Text(detail)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }
    
    private func bulletList(title: String, icon: String, accent: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(accent)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    bulletRow(icon: "circle.fill", accent: accent, text: item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func bulletRow(icon: String, accent: Color, text: String, number: Int? = nil) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let number {
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(accent.opacity(0.3))
                    .cornerRadius(11)
            } else {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(accent)
                    .frame(width: 18)
            }
            Text(text)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func hasPaletteInsights(for analysis: PhotoAnalysisVariables) -> Bool {
        return analysis.seasonalPalette != nil
            || !analysis.bestColors.isEmpty
            || !analysis.avoidColors.isEmpty
            || analysis.skinToneFeedback != nil
            || analysis.hairColorFeedback != nil
            || (analysis.hairColor?.isEmpty == false)
    }
    
    private func colorPaletteSection(_ analysis: PhotoAnalysisVariables) -> some View {
        let bestSwatches = paletteSwatches(from: Array(analysis.bestColors.prefix(8)))
        let avoidSwatches = paletteSwatches(from: Array(analysis.avoidColors.prefix(8)))
        let seasonTitle: String = {
            if let palette = analysis.seasonalPalette {
                return "\(palette) Season"
            } else {
                return "Custom Palette"
            }
        }()
        let makeupLine = makeupCaption(for: analysis)
        
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "paintpalette.fill")
                    .foregroundColor(.pink)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(seasonTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let undertone = analysis.skinUndertone {
                        Text("Undertone: \(undertone)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                if let hair = analysis.hairColor, !hair.isEmpty {
                    Label(hair.capitalized, systemImage: "drop.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                }
            }
            
            if !bestSwatches.isEmpty {
                paletteGrid(
                    title: "Glow Colors",
                    icon: "sparkles",
                    accent: Color(red: 0.94, green: 0.34, blue: 0.56),
                    swatches: bestSwatches,
                    isRecommended: true
                )
            }
            
            if !avoidSwatches.isEmpty {
                paletteGrid(
                    title: "Colors to Ease Up",
                    icon: "nosign",
                    accent: .orange,
                    swatches: avoidSwatches,
                    isRecommended: false
                )
            }
            
            if let skinFeedback = analysis.skinToneFeedback {
                Divider().overlay(Color.white.opacity(0.08))
                Text(skinFeedback)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if let hairFeedback = analysis.hairColorFeedback {
                Text(hairFeedback)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if !makeupLine.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.pink)
                    Text(makeupLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(22)
    }
    
    private func paletteGrid(
        title: String,
        icon: String,
        accent: Color,
        swatches: [PaletteColor],
        isRecommended: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(accent)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 16)], spacing: 16) {
                ForEach(swatches) { swatch in
                    PaletteSwatch(label: swatch.label, fill: swatch.color, isRecommended: isRecommended)
                }
            }
        }
    }
    
    private func paletteSwatches(from names: [String]) -> [PaletteColor] {
        names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { PaletteColor(label: $0, color: colorForName($0)) }
    }
    
    private func colorForName(_ name: String) -> Color {
        let normalized = name.lowercased()
        func color(_ r: Double, _ g: Double, _ b: Double) -> Color {
            Color(red: r / 255.0, green: g / 255.0, blue: b / 255.0)
        }
        
        if normalized.contains("ivory") || normalized.contains("cream") {
            return color(248, 241, 223)
        }
        if normalized.contains("champagne") || normalized.contains("beige") || normalized.contains("sand") {
            return color(227, 200, 161)
        }
        if normalized.contains("peach") || normalized.contains("apricot") {
            return color(246, 194, 162)
        }
        if normalized.contains("coral") {
            return color(242, 127, 124)
        }
        if normalized.contains("rose") || normalized.contains("blush") || normalized.contains("pink") {
            return color(232, 161, 198)
        }
        if normalized.contains("magenta") || normalized.contains("fuchsia") {
            return color(219, 64, 128)
        }
        if normalized.contains("plum") || normalized.contains("eggplant") {
            return color(112, 54, 117)
        }
        if normalized.contains("burgundy") || normalized.contains("wine") {
            return color(104, 28, 49)
        }
        if normalized.contains("red") || normalized.contains("scarlet") {
            return color(207, 63, 61)
        }
        if normalized.contains("orange") || normalized.contains("amber") {
            return color(239, 139, 55)
        }
        if normalized.contains("gold") || normalized.contains("mustard") {
            return color(214, 161, 54)
        }
        if normalized.contains("caramel") || normalized.contains("copper") || normalized.contains("bronze") {
            return color(190, 112, 58)
        }
        if normalized.contains("olive") || normalized.contains("chartreuse") {
            return color(139, 153, 67)
        }
        if normalized.contains("sage") || normalized.contains("mint") {
            return color(166, 198, 158)
        }
        if normalized.contains("emerald") || normalized.contains("forest") || normalized.contains("green") {
            return color(52, 124, 100)
        }
        if normalized.contains("teal") || normalized.contains("turquoise") {
            return color(62, 153, 164)
        }
        if normalized.contains("aqua") || normalized.contains("seafoam") {
            return color(131, 202, 205)
        }
        if normalized.contains("navy") || normalized.contains("midnight") {
            return color(32, 53, 96)
        }
        if normalized.contains("cobalt") || normalized.contains("royal blue") {
            return color(64, 92, 191)
        }
        if normalized.contains("denim") || normalized.contains("indigo") {
            return color(63, 74, 126)
        }
        if normalized.contains("lilac") || normalized.contains("lavender") {
            return color(188, 176, 220)
        }
        if normalized.contains("silver") || normalized.contains("platinum") {
            return color(196, 205, 210)
        }
        if normalized.contains("charcoal") || normalized.contains("graphite") {
            return color(70, 76, 87)
        }
        if normalized.contains("gray") || normalized.contains("grey") {
            return color(128, 133, 144)
        }
        if normalized.contains("black") || normalized.contains("onyx") {
            return color(24, 24, 28)
        }
        if normalized.contains("white") || normalized.contains("snow") {
            return color(245, 245, 245)
        }
        if normalized.contains("tan") || normalized.contains("camel") {
            return color(205, 170, 125)
        }
        return hashedColor(for: normalized)
    }
    
    private func hashedColor(for name: String) -> Color {
        var hash: UInt64 = 0xcbf29ce484222325
        for scalar in name.unicodeScalars {
            hash ^= UInt64(scalar.value)
            hash &*= 0x100000001b3
        }
        let redComponent = Double((hash >> 40) & 0xFF) / 255.0
        let greenComponent = Double((hash >> 24) & 0xFF) / 255.0
        let blueComponent = Double((hash >> 8) & 0xFF) / 255.0
        func adjusted(_ component: Double) -> Double {
            return 0.28 + component * 0.6
        }
        return Color(
            red: adjusted(redComponent),
            green: adjusted(greenComponent),
            blue: adjusted(blueComponent)
        )
    }
    
    private func makeupCaption(for analysis: PhotoAnalysisVariables) -> String {
        let style = analysis.makeupStyle.lowercased()
        switch style {
        case "natural":
            return "Lean into soft-focus makeup: tinted moisturizer, cream blush, and brushed-up brows support this palette."
        case "minimal":
            return "Keep it sheer and skin-forward. Prioritize hydration, clear balm, and subtle highlight to echo your palette."
        case "glam":
            return "Amplify contrast with defined liner and luminous highlight. Use your Glow Colors on lips and lids for cohesion."
        case "dramatic":
            return "Play with bold pigments from your Glow Colors across eyes and lips while keeping skin softly matte."
        case "none":
            return "Let skincare and lighting do the work—hydrated skin plus your Glow Colors in wardrobe keeps everything cohesive."
        default:
            return ""
        }
    }
    
    private func lifestyleHabits(for analysis: PhotoAnalysisVariables) -> [String] {
        if !analysis.foundationalHabits.isEmpty {
            return analysis.foundationalHabits
        }
        return fallbackLifestyleHabits(for: analysis)
    }
    
    private func fallbackLifestyleHabits(for analysis: PhotoAnalysisVariables) -> [String] {
        var habits: [String] = []
        
        if analysis.skinTextureScore < 6.5 {
            habits.append("Set a hydration target (~2L/day) and add antioxidant snacks (berries, citrus) to support smoother texture.")
        }
        if analysis.lightingQuality < 6.0 {
            habits.append("Claim 10 minutes of daylight each morning—face a window to train your eye for flattering natural light.")
        }
        if analysis.poseNaturalness < 6.0 || analysis.confidenceScore < 6.0 {
            habits.append("Practice a quick posture reset: shoulders back, chin long, soft smile—repeat in the mirror for 2 minutes daily.")
        }
        if analysis.makeupSuitability < 6.0 && !analysis.bestColors.isEmpty {
            habits.append("Do a weekly makeup bag audit—clean brushes and keep color cosmetics within your Glow Colors palette.")
        }
        if habits.isEmpty {
            habits.append("Keep hydration, daylight exposure, and nutrient-dense meals consistent this week to amplify your natural glow.")
        }
        return habits
    }
    
    private func foundationalHabitsSection(_ habits: [String], isAIProvided: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
                Text("Foundational Habits")
                    .font(.headline)
                    .foregroundStyle(.white)
                if !isAIProvided {
                    Text("auto-suggested")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(habits.enumerated()), id: \.offset) { index, habit in
                    bulletRow(icon: "leaf", accent: .green, text: habit, number: index + 1)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
    }
    
    private struct PaletteColor: Identifiable {
        let id = UUID()
        let label: String
        let color: Color
    }
    
    private struct PaletteSwatch: View {
        let label: String
        let fill: Color
        let isRecommended: Bool
        
        var body: some View {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(fill)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 4)
                    if !isRecommended {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 80)
            }
        }
    }
    
    
    private func legacyPersonalizedTipsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personalized Tips")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.7))
            VStack(alignment: .leading, spacing: 8) {
                ForEach(personalizedTips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkle")
                            .foregroundColor(.pink)
                        Text(tip)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    
    private func feedbackCard(
        icon: String,
        color: Color,
        title: String,
        feedback: String,
        score: Double?
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if let score = score {
                    Spacer()
                    Text("\(Int(score))/10")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(scoreColor(for: score))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(scoreColor(for: score).opacity(0.2))
                        .cornerRadius(12)
                }
            }
            
            Text(feedback)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
    
    private func actionTipsSection(
        title: String,
        icon: String,
        tips: [AppearanceActionTip],
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(accent)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            VStack(spacing: 12) {
                ForEach(tips) { tip in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tip.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                        Text(tip.body)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding()
                    .background(Color.white.opacity(0.09))
                    .cornerRadius(16)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
    }
    
    private func celebrityVibeSection(_ matches: [CelebrityMatchSuggestion]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.3.sequence")
                    .foregroundColor(.purple)
                Text("Celebrity Vibe Matches")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            ForEach(matches) { match in
                VStack(alignment: .leading, spacing: 10) {
                    Text(match.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text(match.descriptor)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(match.whyItWorks)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(18)
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
    }
    
    private func pinterestSearchSection(_ ideas: [PinterestSearchIdea]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "safari")
                    .foregroundColor(.mint)
                Text("Pinterest Search Generator")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            VStack(spacing: 12) {
                ForEach(ideas) { idea in
                    pinterestIdeaCard(idea)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
    }
    
    private func pinterestIdeaCard(_ idea: PinterestSearchIdea) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(idea.label)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = idea.query
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.white.opacity(0.18))
                
                if let url = idea.encodedURL {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Open in Pinterest", systemImage: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.94, green: 0.34, blue: 0.56).opacity(0.6))
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.22))
        .cornerRadius(16)
    }
    
    private func quickWinsCard(_ analysis: PhotoAnalysisVariables) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                    .font(.title3)
                Text("Quick Wins - Try These Now!")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            ForEach(Array(analysis.quickWins.enumerated()), id: \.offset) { index, win in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.yellow.opacity(0.3))
                        .cornerRadius(12)
                    
                    Text(win)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.2), Color.orange.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
    
    private func scoreColor(for score: Double) -> Color {
        if score >= 8.0 { return .green }
        if score >= 6.0 { return .yellow }
        if score >= 4.0 { return .orange }
        return .red
    }
    
    // MARK: - Data Loading
    
    private func loadAnnotatedImage() {
        guard showAnnotatedImage, presetAnnotatedImage == nil else { return }
        if let data = UserDefaults.standard.data(forKey: "LatestAnnotatedImage"),
           let image = UIImage(data: data) {
            self.annotatedImage = image
        }
    }
    
    private func loadAnalysis() {
        guard presetAnalysis == nil else { return }
        if let data = UserDefaults.standard.data(forKey: "LatestDetailedAnalysis"),
           let decoded = try? JSONDecoder().decode(PhotoAnalysisVariables.self, from: data) {
            self.analysis = decoded
        }
        if let planData = UserDefaults.standard.data(forKey: "LatestRecommendationPlan"),
           let decodedPlan = try? JSONDecoder().decode(PersonalizedRecommendationPlan.self, from: planData) {
            recommendationPlan = decodedPlan
        } else {
            recommendationPlan = nil
        }
        summaryText = UserDefaults.standard.string(forKey: "LatestAnalysisSummary")
        if let plan = recommendationPlan, !plan.shortTerm.isEmpty {
            personalizedTips = plan.shortTerm.map { $0.body }
        } else if let tips = UserDefaults.standard.array(forKey: "LatestPersonalizedTips") as? [String] {
            personalizedTips = tips
        } else {
            personalizedTips = []
        }
        isFallbackAnalysis = UserDefaults.standard.bool(forKey: "LatestAnalysisIsFallback")
    }
}

#Preview {
    NavigationStack {
        DetailedFeedbackView()
    }
}

private struct ConditionalNavigationTitleModifier: ViewModifier {
    let showsTitle: Bool

    func body(content: Content) -> some View {
        if showsTitle {
            content.navigationTitle("Detailed Analysis")
        } else {
            content
        }
    }
}
