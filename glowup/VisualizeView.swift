//
//  VisualizeView.swift
//  glowup
//
//  Main visualization interface showing saved sessions and new session creation
//

import SwiftUI
import CoreData

struct VisualizeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var sessionManager = VisualizationSessionManager(persistenceController: PersistenceController.shared)
    @State private var showingNewSession = false
    @State private var selectedImageSource: ImageSourceType?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedPhotoSession: PhotoSession?
    @State private var showingPhotoLibrary = false
    
    @FetchRequest(
        entity: PhotoSession.entity(),
        sortDescriptors: [NSSortDescriptor(key: "startTime", ascending: false)],
        animation: .easeInOut
    ) private var photoSessions: FetchedResults<PhotoSession>
    
    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground.primary
                    .ignoresSafeArea()
                
                if sessionManager.sessions.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(sessionManager.sessions, id: \.objectID) { session in
                                sessionCard(for: session)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationTitle("Visualize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    newVisualizationButton
                }
            }
            .sheet(isPresented: $showingNewSession) {
                newSessionSheet
            }
            .sheet(isPresented: $showingImagePicker) {
                imageSourceSelectionSheet
            }
            .sheet(isPresented: $showingCamera) {
                CameraView { image in
                    createSessionWithImage(image)
                }
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                ImagePicker { image in
                    createSessionWithImage(image)
                }
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                PhotoSessionSelectionView { session in
                    createSessionFromAnalysis(session)
                }
            }
        }
        .onAppear {
            sessionManager.loadSessions()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "wand.and.stars.inverse")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Start Visualizing")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("Transform your photos with AI-powered visualization. Try different hairstyles, makeup, and styles based on your analysis results.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 40)
            
            Button {
                showingNewSession = true
            } label: {
                Label("Create First Visualization", systemImage: "plus.circle.fill")
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
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Session Cards
    
    private func sessionCard(for session: VisualizationSession) -> some View {
        NavigationLink(destination: VisualizationSessionView(session: session)) {
            HStack(spacing: 16) {
                // Thumbnail
                Group {
                    if let image = session.baseUIImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.6))
                            )
                    }
                }
                
                // Session Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Visualization Session")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(dateFormatter.string(from: session.createdAt))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    let editCount = session.edits?.count ?? 0
                    Text("\(editCount) edit\(editCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                // Edit count badge
                if let edits = session.edits, !edits.isEmpty {
                    VStack(spacing: 4) {
                        Text("\(edits.count)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color(red: 0.94, green: 0.34, blue: 0.56))
                        Text("Edits")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Toolbar
    
    private var newVisualizationButton: some View {
        Button {
            showingNewSession = true
        } label: {
            Image(systemName: "plus")
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Sheets
    
    private var newSessionSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "wand.and.stars.inverse")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                
                Text("Create New Visualization")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("Choose an image to start visualizing different looks")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    imageSourceButton(
                        title: "Take Photo",
                        icon: "camera.fill",
                        color: .blue
                    ) {
                        showingCamera = true
                        showingNewSession = false
                    }
                    
                    imageSourceButton(
                        title: "Choose from Library",
                        icon: "photo.on.rectangle",
                        color: .green
                    ) {
                        showingPhotoLibrary = true
                        showingNewSession = false
                    }
                    
                    if !photoSessions.isEmpty {
                        imageSourceButton(
                            title: "Use from Analysis",
                            icon: "sparkles",
                            color: .purple
                        ) {
                            selectedPhotoSession = photoSessions.first
                            showingPhotoLibrary = true
                            showingNewSession = false
                        }
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .background(GradientBackground.primary.ignoresSafeArea())
            .navigationTitle("New Visualization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingNewSession = false
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
    
    private var imageSourceSelectionSheet: some View {
        // This would be used for more complex image source selection
        EmptyView()
    }
    
    // MARK: - Helper Methods
    
    private func createSessionWithImage(_ image: UIImage) {
        sessionManager.createSession(baseImage: image)
        showingNewSession = false
    }
    
    private func createSessionFromAnalysis(_ session: PhotoSession) {
        guard let image = session.uploadedImage else { return }
        sessionManager.createSession(baseImage: image, analysisReference: session.id)
        showingNewSession = false
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Supporting Views

struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct PhotoSessionSelectionView: View {
    let onSessionSelected: (PhotoSession) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        entity: PhotoSession.entity(),
        sortDescriptors: [NSSortDescriptor(key: "startTime", ascending: false)],
        animation: .easeInOut
    ) private var sessions: FetchedResults<PhotoSession>
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions, id: \.objectID) { session in
                    Button {
                        onSessionSelected(session)
                        dismiss()
                    } label: {
                        HStack {
                            if let image = session.uploadedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            VStack(alignment: .leading) {
                                Text(session.sessionType ?? "Static Photo")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(session.startTime?.formatted() ?? "Unknown date")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    VisualizeView()
}