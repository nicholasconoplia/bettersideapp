// Placeholder to ensure StudioContainerView compiles if needed
//
//  VisualizationViewModel.swift
//  glowup
//
//  Central coordinator for the Visualize feature.
//

import CoreData
import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class VisualizationViewModel: ObservableObject {
    @Published private(set) var sessions: [VisualizationSession] = []
    @Published var activeSession: VisualizationSession?
    @Published var activeImage: UIImage?
    @Published private(set) var activePresets: [VisualizationPreset] = []
    @Published private(set) var savedNotes: [VisualizationNote] = []
    @Published var lastSavedNote: VisualizationNote?
    @Published var isProcessing = false
    @Published var activityMessage: String?
    @Published var errorMessage: String?
    @Published var isPresentingImagePicker = false
    @Published var customPrompt: String = ""
    @Published var isShowingPromptSheet = false

    // Inspiration inputs
    @Published var inspirationReferences: [InspirationReference] = []
    @Published var showInspirationPicker = false
    @Published var selectedInspirationCategory: InspirationCategory = .general

    private let persistenceController: PersistenceController
    private let geminiService: GeminiService
    private let openAIService: OpenAIService
    private var analysisCache: [UUID: DetailedPhotoAnalysis] = [:]
    private var lastAppliedOptions: [VisualizationPresetCategory: VisualizationPresetOption] = [:]

    init(
        persistenceController: PersistenceController = .shared,
        geminiService: GeminiService = .shared,
        openAIService: OpenAIService = .shared
    ) {
        self.persistenceController = persistenceController
        self.geminiService = geminiService
        self.openAIService = openAIService
        loadSessions()
        loadNotes()
    }

    // MARK: - Session Management

    func loadSessions() {
        let request = NSFetchRequest<VisualizationSession>(entityName: "VisualizationSession")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        do {
            sessions = try persistenceController.viewContext.fetch(request)
        } catch {
            sessions = []
            print("[VisualizationViewModel] Failed to load sessions: \(error.localizedDescription)")
        }

        if let active = activeSession,
           let refreshed = sessions.first(where: { $0.objectID == active.objectID }) {
            setActiveSession(refreshed)
        }
    }

    func loadNotes() {
        let request = NSFetchRequest<VisualizationNote>(entityName: "VisualizationNote")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        do {
            savedNotes = try persistenceController.viewContext.fetch(request)
        } catch {
            savedNotes = []
            print("[VisualizationViewModel] Failed to load notes: \(error.localizedDescription)")
        }
    }

    func startSession(with launchContext: VisualizationLaunchContext) {
        #if canImport(UIKit)
        guard let baseData = launchContext.baseImage
            .resized(maxDimension: 1400)?
            .jpegData(compressionQuality: 0.92) ?? launchContext.baseImage.jpegData(compressionQuality: 0.92) else {
            errorMessage = "Could not prepare the image for visualization."
            return
        }

        let context = persistenceController.viewContext
        let session = VisualizationSession(context: context)
        session.id = UUID()
        session.createdAt = Date()
        session.baseImage = baseData
        session.analysisReference = launchContext.photoSessionID

        persistenceController.saveIfNeeded(context)
        loadSessions()

        if let saved = sessions.first(where: { $0.id == session.id }) {
            setActiveSession(saved)
        } else {
            setActiveSession(session)
        }

        activeImage = launchContext.baseImage
        if let analysis = launchContext.analysis, let sessionID = activeSession?.id {
            analysisCache[sessionID] = analysis
            refreshPresets()
        }
        #endif
    }

    func select(session: VisualizationSession) {
        setActiveSession(session)
    }

    func startFromLatestAnalysis() {
        let request = NSFetchRequest<PhotoSession>(entityName: "PhotoSession")
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        request.fetchLimit = 1
        guard let latest = try? persistenceController.viewContext.fetch(request).first else {
            errorMessage = "No completed analyses available yet."
            return
        }
        prepareLaunch(from: latest)
    }

    func startSession(from image: UIImage, analysis: DetailedPhotoAnalysis? = nil, sourceID: UUID? = nil) {
        let context = VisualizationLaunchContext(
            baseImage: image,
            analysis: analysis,
            photoSessionID: sourceID
        )
        startSession(with: context)
    }

    func delete(session: VisualizationSession) {
        let context = persistenceController.viewContext
        context.delete(session)
        persistenceController.saveIfNeeded(context)
        if activeSession?.objectID == session.objectID {
            activeSession = nil
            activeImage = nil
            activePresets = []
        }
        loadSessions()
        loadNotes()
    }

    func resetActiveSession() {
        guard let session = activeSession else { return }
        activeImage = session.baseUIImage
    }

    func latestEdits() -> [VisualizationEdit] {
        activeSession?.sortedEdits ?? []
    }

    func analysisForActiveSession() -> DetailedPhotoAnalysis? {
        guard let session = activeSession,
              let sessionID = session.id else {
            return nil
        }

        if let cached = analysisCache[sessionID] {
            return cached
        }

        guard let reference = session.analysisReference else {
            return nil
        }

        let request = NSFetchRequest<PhotoSession>(entityName: "PhotoSession")
        request.predicate = NSPredicate(format: "id == %@", reference as CVarArg)
        request.fetchLimit = 1
        if let matched = try? persistenceController.viewContext.fetch(request).first,
           let analysis = matched.decodedAnalysis {
            analysisCache[sessionID] = analysis
            return analysis
        }
        return nil
    }

    func prepareLaunch(from photoSession: PhotoSession) {
        #if canImport(UIKit)
        guard let image = photoSession.uploadedImage else {
            errorMessage = "This session is missing its original photo."
            return
        }
        let context = VisualizationLaunchContext(
            baseImage: image,
            analysis: photoSession.decodedAnalysis,
            photoSessionID: photoSession.id
        )
        startSession(with: context)
        #endif
    }

    // MARK: - Editing

    func applyPreset(
        _ option: VisualizationPresetOption,
        category: VisualizationPresetCategory
    ) async {
        #if canImport(UIKit)
        guard let session = activeSession else {
            errorMessage = "Please start a visualization session first."
            return
        }
        guard let workingImage = activeImage ?? session.latestUIImage else {
            errorMessage = "No base image available."
            return
        }
        guard !isProcessing else { return }

        isProcessing = true
        activityMessage = "Rendering your new look…"
        defer {
            isProcessing = false
            activityMessage = nil
        }

        let analysis = analysisForActiveSession()?.variables

        do {
            let result = try await geminiService.applyPreset(
                baseImage: workingImage,
                category: category,
                option: option,
                analysis: analysis
            )
            try persistEdit(
                image: result,
                prompt: option.prompt,
                isPreset: true,
                presetCategory: category
            )
            lastAppliedOptions[category] = option
            activeImage = result
            refreshPresets()
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }

    func submitCustomPrompt(_ prompt: String) async {
        #if canImport(UIKit)
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Describe what you want to try on."
            return
        }
        guard let session = activeSession else {
            errorMessage = "Start a visualization session to continue."
            return
        }
        guard let workingImage = activeImage ?? session.latestUIImage else {
            errorMessage = "No base image available."
            return
        }
        guard !isProcessing else { return }

        isProcessing = true
        activityMessage = "Rendering your new look…"
        defer {
            isProcessing = false
            activityMessage = nil
        }

        do {
            let result = try await geminiService.generateImageEdit(
                baseImage: workingImage,
                prompt: prompt
            )
            try persistEdit(
                image: result,
                prompt: prompt,
                isPreset: false,
                presetCategory: nil
            )
            activeImage = result
            customPrompt = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }

    // MARK: - Inspiration

    func applyInspiration(_ inspirationImage: UIImage, category: InspirationCategory, description: String?) async {
        #if canImport(UIKit)
        guard let session = activeSession else {
            errorMessage = "Please start a visualization session first."
            return
        }
        guard let baseImage = activeImage ?? session.latestUIImage else {
            errorMessage = "No base image available."
            return
        }
        guard !isProcessing else { return }

        isProcessing = true
        activityMessage = "Blending your inspiration…"
        defer {
            isProcessing = false
            activityMessage = nil
        }

        let prompt = buildInspirationPrompt(category: category, description: description)

        do {
            let result = try await geminiService.generateImageEdit(
                baseImage: baseImage,
                prompt: prompt,
                referenceImages: [inspirationImage]
            )

            if let imageData = inspirationImage.jpegData(compressionQuality: 0.85) {
                let reference = InspirationReference(
                    imageData: imageData,
                    category: category,
                    description: description
                )
                inspirationReferences.append(reference)
            }

            try persistEdit(
                image: result,
                prompt: prompt,
                isPreset: false,
                presetCategory: nil
            )
            activeImage = result
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }

    private func buildInspirationPrompt(category: InspirationCategory, description: String?) -> String {
        let basePrompt: String

        switch category {
        case .hairstyle:
            basePrompt = """
            Carefully study the hairstyle shown in the reference image. Apply this exact hairstyle to the person in the base image, matching:
            - Hair length, texture, and volume
            - Styling technique (waves, curls, straight, etc.)
            - Parting and overall shape
            - Color tone if appropriate to the person's features

            Keep the person's facial features, skin tone, and identity completely unchanged. Only transform the hair.
            """
        case .makeup:
            basePrompt = """
            Analyze the makeup look in the reference image and apply it to the person in the base image. Match:
            - Eye makeup style (liner, shadow placement, intensity)
            - Lip color and finish
            - Blush placement and intensity
            - Overall makeup aesthetic

            Adapt the colors to complement the person's skin tone. Keep facial structure identical.
            """
        case .accessories:
            basePrompt = """
            Add the accessories shown in the reference image (earrings, necklace, headband, etc.) to the person in the base image. 
            - Match the style, size, and placement exactly
            - Ensure natural lighting and shadows
            - Keep the accessories proportional to the person's features

            Do not change the person's face, hair, or clothing unless specified.
            """
        case .outfit:
            basePrompt = """
            Apply the clothing style from the reference image to the person in the base image. Match:
            - Garment type and silhouette
            - Colors and patterns
            - Neckline and fit

            Keep the person's pose, face, and proportions identical. Only change the clothing.
            """
        case .general:
            basePrompt = """
            Study the reference image and apply its key visual elements to the base image in a natural, flattering way.
            Keep the person's identity, facial features, and body proportions completely unchanged.
            """
        }

        if let description = description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            return "\(basePrompt)\n\nAdditional guidance: \(description)"
        }

        return basePrompt
    }

    func clearInspirationReferences() {
        inspirationReferences.removeAll()
    }

    func restoreEdit(_ edit: VisualizationEdit) {
        #if canImport(UIKit)
        guard edit.session?.objectID == activeSession?.objectID else { return }
        activeImage = edit.resultUIImage
        #endif
    }

    // MARK: - Helpers

    private func setActiveSession(_ session: VisualizationSession) {
        let isDifferentSession = activeSession?.objectID != session.objectID
        activeSession = session
        if isDifferentSession {
            lastAppliedOptions.removeAll()
        }
        activeImage = session.latestUIImage
        refreshPresets()
    }

    private func refreshPresets() {
        activePresets = VisualizationPresetGenerator.presets(from: analysisForActiveSession())
    }

    private func persistEdit(
        image: UIImage,
        prompt: String,
        isPreset: Bool,
        presetCategory: VisualizationPresetCategory?
    ) throws {
        guard let session = activeSession else {
            throw GeminiServiceError.emptyResponse
        }
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw GeminiServiceError.unsupportedImageFormat
        }

        let context = persistenceController.viewContext
        let edit = VisualizationEdit(context: context)
        edit.id = UUID()
        edit.timestamp = Date()
        edit.prompt = prompt
        edit.isPreset = isPreset
        edit.presetCategory = presetCategory?.rawValue
        edit.resultImage = data
        edit.session = session

        persistenceController.saveIfNeeded(context)
        loadSessions()
    }

    func deleteEdit(_ edit: VisualizationEdit) {
        let context = persistenceController.viewContext
        context.delete(edit)
        persistenceController.saveIfNeeded(context)
        loadSessions()
        if let session = activeSession {
            activeImage = session.latestUIImage
        } else {
            activeImage = nil
        }
    }

    func saveLikedLook(as category: VisualizationLookCategory) async {
        #if canImport(UIKit)
        guard let session = activeSession else {
            errorMessage = "Start a visualization session before saving a note."
            return
        }
        guard let image = activeImage ?? session.latestUIImage else {
            errorMessage = "No visualization image available to save."
            return
        }
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            errorMessage = "Unable to capture the current look."
            return
        }

        guard !isProcessing else { return }
        isProcessing = true
        activityMessage = "Preparing stylist brief…"
        defer {
            isProcessing = false
            activityMessage = nil
        }

        let context = persistenceController.viewContext
        let note = VisualizationNote(context: context)
        note.id = UUID()
        note.createdAt = Date()
        note.category = category.rawValue
        note.targetProfessional = category.professionalTitle
        note.image = imageData
        note.session = session

        let targetPresetCategory = category.presetCategory
        let edits = session.sortedEdits
        let relevantEdit: VisualizationEdit?
        if let target = targetPresetCategory {
            relevantEdit = edits.reversed().first(where: { $0.presetCategoryEnum == target })
        } else {
            relevantEdit = edits.last
        }

        let prompt = relevantEdit?.prompt ?? (customPrompt.isEmpty ? nil : customPrompt)
        note.prompt = prompt

        let analysisVars = analysisForActiveSession()?.variables
        let resolvedPresetCategory = relevantEdit?.presetCategoryEnum

        var selectedOption: VisualizationPresetOption?
        if let category = resolvedPresetCategory {
            selectedOption = lastAppliedOptions[category]
            if selectedOption == nil, let matchingPrompt = prompt {
                selectedOption = option(for: matchingPrompt, in: category)
            }
        }

        let lookDescription = await describeCurrentLook(
            image: image,
            category: category,
            presetOption: selectedOption,
            prompt: prompt,
            analysis: analysisVars
        )

        let composer = VisualizationNoteComposer.compose(
            category: category,
            prompt: prompt,
            analysis: analysisVars,
            presetCategory: resolvedPresetCategory,
            presetOption: selectedOption,
            lookDescription: lookDescription
        )
        note.summary = composer.summary
        note.detail = composer.detail
        note.keywords = composer.keywords.joined(separator: ", ")

        persistenceController.saveIfNeeded(context)
        loadNotes()
        lastSavedNote = note
        #endif
    }
}

extension VisualizationViewModel {
    private func option(for prompt: String, in category: VisualizationPresetCategory) -> VisualizationPresetOption? {
        if let preset = activePresets.first(where: { $0.category == category }),
           let match = preset.options.first(where: { $0.prompt == prompt }) {
            return match
        }

        if let analysis = analysisForActiveSession(),
           let preset = VisualizationPresetGenerator.presets(from: analysis).first(where: { $0.category == category }) {
            return preset.options.first(where: { $0.prompt == prompt })
        }

        return nil
    }

    #if canImport(UIKit)
    private func describeCurrentLook(
        image: UIImage,
        category: VisualizationLookCategory,
        presetOption: VisualizationPresetOption?,
        prompt: String?,
        analysis: PhotoAnalysisVariables?
    ) async -> LookDescription? {
        guard category != .other else { return nil }
        do {
            return try await openAIService.describeLook(
                image: image,
                category: category,
                presetOption: presetOption,
                prompt: prompt,
                analysis: analysis
            )
        } catch {
            print("[VisualizationViewModel] Failed to generate look description: \(error)")
            return nil
        }
    }
    #endif
}
