//
//  PhotoAnalysisService.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import CoreData
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
        if let originalImage = UIImage(data: bundle.face) {
            if let faceResult = try? await faceOverlayService.analyzeAndAnnotateImage(originalImage) {
                annotatedImageData = faceResult.annotatedImage.jpegData(compressionQuality: 0.85)
                print("[PhotoAnalysisService] Face overlay created - Shape: \(faceResult.faceShape)")
            }
        }
        
        let input = PhotoAnalysisInput(
            persona: persona,
            bundle: bundle,
            quizResult: quiz
        )
        
        // Get detailed analysis from GPT-4 Vision
        let analysis = await openAIService.analyzePhoto(input)

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
