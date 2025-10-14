//
//  PhotoSession+Analysis.swift
//  glowup
//
//  Created by Codex on 16/10/2025.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

extension PhotoSession {
    var decodedAnalysis: DetailedPhotoAnalysis? {
        guard let analysisData else { return nil }
        return try? JSONDecoder().decode(DetailedPhotoAnalysis.self, from: analysisData)
    }

    var uploadedImage: UIImage? {
        #if canImport(UIKit)
        guard let originalImage else { return nil }
        return UIImage(data: originalImage)
        #else
        return nil
        #endif
    }

    var recommendations: [String] {
        decodedAnalysis?.personalizedTips ?? []
    }
}
