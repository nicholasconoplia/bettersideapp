//
//  VisualizationNote+Helpers.swift
//  glowup
//
//  Convenience accessors for visualization notes.
//

import CoreData
import Foundation
#if canImport(UIKit)
import UIKit
#endif

extension VisualizationNote {
    #if canImport(UIKit)
    var renderedImage: UIImage? {
        guard let image else { return nil }
        return UIImage(data: image)
    }
    #endif

    var keywordList: [String] {
        keywords?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
    }

    var lookCategory: VisualizationLookCategory {
        if let raw = category, let resolved = VisualizationLookCategory(rawValue: raw) {
            return resolved
        }
        return .other
    }

    var professionalTitle: String {
        targetProfessional ?? lookCategory.professionalTitle
    }
}
