//
//  VisualizationModels.swift
//  glowup
//
//  Core data structures powering the Visualize feature.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum VisualizationPresetCategory: String, CaseIterable, Identifiable, Codable {
    case hairstyles
    case hairColors
    case makeup
    case clothing
    case accessories
    case finishingTouches

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hairstyles:
            return "Hairstyles"
        case .hairColors:
            return "Hair Colors"
        case .makeup:
            return "Makeup"
        case .clothing:
            return "Clothing"
        case .accessories:
            return "Accessories"
        case .finishingTouches:
            return "Finishing Touches"
        }
    }

    var systemImageName: String {
        switch self {
        case .hairstyles:
            return "scissors"
        case .hairColors:
            return "drop.fill"
        case .makeup:
            return "eyeshadow.palette"
        case .clothing:
            return "hanger"
        case .accessories:
            return "sparkles"
        case .finishingTouches:
            return "wand.and.stars"
        }
    }
}

enum VisualizationLookCategory: String, CaseIterable, Identifiable, Codable {
    case makeup
    case hair
    case outfit
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .makeup: return "Makeup"
        case .hair: return "Hair"
        case .outfit: return "Outfit"
        case .other: return "Other"
        }
    }

    var professionalTitle: String {
        switch self {
        case .makeup: return "makeup artist"
        case .hair: return "hairstylist"
        case .outfit: return "stylist"
        case .other: return "specialist"
        }
    }

    var presetCategory: VisualizationPresetCategory? {
        switch self {
        case .makeup: return .makeup
        case .hair: return .hairstyles
        case .outfit: return .clothing
        case .other: return nil
        }
    }
}

struct VisualizationPresetOption: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let subtitle: String
    let prompt: String
    let iconName: String?
    let swatchHex: String?
    let isPremium: Bool

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        prompt: String,
        iconName: String? = nil,
        swatchHex: String? = nil,
        isPremium: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.prompt = prompt
        self.iconName = iconName
        self.swatchHex = swatchHex
        self.isPremium = isPremium
    }
}

struct VisualizationPreset: Identifiable, Codable {
    let id: UUID
    let category: VisualizationPresetCategory
    let headline: String
    let description: String
    let options: [VisualizationPresetOption]
    let priority: Int
    let requiresAnalysis: Bool

    init(
        id: UUID = UUID(),
        category: VisualizationPresetCategory,
        headline: String,
        description: String,
        options: [VisualizationPresetOption],
        priority: Int = 0,
        requiresAnalysis: Bool = false
    ) {
        self.id = id
        self.category = category
        self.headline = headline
        self.description = description
        self.options = options
        self.priority = priority
        self.requiresAnalysis = requiresAnalysis
    }
}

struct VisualizationLaunchContext {
    #if canImport(UIKit)
    let baseImage: UIImage
    #endif
    let analysis: DetailedPhotoAnalysis?
    let photoSessionID: UUID?

    init(
        baseImage: UIImage,
        analysis: DetailedPhotoAnalysis? = nil,
        photoSessionID: UUID? = nil
    ) {
        self.baseImage = baseImage
        self.analysis = analysis
        self.photoSessionID = photoSessionID
    }
}
