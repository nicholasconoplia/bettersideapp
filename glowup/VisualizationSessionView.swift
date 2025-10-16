//
//  VisualizationSessionView.swift
//  glowup
//
//  Interactive visualization session with Puter.js integration
//

import SwiftUI
import CoreData

struct VisualizationSessionView: View {
    let session: VisualizationSession
    @StateObject private var sessionState = VisualizationSessionState()
    @StateObject private var puterService = PuterImageService()
    @State private var customPrompt = ""
    @State private var showingWebView = false
    @State private var selectedPreset: VisualizationPresetOption?
    @State private var showingImageSourcePicker = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // Get analysis reference if available
    private var analysisReference: PhotoAnalysisVariables? {
        guard let analysisRef = session.analysisReference,
              let photoSession = fetchPhotoSession(with: analysisRef) else {
            return nil
        }
        return photoSession.decodedAnalysis?.variables
    }
    
    var body: some View {
        ZStack {
            GradientBackground.primary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Main Image Display
                imageDisplaySection
                
                // Edit History
                if !sessionState.editHistory.isEmpty {
                    editHistorySection
                }
                
                // Presets Grid
                if let analysis = analysisReference {
                    presetsSection(analysis: analysis)
                }
                
                // Custom Prompt Input
                customPromptSection
                
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Change Image Source") {
                        showingImageSourcePicker = true
                    }
                    
                    Button("Open Web Interface") {
                        showingWebView = true
                    }
                    
                    if !sessionState.editHistory.isEmpty {
                        Button("Save to Photos", role: .destructive) {
                            saveCurrentImageToPhotos()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showingWebView) {
            PuterWebViewSheet(prompt: customPrompt)
        }
        .sheet(isPresented: $showingImageSourcePicker) {
            imageSourceSelectionSheet
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { image in
                updateSessionImage(image)
            }
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            ImagePicker { image in
                updateSessionImage(image)
            }
        }
        .onAppear {
            loadSessionData()
            if let analysis = analysisReference {
                sessionState.availablePresets = VisualizationPresetGenerator.generatePresets(from: analysis)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("Visualization Session")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Placeholder for symmetry
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            if let analysis = analysisReference {
                Text("Personalized for your \(analysis.seasonalPalette?.lowercased() ?? "natural") palette")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Image Display Section
    
    private var imageDisplaySection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 300)
                
                if sessionState.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Generating your visualization...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                } else if let image = sessionState.currentImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                } else if let baseImage = session.baseUIImage {
                    Image(uiImage: baseImage)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("No image available")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Error display
            if let error = sessionState.errorMessage {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Edit History Section
    
    private var editHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit History")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Original image
                    Button {
                        sessionState.currentImage = session.baseUIImage
                    } label: {
                        VStack(spacing: 8) {
                            Image(uiImage: session.baseUIImage ?? UIImage())
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                            
                            Text("Original")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    // Edit history
                    ForEach(sessionState.editHistory, id: \.objectID) { edit in
                        Button {
                            sessionState.currentImage = edit.resultUIImage
                        } label: {
                            VStack(spacing: 8) {
                                Image(uiImage: edit.resultUIImage ?? UIImage())
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                
                                Text((edit.timestamp ?? Date()).formatted(date: .omitted, time: .shortened))
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Presets Section
    
    private func presetsSection(analysis: PhotoAnalysisVariables) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Smart Presets")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(VisualizationPresetCategory.allCases, id: \.id) { category in
                        if let presets = sessionState.availablePresets[category], !presets.isEmpty {
                            presetCategoryCard(category: category, presets: presets)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func presetCategoryCard(category: VisualizationPresetCategory, presets: [VisualizationPresetOption]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(Color(category.color))
                
                Text(category.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(presets.prefix(3), id: \.id) { preset in
                    Button {
                        applyPreset(preset)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.title)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.white)
                                
                                Text(preset.subtitle)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    .disabled(sessionState.isLoading)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
        .frame(width: 200)
    }
    
    // MARK: - Custom Prompt Section
    
    private var customPromptSection: some View {
        VStack(spacing: 16) {
            TextField("Describe your desired changes...", text: $customPrompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                .padding(.horizontal, 20)
            
            HStack(spacing: 12) {
                Button {
                    generateCustomVisualization()
                } label: {
                    HStack {
                        if sessionState.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        
                        Text(sessionState.isLoading ? "Generating..." : "Generate")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.94, green: 0.34, blue: 0.56), Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(15)
                }
                .disabled(sessionState.isLoading || customPrompt.isEmpty)
                
                Button {
                    showingWebView = true
                } label: {
                    Image(systemName: "globe")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(15)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Image Source Selection Sheet
    
    private var imageSourceSelectionSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                
                Text("Change Image Source")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                VStack(spacing: 16) {
                    imageSourceButton(
                        title: "Take New Photo",
                        icon: "camera.fill",
                        color: .blue
                    ) {
                        showingCamera = true
                        showingImageSourcePicker = false
                    }
                    
                    imageSourceButton(
                        title: "Choose from Library",
                        icon: "photo.on.rectangle",
                        color: .green
                    ) {
                        showingPhotoLibrary = true
                        showingImageSourcePicker = false
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .background(GradientBackground.primary.ignoresSafeArea())
            .navigationTitle("Image Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingImageSourcePicker = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func imageSourceButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(color.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Methods
    
    private func loadSessionData() {
        sessionState.editHistory = session.sortedEdits
        sessionState.currentImage = session.latestEdit?.resultUIImage ?? session.baseUIImage
    }
    
    private func applyPreset(_ preset: VisualizationPresetOption) {
        Task {
            await sessionState.applyPreset(preset, baseImage: session.baseUIImage)
            
            if let resultImage = sessionState.currentImage {
                // Save the edit to Core Data
                let context = viewContext
                let edit = VisualizationEdit(context: context)
                edit.id = UUID()
                edit.timestamp = Date()
                edit.prompt = preset.prompt
                edit.resultImage = resultImage.jpegData(compressionQuality: 0.8)
                edit.isPreset = true
                edit.presetCategory = preset.category.rawValue
                edit.session = session
                
                do {
                    try context.save()
                    loadSessionData() // Reload to include new edit
                } catch {
                    print("Failed to save preset edit: \(error)")
                }
            }
        }
    }
    
    private func generateCustomVisualization() {
        Task {
            await sessionState.generateImage(
                prompt: customPrompt,
                baseImage: session.baseUIImage
            )
            
            if let resultImage = sessionState.currentImage {
                // Save the edit to Core Data
                let context = viewContext
                let edit = VisualizationEdit(context: context)
                edit.id = UUID()
                edit.timestamp = Date()
                edit.prompt = customPrompt
                edit.resultImage = resultImage.jpegData(compressionQuality: 0.8)
                edit.isPreset = false
                edit.session = session
                
                do {
                    try context.save()
                    loadSessionData() // Reload to include new edit
                    customPrompt = "" // Clear the prompt
                } catch {
                    print("Failed to save custom edit: \(error)")
                }
            }
        }
    }
    
    private func updateSessionImage(_ image: UIImage) {
        // Update the session's base image
        session.baseImage = image.jpegData(compressionQuality: 0.8)
        
        do {
            try viewContext.save()
            sessionState.currentImage = image
            sessionState.editHistory = [] // Clear edit history
        } catch {
            print("Failed to update session image: \(error)")
        }
    }
    
    private func saveCurrentImageToPhotos() {
        guard let image = sessionState.currentImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    
    private func fetchPhotoSession(with id: UUID) -> PhotoSession? {
        let request = NSFetchRequest<PhotoSession>(entityName: "PhotoSession")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        return try? viewContext.fetch(request).first
    }
}

#Preview {
    let context = PersistenceController.shared.viewContext
    let session = VisualizationSession(context: context)
    session.id = UUID()
    session.createdAt = Date()
    
    return NavigationStack {
        VisualizationSessionView(session: session)
    }
}