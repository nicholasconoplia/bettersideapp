//
//  AICoachOptionsView.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import PhotosUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AnalyzeContainerView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.managedObjectContext) private var context

    @AppStorage("hasUsedFreeScan") private var hasUsedFreeScan = false
    @State private var personaSelection: CoachPersona = .bestie
    @State private var showUploadWizard = false
    @State private var showAnalysisSheet = false
    @State private var pendingBundle: PhotoAnalysisBundle?
    @State private var shouldPresentAnalysisAfterWizard = false

    @State private var showResults = false

    var body: some View {
        NavigationStack {
            ZStack {
                GlowGradient.canvas
                    .ignoresSafeArea()
                VStack(spacing: 28) {
                    cameraPreview
                    helperText
                    buttonStack
                    previousAnalysesButton
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showUploadWizard) {
            StructuredPhotoUploadView { bundle in
                pendingBundle = bundle
                shouldPresentAnalysisAfterWizard = true
                showUploadWizard = false
            }
        }
        .sheet(isPresented: $showAnalysisSheet) {
            if let bundle = pendingBundle {
                StaticPhotoAnalysisView(persona: personaSelection, bundle: bundle)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: showUploadWizard) { isPresented in
            if !isPresented {
                if shouldPresentAnalysisAfterWizard, pendingBundle != nil {
                    DispatchQueue.main.async {
                        showAnalysisSheet = true
                    }
                }
                shouldPresentAnalysisAfterWizard = false
            }
        }
        .onChange(of: showAnalysisSheet) { newValue in
            if !newValue {
                pendingBundle = nil
            }
        }
        .onAppear {
            if let personaID = appModel.userSettings?.coachPersonaID,
               let persona = CoachPersona(rawValue: personaID) {
                personaSelection = persona
            }
        }
        .sheet(isPresented: $showResults) {
            ResultsSheetView()
        }
    }

    private var cameraPreview: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(GlowPalette.softBeige)
            .frame(height: 240)
            .overlay {
                VStack(spacing: 16) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 40))
                        .foregroundStyle(GlowPalette.deepRose)
                    Text("Upload or capture photos and we’ll handle the analysis.")
                        .font(GlowTypography.body(16, weight: .semibold))
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .shadow(
                color: GlowShadow.soft.color,
                radius: GlowShadow.soft.radius,
                x: GlowShadow.soft.x,
                y: GlowShadow.soft.y
            )
    }

    private var helperText: some View {
        Text("Capture a full face, skin close-up, and eye detail to unlock hyper-specific coaching.")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
    }

    private var buttonStack: some View {
        VStack(spacing: 16) {
            Button {
                if subscriptionManager.isSubscribed {
                    showUploadWizard = true
                } else if hasUsedFreeScan {
                    SuperwallService.shared.registerEvent("subscription_paywall")
                } else {
                    showUploadWizard = true
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.headline)
                    Text("Start Glow Scan")
                        .font(GlowTypography.button)
                }
                .padding(.horizontal, 20)
            }
            .glowRoundedButtonBackground(isEnabled: true)
            
            Text("We’ll guide you through three quick uploads so the AI can score facial harmony, skin texture, and eye styling.")
                .font(GlowTypography.caption)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    private var previousAnalysesButton: some View {
        Button {
            showResults = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                Text("View Previous Analyses")
            }
            .font(GlowTypography.body(15, weight: .semibold))
            .foregroundStyle(GlowPalette.deepRose)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(GlowPalette.softBeige.opacity(0.85))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Structured Multi-Photo Upload

private struct StructuredPhotoUploadView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @AppStorage("hasUsedFreeScan") private var hasUsedFreeScan = false
    enum CaptureStage: String, CaseIterable, Identifiable {
        case face, skin
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .face: return "Full Face Reference"
            case .skin: return "Skin Texture Close-Up"
            }
        }
        
        var instruction: String {
            switch self {
            case .face:
                return "Frame your head and shoulders in bright, even lighting. Pull hair back, look straight at the camera, and keep the camera at eye level."
            case .skin:
                return "Hold the camera 6-8 inches from a cheek or forehead area. Stay in natural light so pores and texture are visible without harsh flash."
            }
        }
        
        var whyItMatters: String {
            switch self {
            case .face:
                return "Used to score facial harmony, proportional balance, dimorphism, and facial angularity."
            case .skin:
                return "Feeds the skin texture, clarity, and skincare roadmap recommendations."
            }
        }
        
        var systemImage: String {
            switch self {
            case .face: return "person.crop.square"
            case .skin: return "circle.dashed"
            }
        }
    }
    
    @Environment(\.dismiss) private var dismiss
    let onComplete: (PhotoAnalysisBundle) -> Void
    
    @State private var facePickerItem: PhotosPickerItem?
    @State private var skinPickerItem: PhotosPickerItem?
    @State private var faceData: Data?
    @State private var skinData: Data?
    @State private var isLoadingStage: CaptureStage?
    @State private var activeCameraStage: CaptureStage?
    
    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground.twilightAura
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 28) {
                        introCard
                        ForEach(CaptureStage.allCases) { stage in
                            stageCard(for: stage)
                        }
                        actionButtons
                    }
                    .padding(.vertical, 32)
                    .padding(.horizontal, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .tint(.white)
                }
            }
            .navigationTitle("Upload Breakdown")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(item: $activeCameraStage) { stage in
            CameraCaptureView { image in
                store(image: image, for: stage)
            }
        }
        .task(id: facePickerItem) { await loadImage(from: facePickerItem, for: .face) }
        .task(id: skinPickerItem) { await loadImage(from: skinPickerItem, for: .skin) }
    }
    
    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Soft-Max Glow Scan")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Upload two focused shots so the AI can map facial harmony and skin health. Keep lighting consistent and wipe the camera lens before each capture.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding()
        .background(Color.white.opacity(0.12))
        .cornerRadius(24)
    }
    
    private func stageCard(for stage: CaptureStage) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: stage.systemImage)
                    .foregroundStyle(.white)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(stage.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(stage.whyItMatters)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                if let data = data(for: stage) {
                    Text("Ready")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(10)
                }
            }
            
            Text(stage.instruction)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            
            previewView(for: stage)
            
            controlRow(for: stage)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(22)
    }
    
    @ViewBuilder
    private func previewView(for stage: CaptureStage) -> some View {
        if let data = data(for: stage), let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 180)
                .clipped()
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(height: 180)
                .overlay(
                    VStack(spacing: 10) {
                        if isLoadingStage == stage {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Text("No photo yet")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                )
        }
    }
    
    private func controlRow(for stage: CaptureStage) -> some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: binding(for: stage), matching: .images) {
                Label(data(for: stage) == nil ? "Choose Photo" : "Replace Photo", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(GlowPalette.roseGold)
            .disabled(isLoadingStage != nil)
            
            Button {
                activeCameraStage = stage
            } label: {
                Label("Use Camera", systemImage: "camera.viewfinder")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(GlowPalette.deepRose)
            .disabled(isLoadingStage != nil)
            
            if data(for: stage) != nil {
                Button {
                    removeData(for: stage)
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.bold))
                        .padding(12)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.red.opacity(0.8))
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 14) {
            Button {
                if !subscriptionManager.isSubscribed && hasUsedFreeScan {
                    SuperwallService.shared.registerEvent("subscription_paywall")
                    return
                }
                if let faceData, let skinData {
                    let bundle = PhotoAnalysisBundle(face: faceData, skin: skinData, eyes: nil)
                    onComplete(bundle)
                    dismiss()
                }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Analyze My Glow")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(GlowPalette.creamyWhite)
                .padding()
                .frame(maxWidth: .infinity)
                .background(GlowPalette.deepRose)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(!isBundleReady)
            
            Button {
                faceData = nil
                skinData = nil
            } label: {
                Text("Reset Selections")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .disabled(faceData == nil && skinData == nil)
        }
    }
    
    private var isBundleReady: Bool {
        faceData != nil && skinData != nil && isLoadingStage == nil
    }
    
    private func data(for stage: CaptureStage) -> Data? {
        switch stage {
        case .face: return faceData
        case .skin: return skinData
        }
    }
    
    private func binding(for stage: CaptureStage) -> Binding<PhotosPickerItem?> {
        switch stage {
        case .face:
            return Binding(
                get: { facePickerItem },
                set: { facePickerItem = $0 }
            )
        case .skin:
            return Binding(
                get: { skinPickerItem },
                set: { skinPickerItem = $0 }
            )
        }
    }
    
    private func removeData(for stage: CaptureStage) {
        switch stage {
        case .face:
            faceData = nil
            facePickerItem = nil
        case .skin:
            skinData = nil
            skinPickerItem = nil
        }
    }
    
    private func store(image: UIImage, for stage: CaptureStage) {
        if let processed = processedData(from: image, for: stage) {
            setData(processed, for: stage)
        }
    }
    
    private func setData(_ data: Data, for stage: CaptureStage) {
        switch stage {
        case .face: faceData = data
        case .skin: skinData = data
        }
    }
    
    @MainActor
    private func loadImage(from item: PhotosPickerItem?, for stage: CaptureStage) async {
        guard let item else { return }
        do {
            isLoadingStage = stage
            if let rawData = try await item.loadTransferable(type: Data.self) {
                if let image = UIImage(data: rawData),
                   let processed = processedData(from: image, for: stage) {
                    setData(processed, for: stage)
                } else {
                    setData(rawData, for: stage)
                }
            }
        } catch {
            print("[StructuredPhotoUploadView] Failed to load image for \(stage.rawValue): \(error.localizedDescription)")
        }
        isLoadingStage = nil
    }
    
    private func processedData(from image: UIImage, for stage: CaptureStage) -> Data? {
        let maxDimension: CGFloat
        let compression: CGFloat = 0.8
        
        switch stage {
        case .face:
            maxDimension = 1024
        case .skin:
            maxDimension = 768
        }
        
        let size = image.size
        let maxSide = max(size.width, size.height)
        var targetImage = image
        if maxSide > maxDimension {
            let scale = maxDimension / maxSide
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            targetImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        }
        return targetImage.jpegData(compressionQuality: compression)
    }
}

// MARK: - Camera Capture

private struct CameraCaptureView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            controller.sourceType = .camera
        } else {
            controller.sourceType = .photoLibrary
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraCaptureView

        init(parent: CameraCaptureView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
