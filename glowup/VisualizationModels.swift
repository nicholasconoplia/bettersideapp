//
//  VisualizationModels.swift
//  glowup
//
//  Models for the visualization feature with Puter.js integration
//

import Foundation
import UIKit
import CoreData

// MARK: - Preset Categories

enum VisualizationPresetCategory: String, CaseIterable, Identifiable {
    case hairStyles = "hair_styles"
    case hairColors = "hair_colors"
    case makeup = "makeup"
    case clothing = "clothing"
    case accessories = "accessories"
    case styleVariations = "style_variations"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .hairStyles: return "Hair Styles"
        case .hairColors: return "Hair Colors"
        case .makeup: return "Makeup"
        case .clothing: return "Clothing"
        case .accessories: return "Accessories"
        case .styleVariations: return "Style Variations"
        }
    }
    
    var icon: String {
        switch self {
        case .hairStyles: return "scissors"
        case .hairColors: return "paintpalette.fill"
        case .makeup: return "wand.and.stars"
        case .clothing: return "tshirt.fill"
        case .accessories: return "eyeglasses"
        case .styleVariations: return "sparkles"
        }
    }

    var systemImageName: String {
        icon
    }
    
    var color: UIColor {
        switch self {
        case .hairStyles: return UIColor.systemBrown
        case .hairColors: return UIColor.systemPurple
        case .makeup: return UIColor.systemPink
        case .clothing: return UIColor.systemBlue
        case .accessories: return UIColor.systemOrange
        case .styleVariations: return UIColor.systemIndigo
        }
    }
}

// MARK: - Preset Options

struct VisualizationPresetOption: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let prompt: String
    let category: VisualizationPresetCategory
    let iconName: String?
    let swatchHex: String?
    let isPremium: Bool

    init(
        title: String,
        subtitle: String = "",
        prompt: String,
        category: VisualizationPresetCategory,
        iconName: String? = nil,
        swatchHex: String? = nil,
        isPremium: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.prompt = prompt
        self.category = category
        self.iconName = iconName
        self.swatchHex = swatchHex
        self.isPremium = isPremium
    }
}

// MARK: - Visualization Session State

@MainActor
class VisualizationSessionState: ObservableObject {
    @Published var currentImage: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var editHistory: [VisualizationEdit] = []
    @Published var availablePresets: [VisualizationPresetCategory: [VisualizationPresetOption]] = [:]
    
    private let puterService = PuterImageService()
    
    func generateImage(prompt: String, baseImage: UIImage? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let generatedImage = try await puterService.generateImageWithPuter(
                prompt: prompt,
                baseImage: baseImage
            )
            
            currentImage = generatedImage
            isLoading = false
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func applyPreset(_ preset: VisualizationPresetOption, baseImage: UIImage?) async {
        await generateImage(prompt: preset.prompt, baseImage: baseImage)
    }
    
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Puter Image Service Extension

extension PuterImageService {
    func generateImageWithPuter(prompt: String, baseImage: UIImage?) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            // Use the existing Puter.js implementation
            generateImage(prompt: prompt)
            
            // Wait for the result
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Check for result in the published properties
                if let image = self.generatedImage {
                    continuation.resume(returning: image)
                } else if let error = self.errorMessage {
                    continuation.resume(throwing: NSError(domain: "PuterService", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
                }
            }
        }
    }
}

// MARK: - Image Source Types

enum ImageSourceType {
    case camera
    case photoLibrary
    case analysisResult(PhotoSession)
    case existing(UIImage)
    
    var displayName: String {
        switch self {
        case .camera: return "Take Photo"
        case .photoLibrary: return "Choose from Library"
        case .analysisResult: return "Use from Analysis"
        case .existing: return "Current Image"
        }
    }
    
    var icon: String {
        switch self {
        case .camera: return "camera.fill"
        case .photoLibrary: return "photo.on.rectangle"
        case .analysisResult: return "sparkles"
        case .existing: return "photo.fill"
        }
    }
}

// MARK: - Visualization Session Manager

@MainActor
class VisualizationSessionManager: ObservableObject {
    @Published var sessions: [VisualizationSession] = []
    @Published var currentSession: VisualizationSession?
    
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        loadSessions()
    }
    
    func createSession(baseImage: UIImage, analysisReference: UUID? = nil) {
        let context = persistenceController.viewContext
        let session = VisualizationSession(context: context)
        session.id = UUID()
        session.createdAt = Date()
        session.baseImage = baseImage.jpegData(compressionQuality: 0.8)
        session.analysisReference = analysisReference
        
        do {
            try context.save()
            currentSession = session
            loadSessions()
        } catch {
            print("Failed to create visualization session: \(error)")
        }
    }
    
    func addEdit(to session: VisualizationSession, prompt: String, resultImage: UIImage, isPreset: Bool = false, presetCategory: String? = nil) {
        let context = persistenceController.viewContext
        let edit = VisualizationEdit(context: context)
        edit.id = UUID()
        edit.timestamp = Date()
        edit.prompt = prompt
        edit.resultImage = resultImage.jpegData(compressionQuality: 0.8)
        edit.isPreset = isPreset
        edit.presetCategory = presetCategory
        edit.session = session
        
        do {
            try context.save()
            loadSessions()
        } catch {
            print("Failed to add edit: \(error)")
        }
    }
    
    func deleteSession(_ session: VisualizationSession) {
        let context = persistenceController.viewContext
        context.delete(session)
        
        do {
            try context.save()
            loadSessions()
        } catch {
            print("Failed to delete session: \(error)")
        }
    }
    
    private func loadSessions() {
        let context = persistenceController.viewContext
        let request = NSFetchRequest<VisualizationSession>(entityName: "VisualizationSession")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            sessions = try context.fetch(request)
        } catch {
            print("Failed to load sessions: \(error)")
            sessions = []
        }
    }
}
