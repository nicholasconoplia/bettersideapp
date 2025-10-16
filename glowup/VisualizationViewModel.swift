//
//  VisualizationViewModel.swift
//  glowup
//
//  ViewModel for managing visualization state and navigation
//

import SwiftUI
import CoreData

@MainActor
class VisualizationViewModel: ObservableObject {
    @Published var pendingSession: PhotoSession?
    @Published var pendingImage: UIImage?
    @Published var pendingAnalysis: PhotoAnalysisVariables?
    
    func prepareLaunch(from session: PhotoSession) {
        pendingSession = session
        pendingImage = session.uploadedImage
        pendingAnalysis = session.decodedAnalysis?.variables
    }
    
    func clearPendingSession() {
        pendingSession = nil
        pendingImage = nil
        pendingAnalysis = nil
    }
}