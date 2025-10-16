//
//  VisualizationLookCategory.swift
//  glowup
//
//  Defines the categories a user can file a saved visualization under.
//

import Foundation

enum VisualizationLookCategory: String, CaseIterable, Identifiable {
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
        case .other: return "beauty specialist"
        }
    }
}
