//
//  PhotoAnalysisService.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import CoreData
import CoreImage
import Foundation
import UIKit

struct AnalysisPipelineResult {
    let session: PhotoSession
    let analysis: DetailedPhotoAnalysis
}

@MainActor
final class PhotoAnalysisService {
    private let persistenceController: PersistenceController
    private let openAIService: OpenAIService
    private let faceOverlayService = FaceOverlayService()
    private let analysisCalibrator = AnalysisCalibrator()

    init(
        persistenceController: PersistenceController,
        openAIService: OpenAIService = .shared
    ) {
        self.persistenceController = persistenceController
        self.openAIService = openAIService
    }

    func analyzePhoto(
        bundle: PhotoAnalysisBundle,
        persona: CoachPersona,
        quiz: QuizResult?
    ) async -> AnalysisPipelineResult {
        let context = persistenceController.viewContext
        
        // Create annotated image with face overlay
        var annotatedImageData: Data?
        var overlayResult: FaceOverlayService.FaceAnalysisResult?
        var baseFaceImage: UIImage?
        if let originalImage = UIImage(data: bundle.face) {
            baseFaceImage = originalImage
            if let faceResult = try? await faceOverlayService.analyzeAndAnnotateImage(originalImage) {
                overlayResult = faceResult
                annotatedImageData = faceResult.annotatedImage.jpegData(compressionQuality: 0.85)
                let confidence = Int((faceResult.classification.confidence * 100).rounded())
                print("[PhotoAnalysisService] Face overlay created - Shape: \(faceResult.faceShape) (\(confidence)% match)")
            }
        }
        
        let input = PhotoAnalysisInput(
            persona: persona,
            bundle: bundle,
            quizResult: quiz
        )
        
        // Get detailed analysis from GPT-4 Vision
        var analysis = await openAIService.analyzePhoto(input)
        if !analysis.isFallback {
            analysis = analysisCalibrator.calibrate(
                analysis: analysis,
                overlay: overlayResult,
                originalImage: baseFaceImage
            )
            print("[PhotoAnalysisService] Calibrated lighting quality:", String(format: "%.2f", analysis.variables.lightingQuality))
            print("[PhotoAnalysisService] Calibrated angle score:", String(format: "%.2f", analysis.variables.angleFlatter))
            print("[PhotoAnalysisService] Calibrated facial angularity:", String(format: "%.2f", analysis.variables.facialAngularityScore))
            if let shape = analysis.variables.faceShape {
                print("[PhotoAnalysisService] Final face shape classification:", shape)
            }
        }

        // Create photo session
        let session = PhotoSession(context: context)
        session.id = UUID()
        session.startTime = Date()
        session.sessionType = "Static Photo"
        session.originalImage = bundle.face
        if analysis.isFallback {
            session.confidenceScore = 0
        } else {
            session.confidenceScore = analysis.variables.overallGlowScore / 10.0  // Convert to 0-1 scale
        }
        session.aiSummary = analysis.summary
        if let encodedAnalysis = try? JSONEncoder().encode(analysis) {
            session.analysisData = encodedAnalysis
        } else {
            print("[PhotoAnalysisService] Failed to encode analysis for session \(session.id?.uuidString ?? "unknown")")
        }

        // Update profile with detailed analysis
        if !analysis.isFallback {
            updateGlowProfile(with: analysis, in: context)
        } else {
            print("[PhotoAnalysisService] Skipping profile update due to fallback analysis.")
        }
        
        // Store annotated image
        if let annotatedImageData = annotatedImageData {
            UserDefaults.standard.set(annotatedImageData, forKey: "LatestAnnotatedImage")
        }

        if analysis.isFallback {
            context.delete(session)
        } else {
            persistenceController.saveIfNeeded(context)
        }
        return AnalysisPipelineResult(session: session, analysis: analysis)
    }

    private func updateGlowProfile(
        with analysis: DetailedPhotoAnalysis,
        in context: NSManagedObjectContext
    ) {
        let profile = fetchExistingProfile(in: context) ?? GlowProfile(context: context)
        let vars = analysis.variables
        
        // Physical features
        profile.faceShape = vars.faceShape
        profile.skinUndertone = vars.skinUndertone
        profile.eyeColor = vars.eyeColor
        profile.hairColor = vars.hairColor
        
        // Color analysis
        profile.colorPalette = vars.seasonalPalette
        profile.bestColors = vars.bestColors.joined(separator: ", ")
        profile.avoidColors = vars.avoidColors.joined(separator: ", ")
        
        // Technical aspects
        profile.optimalLightingDesc = "\(vars.lightingType) light from \(vars.lightingDirection.lowercased()) direction (Quality: \(Int(vars.lightingQuality))/10)"
        profile.bestAngleTilt = vars.angleFlatter
        
        // Style & presentation
        profile.makeupStyle = vars.makeupStyle
        profile.theme = generateTheme(from: vars)
        
        // Store detailed scores as JSON (if you add a flexible field to Core Data)
        // Or store them in UserDefaults for detailed view
        storeDetailedAnalysis(analysis)
        
        print("[PhotoAnalysisService] Updated profile:")
        print("  Face Shape: \(vars.faceShape ?? "Not detected")")
        print("  Seasonal Palette: \(vars.seasonalPalette ?? "Not detected")")
        print("  Best Colors: \(vars.bestColors.isEmpty ? "None" : vars.bestColors.joined(separator: ", "))")
        print("  Glow Score: \(vars.overallGlowScore)/10")
    }
    
    private func generateTheme(from vars: PhotoAnalysisVariables) -> String {
        // Generate theme based on seasonal palette and style
        guard let palette = vars.seasonalPalette else {
            return "Natural Glow"
        }
        
        switch palette {
        case "Spring":
            return "Fresh & Radiant"
        case "Summer":
            return "Soft & Elegant"
        case "Autumn":
            return "Warm & Rich"
        case "Winter":
            return "Bold & Striking"
        default:
            return "Natural Glow"
        }
    }
    
    private func storeDetailedAnalysis(_ analysis: DetailedPhotoAnalysis) {
        let vars = analysis.variables
        let defaults = UserDefaults.standard
        
        if analysis.isFallback {
            defaults.removeObject(forKey: "LatestDetailedAnalysis")
            defaults.set(true, forKey: "LatestAnalysisIsFallback")
            defaults.removeObject(forKey: "LatestRecommendationPlan")
        } else {
            if let encoded = try? JSONEncoder().encode(vars) {
                defaults.set(encoded, forKey: "LatestDetailedAnalysis")
            }
            defaults.set(false, forKey: "LatestAnalysisIsFallback")
            
            let plan = PersonalizedRecommendationBuilder(analysis: analysis).buildPlan()
            if let encodedPlan = try? JSONEncoder().encode(plan) {
                defaults.set(encodedPlan, forKey: "LatestRecommendationPlan")
            }
        }
        UserDefaults.standard.set(analysis.summary, forKey: "LatestAnalysisSummary")
        UserDefaults.standard.set(analysis.personalizedTips, forKey: "LatestPersonalizedTips")
    }

    private func fetchExistingProfile(in context: NSManagedObjectContext) -> GlowProfile? {
        let request = NSFetchRequest<GlowProfile>(entityName: "GlowProfile")
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}

// MARK: - Analysis Calibration Helpers

private struct LightingAssessment {
    let qualityScore: Double
    let averageLuminance: Double
    let evennessScore: Double
    let contrastScore: Double
    let highlightClipping: Bool
}

private struct LightingAnalyzer {
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    
    func assess(image: UIImage, faceBounds: CGRect?) -> LightingAssessment? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let extent = ciImage.extent
        
        let analysisRect: CGRect = {
            guard let faceBounds else { return extent }
            let rect = CGRect(
                x: faceBounds.origin.x * extent.width,
                y: faceBounds.origin.y * extent.height,
                width: faceBounds.width * extent.width,
                height: faceBounds.height * extent.height
            )
            let expansionX = rect.width * 0.25
            let expansionY = rect.height * 0.25
            let expanded = rect.insetBy(dx: -expansionX, dy: -expansionY)
            let clamped = expanded.intersection(extent)
            return clamped.isNull ? extent : clamped
        }()
        
        guard analysisRect.width >= 4, analysisRect.height >= 4 else {
            return nil
        }
        
        guard let average = sampleLuminance(in: ciImage, rect: analysisRect) else {
            return nil
        }
        
        let halfWidth = analysisRect.width / 2
        let halfHeight = analysisRect.height / 2
        let leftRect = CGRect(x: analysisRect.minX, y: analysisRect.minY, width: halfWidth, height: analysisRect.height)
        let rightRect = CGRect(x: analysisRect.midX, y: analysisRect.minY, width: halfWidth, height: analysisRect.height)
        let topRect = CGRect(x: analysisRect.minX, y: analysisRect.midY, width: analysisRect.width, height: halfHeight)
        let bottomRect = CGRect(x: analysisRect.minX, y: analysisRect.minY, width: analysisRect.width, height: halfHeight)
        let centerRect = analysisRect.insetBy(dx: analysisRect.width * 0.2, dy: analysisRect.height * 0.2)
        
        guard
            let left = sampleLuminance(in: ciImage, rect: leftRect),
            let right = sampleLuminance(in: ciImage, rect: rightRect),
            let top = sampleLuminance(in: ciImage, rect: topRect),
            let bottom = sampleLuminance(in: ciImage, rect: bottomRect),
            let center = sampleLuminance(in: ciImage, rect: centerRect)
        else {
            return nil
        }
        
        let samples = [average, left, right, top, bottom, center]
        let sampleMean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.reduce(0) { partial, value in
            let diff = value - sampleMean
            return partial + diff * diff
        } / Double(samples.count)
        let stdDev = sqrt(max(variance, 0))
        
        let lrDiff = abs(left - right)
        let tbDiff = abs(top - bottom)
        
        let evennessScore = max(0, 1 - min(1, (lrDiff + tbDiff) / 0.9))
        let brightnessScore = max(0, 1 - min(1, abs(average - 0.55) / 0.35))
        let contrastNormalized = min(1, stdDev / 0.18)
        
        let highlightThreshold = samples.max() ?? average
        let highlightClipping = highlightThreshold > 0.9 && average < 0.85
        
        var quality = 4.2
        quality += brightnessScore * 3.3
        quality += evennessScore * 2.3
        quality += contrastNormalized * 2.2
        if highlightClipping {
            quality -= 0.6
        }
        if average < 0.28 {
            quality -= 0.8
        }
        
        return LightingAssessment(
            qualityScore: min(10, max(0, quality)),
            averageLuminance: average,
            evennessScore: evennessScore,
            contrastScore: contrastNormalized,
            highlightClipping: highlightClipping
        )
    }
    
    private func sampleLuminance(in image: CIImage, rect: CGRect) -> Double? {
        guard let filter = CIFilter(name: "CIAreaAverage") else { return nil }
        filter.setValue(image.cropped(to: rect), forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: rect), forKey: kCIInputExtentKey)
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        
        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0
        
        return (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
    }
}

private struct AnalysisCalibrator {
    private let lightingAnalyzer = LightingAnalyzer()
    
    func calibrate(
        analysis: DetailedPhotoAnalysis,
        overlay: FaceOverlayService.FaceAnalysisResult?,
        originalImage: UIImage?
    ) -> DetailedPhotoAnalysis {
        guard !analysis.isFallback else { return analysis }
        var variables = analysis.variables
        let originalLighting = variables.lightingQuality
        let originalAngle = variables.angleFlatter
        let originalAngularity = variables.facialAngularityScore
        
        let lighting = originalImage.map { lightingAnalyzer.assess(image: $0, faceBounds: overlay?.faceBounds) } ?? nil
        
        if let classification = overlay?.classification {
            if variables.faceShape == nil || shouldReplaceFaceShape(current: variables.faceShape, with: classification) {
                variables.faceShape = classification.label
            }
            
            let overlayAngularity = angularityScore(from: classification.metrics)
            let blendedAngularity = blend(
                base: variables.facialAngularityScore,
                measurement: overlayAngularity,
                weight: 0.6
            )
            if blendedAngularity > variables.facialAngularityScore {
                variables.facialAngularityScore = min(10, blendedAngularity)
            }
            
            if variables.facialAngularityScore >= 7.2 {
                variables.faceFullnessDescriptor = "Defined"
            } else if variables.facialAngularityScore <= 4.2 {
                variables.faceFullnessDescriptor = "Soft"
            }
        }
        
        if let orientation = overlay?.orientation {
            let symmetryBoost = max(0, (orientation.symmetryScore - 0.68) * 6.0)
            if symmetryBoost > 0 {
                variables.angleFlatter = min(10, max(variables.angleFlatter, variables.angleFlatter + symmetryBoost))
                variables.poseNaturalness = min(10, max(variables.poseNaturalness, variables.poseNaturalness + symmetryBoost * 0.55))
            }
        }
        
        if let lighting {
            var recalibrated = blend(
                base: variables.lightingQuality,
                measurement: lighting.qualityScore,
                weight: 0.55
            )
            if variables.exposure.lowercased() == "perfect" {
                recalibrated += 0.45
            }
            if variables.lightingDirection.lowercased().contains("front") {
                recalibrated += lighting.evennessScore * 0.9
            }
            if let orientation = overlay?.orientation, orientation.symmetryScore > 0.78 {
                recalibrated += 0.3
            }
            recalibrated = min(10, max(recalibrated, lighting.qualityScore))
            variables.lightingQuality = recalibrated
            
            if variables.lightingType.lowercased() == "artificial", lighting.qualityScore >= 7.2 {
                variables.lightingType = "Studio Soft Light"
            }
            
            if lighting.evennessScore > 0.78 && !variables.lightingFeedback.lowercased().contains("even") {
                variables.lightingFeedback = "Lighting is evenly balanced with minimal shadow falloff.\n" + variables.lightingFeedback
            }
        }
        
        let lightingDelta = variables.lightingQuality - originalLighting
        let angleDelta = variables.angleFlatter - originalAngle
        let angularityDelta = variables.facialAngularityScore - originalAngularity
        let compositeDelta = max(0, (lightingDelta * 0.18) + (angleDelta * 0.15) + (angularityDelta * 0.12))
        if compositeDelta > 0 {
            variables.overallGlowScore = min(10, variables.overallGlowScore + compositeDelta)
        }
        if lightingDelta > 0.6 {
            variables.confidenceScore = min(10, variables.confidenceScore + lightingDelta * 0.12)
        }
        
        variables.bestColors = normalizedRecommendedColors(
            from: variables.bestColors,
            season: variables.seasonalPalette
        )
        variables.avoidColors = normalizedAvoidColors(
            from: variables.avoidColors,
            season: variables.seasonalPalette
        )
        variables.roadmap = expandRoadmap(for: variables, original: analysis.variables.roadmap)
        
        return DetailedPhotoAnalysis(
            variables: variables,
            summary: analysis.summary,
            personalizedTips: analysis.personalizedTips,
            isFallback: analysis.isFallback
        )
    }
    
    private func shouldReplaceFaceShape(
        current: String?,
        with classification: FaceOverlayService.FaceShapeClassification
    ) -> Bool {
        guard let current else { return true }
        if classification.confidence < 0.52 { return false }
        return current.caseInsensitiveCompare(classification.label) != .orderedSame
    }
    
    private func angularityScore(from metrics: FaceOverlayService.FaceProportionMetrics) -> Double {
        let jawComponent = clamp((metrics.jawAngle - 32.0) / 18.0, 0, 1)
        let cheekComponent = clamp((metrics.cheekboneWidth - metrics.jawWidth) / 0.12, 0, 1)
        let combined = max(0.1, min(1, (jawComponent * 0.65) + (cheekComponent * 0.35)))
        return max(2.5, min(9.8, combined * 10))
    }
    
    private func blend(base: Double, measurement: Double, weight: Double) -> Double {
        let clampedWeight = clamp(weight, 0, 1)
        return (base * (1 - clampedWeight)) + (measurement * clampedWeight)
    }
    
    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
    
    private func normalizedRecommendedColors(from colors: [String], season: String?) -> [String] {
        let sanitized = sanitize(colors)
        let filtered = sanitized.filter { color in
            let lower = color.lowercased()
            if lower.contains("coral") || lower.contains("peach") {
                guard let season else { return true }
                let allowedWarm: Set<String> = ["spring", "true spring", "warm spring", "autumn", "true autumn", "deep autumn", "warm autumn"]
                return allowedWarm.contains(season.lowercased())
            }
            return true
        }
        let deduped = deduplicate(filtered)
        if !deduped.isEmpty {
            return Array(deduped.prefix(10))
        }
        guard let season else { return sanitized }
        return fallbackPalette(for: season)
    }
    
    private func normalizedAvoidColors(from colors: [String], season: String?) -> [String] {
        let sanitized = sanitize(colors)
        let filtered = sanitized.filter { color in
            let lower = color.lowercased()
            if lower.contains("black") || lower.contains("white") {
                return false
            }
            return true
        }
        let deduped = deduplicate(filtered)
        if !deduped.isEmpty {
            return Array(deduped.prefix(8))
        }
        guard let season else { return sanitized }
        return fallbackAvoid(for: season)
    }
    
    private func sanitize(_ colors: [String]) -> [String] {
        colors
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func deduplicate(_ colors: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for color in colors {
            let key = color.lowercased()
            if seen.insert(key).inserted {
                ordered.append(color)
            }
        }
        return ordered
    }
    
    private func fallbackPalette(for season: String) -> [String] {
        switch season.lowercased() {
        case "spring", "true spring", "warm spring":
            return ["Golden Apricot", "Sunrise Coral", "Mint Mojito", "Seafoam Teal", "Buttercream Beige"]
        case "summer", "true summer", "cool summer":
            return ["Mauve Mist", "Soft Rose", "Powder Blue", "Silver Birch", "Dusty Periwinkle"]
        case "autumn", "true autumn", "deep autumn":
            return ["Spiced Pumpkin", "Olive Grove", "Copper Maple", "Honey Mustard", "Teal Lagoon"]
        case "winter", "true winter", "cool winter":
            return ["Royal Sapphire", "Electric Fuchsia", "Deep Emerald", "Velvet Plum", "Frosted Lilac"]
        default:
            return ["Soft Rose", "Warm Sand", "Sky Blue"]
        }
    }
    
    private func fallbackAvoid(for season: String) -> [String] {
        switch season.lowercased() {
        case "spring", "true spring", "warm spring":
            return ["Dusty Olive", "Cool Charcoal", "Muted Mauve"]
        case "summer", "true summer", "cool summer":
            return ["Neon Orange", "Harsh Mustard", "Burnt Copper"]
        case "autumn", "true autumn", "deep autumn":
            return ["Icy Lavender", "Frost White", "Bubblegum Pink"]
        case "winter", "true winter", "cool winter":
            return ["Muddy Brown", "Muted Olive", "Goldenrod"]
        default:
            return ["Neon Yellow", "Harsh Lime", "Faded Beige"]
        }
    }
    
    private func expandRoadmap(for variables: PhotoAnalysisVariables, original: [ImprovementRoadmapStep]) -> [ImprovementRoadmapStep] {
        var buckets: [String: RoadmapBucket] = [:]
        
        for step in original where !step.actions.isEmpty {
            let timeframe = normalizedTimeframe(step.timeframe)
            let trimmedActions = sanitize(step.actions)
            guard !trimmedActions.isEmpty else { continue }
            var bucket = buckets[timeframe] ?? RoadmapBucket(id: step.id, focus: step.focus, actions: [])
            if bucket.focus.count < step.focus.count {
                bucket.focus = step.focus
            }
            for action in trimmedActions where !bucket.actions.contains(where: { $0.caseInsensitiveCompare(action) == .orderedSame }) {
                bucket.actions.append(action)
            }
            buckets[timeframe] = bucket
        }
        
        if variables.lightingQuality < 7.5 {
            appendAction(
                to: &buckets,
                timeframe: "This Week",
                focus: "Angles & Lighting Reset",
                action: "Compare your current setup against daylight: take 5 fast shots rotating 30° around your key light and lock the angle that smooths your skin tone the most."
            )
            appendAction(
                to: &buckets,
                timeframe: "Next 30 Days",
                focus: "Angles & Lighting Reset",
                action: "Document three go-to lighting recipes (window, bounce, evening) with diagrams and camera placement so recreating flattering light becomes automatic."
            )
        }
        
        if variables.angleFlatter < 7.0 || variables.poseNaturalness < 7.0 {
            appendAction(
                to: &buckets,
                timeframe: "This Week",
                focus: "Pose Mastery Sprint",
                action: "Record a 60-second video rotating your head in 15° increments—freeze the frame that defines your jawline best and screenshot it for reference."
            )
            appendAction(
                to: &buckets,
                timeframe: "Next 30 Days",
                focus: "Pose Mastery Sprint",
                action: "Build a pose deck of 6 looks (chin tuck, chin forward, over-shoulder, candid laugh, power stance, seated lean) and rehearse them weekly until they feel automatic."
            )
        }
        
        if variables.skinTextureScore < 7.0 {
            appendAction(
                to: &buckets,
                timeframe: "This Week",
                focus: "Skin Texture Strategy",
                action: "Run a prep drill before your next shoot: mist, press a silicone-free blurring primer, and spot-correct with a damp sponge—note how each step shifts texture on camera."
            )
            appendAction(
                to: &buckets,
                timeframe: "60 Days",
                focus: "Skin Texture Strategy",
                action: "Schedule a 6-week barrier routine (gentle exfoliation, peptide serum, hydrating mask). Track results with bi-weekly selfies under the same lighting."
            )
        }
        
        if variables.colorHarmony < 7.0 || variables.seasonalPalette == nil {
            appendAction(
                to: &buckets,
                timeframe: "This Week",
                focus: "Palette Alignment",
                action: "Lay out three outfits in your Glow Colors and snap them beside any off-palette pieces—keep what photographs vibrant and tag what needs replacing."
            )
            appendAction(
                to: &buckets,
                timeframe: "90 Days",
                focus: "Palette Alignment",
                action: "Plan a seasonal capsule refresh: list 5 hero pieces, 3 layering items, and 2 accessories in your palette to make future shoots plug-and-play."
            )
        }
        
        if variables.confidenceScore < 7.0 {
            appendAction(
                to: &buckets,
                timeframe: "60 Days",
                focus: "Confidence Calibration",
                action: "Set a weekly 'confidence rep': capture a quick talking video after your photo session summarizing what felt powerful and what needs coaching."
            )
        }
        
        if variables.backgroundSuitability < 7.0 {
            appendAction(
                to: &buckets,
                timeframe: "This Week",
                focus: "Backdrop Control",
                action: "Audit your shooting space: clear two clean background zones and keep a neutral throw/blanket ready to smooth distractions in seconds."
            )
        }
        
        let prioritizedOrder = ["This Week", "Next 30 Days", "60 Days", "90 Days"]
        return prioritizedOrder.compactMap { key in
            guard var bucket = buckets[key] else { return nil }
            bucket.actions = deduplicate(bucket.actions)
            guard !bucket.actions.isEmpty else { return nil }
            let focus = bucket.focus.isEmpty ? defaultFocus(for: key) : bucket.focus
            return ImprovementRoadmapStep(
                id: bucket.id ?? UUID().uuidString,
                timeframe: key,
                focus: focus,
                actions: bucket.actions
            )
        }
    }
    
    private func appendAction(
        to buckets: inout [String: RoadmapBucket],
        timeframe: String,
        focus: String,
        action: String
    ) {
        var bucket = buckets[timeframe] ?? RoadmapBucket(id: nil, focus: focus, actions: [])
        if bucket.focus.count < focus.count {
            bucket.focus = focus
        }
        if !bucket.actions.contains(where: { $0.caseInsensitiveCompare(action) == .orderedSame }) {
            bucket.actions.append(action)
        }
        buckets[timeframe] = bucket
    }
    
    private func normalizedTimeframe(_ timeframe: String) -> String {
        let lowered = timeframe.lowercased()
        if lowered.contains("week") {
            return "This Week"
        }
        if lowered.contains("30") || lowered.contains("month") {
            return "Next 30 Days"
        }
        if lowered.contains("60") || lowered.contains("two") {
            return "60 Days"
        }
        if lowered.contains("90") || lowered.contains("quarter") {
            return "90 Days"
        }
        return timeframe.isEmpty ? "Next 30 Days" : timeframe
    }
    
    private func defaultFocus(for timeframe: String) -> String {
        switch timeframe {
        case "This Week":
            return "Quick Wins"
        case "Next 30 Days":
            return "Systems & Practice"
        case "60 Days":
            return "Deeper Refinements"
        case "90 Days":
            return "Long-Term Upgrades"
        default:
            return "Glow Strategy"
        }
    }
}

private struct RoadmapBucket {
    var id: String?
    var focus: String
    var actions: [String]
}
