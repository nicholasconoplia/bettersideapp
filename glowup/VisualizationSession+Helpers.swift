//
//  VisualizationSession+Helpers.swift
//  glowup
//
//  Core Data extensions for VisualizationSession and VisualizationEdit
//

import Foundation
import UIKit
import CoreData

extension VisualizationSession {
    var baseUIImage: UIImage? {
        guard let data = baseImage else { return nil }
        return UIImage(data: data)
    }
    
    var sortedEdits: [VisualizationEdit] {
        guard let edits = edits as? Set<VisualizationEdit> else { return [] }
        return edits.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
    }
    
    var latestEdit: VisualizationEdit? {
        sortedEdits.last
    }
}

extension VisualizationEdit {
    var resultUIImage: UIImage? {
        guard let data = resultImage else { return nil }
        return UIImage(data: data)
    }
}