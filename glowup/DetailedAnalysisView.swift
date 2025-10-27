//
//  DetailedAnalysisView.swift
//  glowup
//
//  Created by AI Assistant
//

import SwiftUI

/// Displays comprehensive photo analysis with all 27 variables
struct DetailedAnalysisView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @AppStorage("hasUsedFreeScan") private var hasUsedFreeScan = false
    let analysis: PhotoAnalysisVariables?
    let isFallback: Bool
    let summary: String?
    
    init() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "LatestDetailedAnalysis"),
           let decoded = try? JSONDecoder().decode(PhotoAnalysisVariables.self, from: data) {
            self.analysis = decoded
        } else {
            self.analysis = nil
        }
        self.isFallback = UserDefaults.standard.bool(forKey: "LatestAnalysisIsFallback")
        self.summary = UserDefaults.standard.string(forKey: "LatestAnalysisSummary")
    }
    
    var body: some View {
        ScrollView {
            if let analysis = analysis {
                if isLimitedExperience {
                    limitedAnalysisContent(analysis)
                } else {
                    VStack(spacing: 24) {
                        // Overall Scores Header
                        overallScoresSection(analysis)
                        
                        // Physical Features
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(title: "Your Features", icon: "person.fill", color: .purple)
                            
                            VStack(spacing: 8) {
                                if let faceShape = analysis.faceShape {
                                    infoRow(title: "Face Shape", value: faceShape)
                                }
                                if let skinUndertone = analysis.skinUndertone {
                                    infoRow(title: "Skin Undertone", value: skinUndertone)
                                }
                                if let eyeColor = analysis.eyeColor {
                                    infoRow(title: "Eye Color", value: eyeColor)
                                }
                                if let hairColor = analysis.hairColor {
                                    infoRow(title: "Hair Color", value: hairColor)
                                }
                            }
                            .padding()
                            .background(GlowPalette.softBeige)
                            .cornerRadius(16)
                        }
                        
                        // Color Analysis
                        colorAnalysisSection(analysis)
                        
                        // Lighting Analysis
                        lightingSection(analysis)
                        
                        // Style & Presentation
                        styleSection(analysis)
                        
                        // Posing & Expression
                        posingSection(analysis)
                        
                        // Actionable Insights
                        insightsSection(analysis)
                    }
                    .padding()
                }
            } else if isFallback {
                fallbackState
            } else {
                emptyState
            }
        }
        .background(GradientBackground.twilightAura.ignoresSafeArea())
        .navigationTitle("Detailed Analysis")
    }
    
    // MARK: - Sections
    
    private func limitedAnalysisContent(_ analysis: PhotoAnalysisVariables) -> some View {
        VStack(spacing: 24) {
            limitedSummarySection()
            limitedRatingsSection(analysis)
            limitedQuickFactsSection(analysis)
            
            ForEach(limitedLockedSectionTitles, id: \.self) { title in
                limitedLockedSection(title: title)
            }
            
            limitedUnlockButton
        }
        .padding()
    }
    
    private var limitedLockedSectionTitles: [String] {
        [
            "Facial Harmony Map",
            "Skin Texture Insight",
            "Brows & Framing",
            "Trait Breakdown",
            "Soft-Max Roadmap",
            "Seasonal Color Palette",
            "Pose & Angle Coaching",
            "Makeup & Style Coaching",
            "Composition & Background",
            "Quick Wins - Try These Now!",
            "Foundational Habits"
        ]
    }
    
    private func limitedSummarySection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Summary")
                .font(GlowTypography.glowSubheading.weight(.semibold))
                .foregroundStyle(GlowPalette.deepRose)
            Text(summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Your personalized summary will appear here once we finish processing.")
                .font(GlowTypography.body(17, weight: .medium))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(GlowPalette.creamyWhite.opacity(0.12))
        .cornerRadius(24)
    }
    
    private func limitedRatingsSection(_ analysis: PhotoAnalysisVariables) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ratings")
                .font(GlowTypography.glowSubheading.weight(.semibold))
                .foregroundStyle(GlowPalette.deepRose)
            
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Array(limitedMetrics(for: analysis).enumerated()), id: \.offset) { _, metric in
                    limitedMetricCard(icon: metric.icon, title: metric.title, value: metric.value)
                }
            }
        }
        .padding()
        .background(GlowPalette.creamyWhite.opacity(0.12))
        .cornerRadius(24)
    }
    
    private func limitedQuickFactsSection(_ analysis: PhotoAnalysisVariables) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Facts")
                .font(GlowTypography.glowSubheading.weight(.semibold))
                .foregroundStyle(GlowPalette.deepRose)
            
            VStack(spacing: 10) {
                if let faceShape = analysis.faceShape?.trimmingCharacters(in: .whitespacesAndNewlines), !faceShape.isEmpty {
                    limitedFactRow(icon: "face.smiling", title: "Face Shape", value: faceShape)
                }
                if let eyeColor = analysis.eyeColor?.trimmingCharacters(in: .whitespacesAndNewlines), !eyeColor.isEmpty {
                    limitedFactRow(icon: "eye.fill", title: "Eye Color", value: eyeColor)
                }
            }
            .padding(16)
            .background(GlowPalette.softBeige.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding()
        .background(GlowPalette.creamyWhite.opacity(0.12))
        .cornerRadius(24)
    }
    
    private func limitedLockedSection(title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
                Text(title)
                    .font(GlowTypography.glowSubheading)
                    .foregroundStyle(GlowPalette.deepRose)
            }
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GlowPalette.creamyWhite.opacity(0.08))
                .overlay(
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Locked in Full Analysis")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GlowPalette.deepRose.opacity(0.9))
                        Text("Unlock GlowUp Pro to see the full breakdown and daily plan.")
                            .font(GlowTypography.body())
                            .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
                    }
                    .padding()
                )
                .frame(height: 110)
        }
        .padding()
        .background(GlowPalette.creamyWhite.opacity(0.06))
        .cornerRadius(20)
    }
    
    private var limitedUnlockButton: some View {
        Button {
            SuperwallService.shared.registerEvent("post_paywall_education")
        } label: {
            Text("Unlock Full Analysis")
                .font(GlowTypography.glowSubheading)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            GlowPalette.blushPink,
                            GlowPalette.roseGold.opacity(0.9)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(GlowPalette.deepRose)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
    
    private func limitedMetrics(for analysis: PhotoAnalysisVariables) -> [(icon: String, title: String, value: String)] {
        func formatted(_ value: Double) -> String {
            String(format: "%.1f / 10", value)
        }
        
        return [
            ("sparkles", "Glow Score", formatted(analysis.overallGlowScore)),
            ("heart.fill", "Confidence", formatted(analysis.confidenceScore)),
            ("faceid", "Facial Harmony", formatted(analysis.facialHarmonyScore)),
            ("paintpalette", "Color Harmony", formatted(analysis.colorHarmony)),
            ("rectangle.split.3x3", "Composition", formatted(analysis.overallComposition)),
            ("light.max", "Lighting Quality", formatted(analysis.lightingQuality)),
            ("triangle.fill", "Angle Definition", formatted(analysis.facialAngularityScore)),
            ("drop.circle", "Skin Texture", formatted(analysis.skinTextureScore)),
            ("figure.stand", "Pose Naturalness", formatted(analysis.poseNaturalness)),
            ("camera.aperture", "Angle Flattery", formatted(analysis.angleFlatter)),
            ("wand.and.stars", "Makeup Suitability", formatted(analysis.makeupSuitability)),
            ("line.3.horizontal.decrease.circle", "Brows", formatted(analysis.eyebrowDensityScore)),
            ("hanger", "Outfit Match", formatted(analysis.outfitColorMatch)),
            ("sparkle.magnifyingglass", "Accessory Balance", formatted(analysis.accessoryBalance)),
            ("photo.artframe", "Background", formatted(analysis.backgroundSuitability))
        ]
    }
    
    private func limitedMetricCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(GlowPalette.deepRose)
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
            }
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(GlowPalette.deepRose)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GlowPalette.creamyWhite.opacity(0.08))
        .cornerRadius(16)
    }
    
    private func limitedFactRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.glowSubheading)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(GlowTypography.caption.weight(.semibold))
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
                Text(value)
                    .font(GlowTypography.body(17, weight: .semibold))
                    .foregroundStyle(GlowPalette.deepRose)
            }
            Spacer(minLength: 0)
        }
    }
    
    private var isLimitedExperience: Bool {
        !subscriptionManager.isSubscribed && hasUsedFreeScan
    }
    
    private func overallScoresSection(_ analysis: PhotoAnalysisVariables) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                scoreCard(
                    title: "Glow Score",
                    score: analysis.overallGlowScore,
                    color: .pink
                )
                scoreCard(
                    title: "Confidence",
                    score: analysis.confidenceScore,
                    color: .orange
                )
            }
            
            HStack(spacing: 20) {
                scoreCard(
                    title: "Color Harmony",
                    score: analysis.colorHarmony,
                    color: .purple
                )
                scoreCard(
                    title: "Composition",
                    score: analysis.overallComposition,
                    color: .blue
                )
            }
        }
    }
    
    private func colorAnalysisSection(_ analysis: PhotoAnalysisVariables) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Color Analysis", icon: "paintpalette.fill", color: .pink)
            
            VStack(alignment: .leading, spacing: 12) {
                if let season = analysis.seasonalPalette {
                    seasonBadge(season)
                }
                
                if !analysis.bestColors.isEmpty {
                    colorList(title: "Your Best Colors", colors: analysis.bestColors, positive: true)
                }
                if !analysis.avoidColors.isEmpty {
                    colorList(title: "Colors to Avoid", colors: analysis.avoidColors, positive: false)
                }
            }
            .padding()
            .background(GlowPalette.softBeige)
            .cornerRadius(16)
        }
    }
    
    private func lightingSection(_ analysis: PhotoAnalysisVariables) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Lighting", icon: "light.max", color: .yellow)
            
            VStack(spacing: 8) {
                scoreRow(title: "Quality", score: analysis.lightingQuality, total: 10)
                infoRow(title: "Type", value: analysis.lightingType)
                infoRow(title: "Direction", value: analysis.lightingDirection)
                infoRow(title: "Exposure", value: analysis.exposure)
            }
            .padding()
            .background(GlowPalette.softBeige)
            .cornerRadius(16)
        }
    }
    
    private func styleSection(_ analysis: PhotoAnalysisVariables) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Style & Presentation", icon: "sparkles", color: .purple)
            
            VStack(spacing: 8) {
                scoreRow(title: "Makeup Suitability", score: analysis.makeupSuitability, total: 10)
                infoRow(title: "Makeup Style", value: analysis.makeupStyle)
                scoreRow(title: "Outfit Match", score: analysis.outfitColorMatch, total: 10)
                scoreRow(title: "Accessory Balance", score: analysis.accessoryBalance, total: 10)
                scoreRow(title: "Background", score: analysis.backgroundSuitability, total: 10)
            }
            .padding()
            .background(GlowPalette.softBeige)
            .cornerRadius(16)
        }
    }
    
    private func posingSection(_ analysis: PhotoAnalysisVariables) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Posing & Expression", icon: "figure.stand", color: .blue)
            
            VStack(spacing: 8) {
                scoreRow(title: "Pose Naturalness", score: analysis.poseNaturalness, total: 10)
                scoreRow(title: "Angle Flattery", score: analysis.angleFlatter, total: 10)
                infoRow(title: "Expression", value: analysis.facialExpression)
                infoRow(title: "Eye Contact", value: analysis.eyeContact)
            }
            .padding()
            .background(GlowPalette.softBeige)
            .cornerRadius(16)
        }
    }
    
    private func insightsSection(_ analysis: PhotoAnalysisVariables) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Strengths
            insightCard(
                title: "Your Strengths",
                icon: "star.fill",
                color: .green,
                items: analysis.strengthAreas
            )
            
            // Quick Wins
            insightCard(
                title: "Quick Wins",
                icon: "bolt.fill",
                color: .orange,
                items: analysis.quickWins
            )
            
            // Improvements
            insightCard(
                title: "Room to Grow",
                icon: "arrow.up.circle.fill",
                color: .blue,
                items: analysis.improvementAreas
            )
            
            // Long Term
            insightCard(
                title: "Long-Term Goals",
                icon: "target",
                color: .purple,
                items: analysis.longTermGoals
            )
        }
    }

    private var fallbackState: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(GlowPalette.roseGold)
            Text("We couldn't refresh your analysis because GPT-4 Vision wasn't reachable.")
                .font(.glowSubheading)
                .deepRoseText()
                .multilineTextAlignment(.center)
            Text("Drop your OpenAI key into Secrets.plist (OPENAI_API_KEY) or set it via environment variables, then re-run a photo to regenerate your personalized insights.")
                .font(.subheadline)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
    
    // MARK: - Components
    
    private func scoreCard(title: String, score: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(String(format: "%.1f", score))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.glowBody)
                .deepRoseText()
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(GlowPalette.creamyWhite.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * (score / 10))
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(GlowPalette.softBeige)
        .cornerRadius(16)
    }
    
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.glowHeading)
                .foregroundStyle(GlowPalette.roseGold)
            
            Text(title)
                .font(GlowTypography.glowSubheading)
                .foregroundStyle(GlowPalette.deepRose)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func scoreRow(title: String, score: Double, total: Double) -> some View {
        HStack {
            Text(title)
                .font(GlowTypography.glowBody)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.9))
            Spacer()
            Text(String(format: "%.1f/%g", score, total))
                .font(GlowTypography.glowBody)
                .foregroundStyle(GlowPalette.deepRose)
        }
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(GlowTypography.glowBody)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.9))
            Spacer()
            Text(value)
                .font(GlowTypography.glowBody)
                .foregroundStyle(GlowPalette.deepRose)
        }
    }
    
    private func seasonBadge(_ season: String) -> some View {
        HStack {
            Image(systemName: seasonIcon(season))
            Text("\(season) Season")
                .font(.glowSubheading)
        }
        .deepRoseText()
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(seasonColor(season))
        .cornerRadius(20)
    }
    
    private func colorList(title: String, colors: [String], positive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.glowSubheading.weight(.semibold))
                .deepRoseText()
            
            FlowLayout(spacing: 8) {
                ForEach(colors, id: \.self) { color in
                    Text(color)
                        .font(.glowBody)
                        .deepRoseText()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(positive ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private func insightCard(title: String, icon: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.glowSubheading)
                    .deepRoseText()
            }
            
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(color)
                    Text(item)
                        .font(.glowBody)
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.9))
                }
            }
        }
        .padding()
        .background(GlowPalette.softBeige)
        .cornerRadius(16)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.checkmark")
                .font(.system(size: 64))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.5))
            Text("No Analysis Yet")
                .font(.glowHeading)
                .deepRoseText()
            Text("Upload a photo to see your detailed analysis")
                .font(.glowBody)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private func scoreColor(for score: Double, total: Double) -> Color {
        let percentage = score / total
        if percentage >= 0.8 { return .green }
        if percentage >= 0.6 { return .yellow }
        return .orange
    }
    
    private func seasonIcon(_ season: String) -> String {
        switch season {
        case "Spring": return "leaf.fill"
        case "Summer": return "sun.max.fill"
        case "Autumn": return "leaf.fill"
        case "Winter": return "snowflake"
        default: return "sparkles"
        }
    }
    
    private func seasonColor(_ season: String) -> Color {
        switch season {
        case "Spring": return .green
        case "Summer": return .yellow
        case "Autumn": return .orange
        case "Winter": return .blue
        default: return .purple
        }
    }
}

// Simple flow layout for wrapping items
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize
        var frames: [CGRect]
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var frames: [CGRect] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.frames = frames
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    NavigationStack {
        DetailedAnalysisView()
    }
}
