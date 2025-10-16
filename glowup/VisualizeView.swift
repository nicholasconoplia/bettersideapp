//
//  VisualizeView.swift
//  glowup
//
//  Entry point for managing visualization sessions.
//

import PhotosUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct VisualizationSessionRoute: Identifiable, Hashable {
    let id: UUID
}

struct VisualizeView: View {
    @EnvironmentObject private var viewModel: VisualizationViewModel
    @State private var route: VisualizationSessionRoute?
    @State private var showCameraPicker = false
    @State private var showLibraryPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground.primary
                    .ignoresSafeArea()

                if viewModel.sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("Visualize")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.isPresentingImagePicker = true
                    } label: {
                        Label("New Visualization", systemImage: "plus")
                            .font(.headline)
                    }
                    .tint(.white)
                }
            }
            .navigationDestination(item: $route) { route in
                VisualizationSessionView()
                    .environmentObject(viewModel)
                    .onAppear {
                        if let session = viewModel.sessions.first(where: { $0.id == route.id }) {
                            viewModel.select(session: session)
                        }
                    }
            }
        }
        .photosPicker(isPresented: $showLibraryPicker, selection: $selectedPhotoItem, matching: .images)
        .sheet(isPresented: $showCameraPicker) {
            VisualizationCameraPicker { image in
                handleSelectedImage(image)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isPresentingImagePicker },
            set: { viewModel.isPresentingImagePicker = $0 }
        )) {
            ImageSourcePicker {
                viewModel.isPresentingImagePicker = false
                showCameraPicker = true
            } onLibrary: {
                viewModel.isPresentingImagePicker = false
                showLibraryPicker = true
            } onUseAnalysis: {
                viewModel.isPresentingImagePicker = false
                viewModel.startFromLatestAnalysis()
                if let id = viewModel.activeSession?.id {
                    route = VisualizationSessionRoute(id: id)
                }
            }
            .presentationDetents([.height(380)])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedPhotoItem) { newValue in
            guard let item = newValue else { return }
            Task {
                await loadImage(from: item)
            }
        }
        .onAppear {
            if let id = viewModel.activeSession?.id, route?.id != id {
                route = VisualizationSessionRoute(id: id)
            }
        }
        .onChange(of: viewModel.activeSession?.id) { newValue in
            if let id = newValue {
                if route?.id != id {
                    route = VisualizationSessionRoute(id: id)
                }
            } else {
                route = nil
            }
        }
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                ForEach(viewModel.sessions, id: \.objectID) { session in
                    NavigationLink {
                        VisualizationSessionView()
                            .environmentObject(viewModel)
                            .onAppear {
                                viewModel.select(session: session)
                            }
                    } label: {
                        sessionCard(for: session)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        viewModel.select(session: session)
                    })
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
    }

    private func sessionCard(for session: VisualizationSession) -> some View {
        HStack(alignment: .center, spacing: 18) {
            if let preview = session.latestUIImage {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 86, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 8)
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 86, height: 86)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Session \(sessionLabel(for: session))")
                    .font(.headline)
                    .foregroundStyle(.white)

                if let createdAt = session.createdAt {
                    Text(createdAt, style: .relative)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }

                Text("\(session.sortedEdits.count) edit\(session.sortedEdits.count == 1 ? "" : "s") • Presets ready")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            Image(systemName: "wand.and.rays")
                .font(.system(size: 66))
                .foregroundStyle(.white.opacity(0.7))

            Text("Welcome to Visualize")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Transform your glow recommendations into real visuals. Start with your latest results or upload any photo to explore hair, makeup, and wardrobe experiments.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 32)

            Button {
                viewModel.isPresentingImagePicker = true
            } label: {
                Label("Start Visualizing", systemImage: "sparkles")
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.94, green: 0.34, blue: 0.56))
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 80)
    }

    private func handleSelectedImage(_ image: UIImage) {
        viewModel.startSession(from: image)
        if let id = viewModel.activeSession?.id {
            route = VisualizationSessionRoute(id: id)
        }
    }

    private func sessionLabel(for session: VisualizationSession) -> String {
        if let createdAt = session.createdAt {
            return DateFormatter.shortDateFormatter.string(from: createdAt)
        }
        return session.id?.uuidString.prefix(6).uppercased() ?? "New"
    }

    private func loadImage(from item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    handleSelectedImage(image)
                    showLibraryPicker = false
                }
            }
        } catch {
            print("[VisualizeView] Failed to load image: \(error.localizedDescription)")
        }
        await MainActor.run {
            selectedPhotoItem = nil
        }
    }
}

private extension DateFormatter {
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct VisualizationCameraPicker: UIViewControllerRepresentable {
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
        controller.allowsEditing = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: VisualizationCameraPicker

        init(parent: VisualizationCameraPicker) {
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
