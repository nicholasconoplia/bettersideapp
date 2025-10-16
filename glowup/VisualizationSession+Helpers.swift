//
//  VisualizationSession+Helpers.swift
//  glowup
//
//  Convenience helpers for working with visualization sessions and edits.
//

import CoreData
import Foundation
#if canImport(UIKit)
import UIKit
#endif

extension VisualizationSession {
    var sortedEdits: [VisualizationEdit] {
        let editsSet = edits as? Set<VisualizationEdit> ?? []
        return editsSet.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
    }

    #if canImport(UIKit)
    var baseUIImage: UIImage? {
        guard let baseImage else { return nil }
        return UIImage(data: baseImage)
    }

    var latestUIImage: UIImage? {
        sortedEdits.last?.resultUIImage ?? baseUIImage
    }
    #endif
}

extension VisualizationEdit {
    #if canImport(UIKit)
    var resultUIImage: UIImage? {
        guard let resultImage else { return nil }
        return UIImage(data: resultImage)
    }
    #endif

    var presetCategoryEnum: VisualizationPresetCategory? {
        guard let presetCategory else { return nil }
        return VisualizationPresetCategory(rawValue: presetCategory)
    }
}
