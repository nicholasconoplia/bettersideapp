//
//  VisualizeView.swift
//  glowup
//
//  Entry point for managing visualization sessions.
//

import CoreData
import PhotosUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct VisualizationSessionRoute: Identifiable, Hashable {
    let id: UUID
}

private enum VisualizeSegment: String, CaseIterable {
    case history = "History"
    case notes = "Notes"

    var title: String { rawValue }
}

struct VisualizeView: View {
    @EnvironmentObject private var viewModel: VisualizationViewModel
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        entity: VisualizationNote.entity(),
        sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
        animation: .easeInOut
    ) private var notes: FetchedResults<VisualizationNote>
    @State private var route: VisualizationSessionRoute?
    @State private var showCameraPicker = false
    @State private var showLibraryPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedSegment: VisualizeSegment = .history

    var body: some View {
        NavigationStack {
            ZStack {
                visualizationContent
                    .blur(radius: isLocked ? 8 : 0)
                    .allowsHitTesting(!isLocked)

                if isLocked {
                    lockedOverlay
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .navigationTitle(selectedSegment == .history ? "Visualize" : "Notes")
            .toolbar {
                if selectedSegment == .history && !isLocked {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            viewModel.isPresentingImagePicker = true
                        } label: {
                            Label("New Visualization", systemImage: "plus")
                                .font(.glowSubheading)
                                .foregroundStyle(GlowPalette.deepRose)
                        }
                        .tint(GlowPalette.deepRose)
                    }
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
            .navigationDestination(for: NSManagedObjectID.self) { objectID in
                if let note = fetchNote(with: objectID) {
                    VisualizationNoteDetailView(note: note)
                } else {
                    Text("Note not found.")
                        .deepRoseText()
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
            get: { viewModel.isPresentingImagePicker && !isLocked },
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
                selectedSegment = .history
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
            if isLocked {
                route = nil
            } else if selectedSegment == .history,
                      let id = viewModel.activeSession?.id,
                      route?.id != id {
                route = VisualizationSessionRoute(id: id)
            }
        }
        .onChange(of: viewModel.activeSession?.id) { newValue in
            guard !isLocked, selectedSegment == .history else {
                route = nil
                return
            }
            if let id = newValue {
                if route?.id != id {
                    route = VisualizationSessionRoute(id: id)
                }
            } else {
                route = nil
            }
        }
        .onChange(of: selectedSegment) { segment in
            if segment == .history {
                if !isLocked, let id = viewModel.activeSession?.id {
                    route = VisualizationSessionRoute(id: id)
                }
            } else {
                route = nil
                viewModel.isPresentingImagePicker = false
            }
        }
        .onChange(of: appModel.isSubscribed) { subscribed in
            if !subscribed {
                route = nil
                viewModel.isPresentingImagePicker = false
            }
        }
        .toolbarBackground(GlowPalette.creamyWhite, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }

    private var isLocked: Bool {
        !appModel.isSubscribed
    }

    private var visualizationContent: some View {
        ZStack {
            GlowGradient.canvas
                .ignoresSafeArea()
            VStack(spacing: 0) {
                segmentPicker
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 12)

                Group {
                    switch selectedSegment {
                    case .history:
                        historyContent
                    case .notes:
                        notesContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var historyContent: some View {
        Group {
            if viewModel.sessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
        .transition(.opacity)
    }

    private var segmentPicker: some View {
        Picker("Visualize Section", selection: $selectedSegment) {
            ForEach(VisualizeSegment.allCases, id: \.self) { segment in
                Text(segment.title).tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    private var notesContent: some View {
        Group {
            if notes.isEmpty {
                notesEmptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(notes, id: \.objectID) { note in
                            NavigationLink(value: note.objectID) {
                                noteCard(note)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(note)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .transition(.opacity)
    }

    private var notesEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 58))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
            Text("Save Your Favorites")
                .font(.glowHeading.bold())
                .deepRoseText()
            Text("Tap \"I Like This Look\" in Visualize to pin detailed instructions, pro-ready notes, and image references right here.")
                .font(.glowBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.75))
                .padding(.horizontal, 32)
        }
        .padding(.bottom, 80)
    }

    private func noteCard(_ note: VisualizationNote) -> some View {
        HStack(spacing: 16) {
            if let image = note.renderedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(GlowPalette.deepRose.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(note.summary ?? "Favorite Look")
                    .font(.glowSubheading)
                    .deepRoseText()

                Text(note.detail ?? "")
                    .font(.glowBody)
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.7))

                HStack(spacing: 8) {
                    Label(note.lookCategory.displayName, systemImage: "tag.fill")
                        .font(GlowTypography.glowCaption.weight(.semibold))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(GlowPalette.deepRose.opacity(0.12))
                        .clipShape(Capsule())

                    Text((note.createdAt ?? Date()), formatter: Self.noteDateFormatter)
                        .font(GlowTypography.glowCaption)
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.55))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.glowSubheading.weight(.semibold))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.45))
        }
        .padding()
        .background(GlowPalette.deepRose.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(GlowPalette.deepRose.opacity(0.06), lineWidth: 1)
        )
    }

    private func delete(_ note: VisualizationNote) {
        context.delete(note)
        do {
            try context.save()
        } catch {
            print("[VisualizeView] Failed to delete note: \(error.localizedDescription)")
        }
    }

    private func fetchNote(with id: NSManagedObjectID) -> VisualizationNote? {
        try? context.existingObject(with: id) as? VisualizationNote
    }

    private static let noteDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var lockedOverlay: some View {
        VStack(spacing: 18) {
            Text("Studio (Locked)")
                .font(GlowTypography.heading(28, weight: .bold))
                .foregroundStyle(GlowPalette.deepRose)

            Text("Try on hairstyles, makeup, and outfits powered by your analysis.")
                .font(GlowTypography.body(16))
                .multilineTextAlignment(.center)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.75))

            Button {
                presentUnlockPaywall()
            } label: {
                Text("Unlock full analysis")
                    .font(GlowTypography.button)
                    .frame(maxWidth: .infinity)
            }
            .glowRoundedButtonBackground(isEnabled: true)
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: GlowPalette.deepRose.opacity(0.18), radius: 20, x: 0, y: 12)
    }

    private func presentUnlockPaywall() {
        Task {
            _ = await SuperwallService.shared.presentAndAwaitDismissal("subscription_paywall", timeoutSeconds: 8)
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
                            .stroke(GlowPalette.roseStroke(0.35), lineWidth: 1)
                    )
                    .shadow(
                        color: GlowShadow.soft.color,
                        radius: GlowShadow.soft.radius,
                        x: GlowShadow.soft.x,
                        y: GlowShadow.soft.y
                    )
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(GlowPalette.softOverlay(0.6))
                    .frame(width: 86, height: 86)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.glowHeading)
                            .foregroundStyle(GlowPalette.roseGold.opacity(0.7))
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Session \(sessionLabel(for: session))")
                    .font(.glowSubheading)
                    .deepRoseText()

                if let createdAt = session.createdAt {
                    Text(createdAt, style: .relative)
                        .font(Font.glowCaption)
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.55))
                }

                Text("\(session.sortedEdits.count) edit\(session.sortedEdits.count == 1 ? "" : "s") • Presets ready")
                    .font(Font.glowCaption)
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(GlowPalette.roseGold.opacity(0.6))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GlowPalette.softOverlay(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(GlowPalette.roseStroke(0.25), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            Image(systemName: "wand.and.rays")
                .font(.system(size: 66))
                .foregroundStyle(GlowPalette.roseGold.opacity(0.7))

            Text("Welcome to Visualize")
                .font(GlowTypography.glowHeading)
                .foregroundStyle(GlowPalette.deepRose)

            Text("Transform your glow recommendations into real visuals. Start with your latest results or upload any photo to explore hair, makeup, and wardrobe experiments.")
                .font(GlowTypography.glowBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.75))
                .padding(.horizontal, 32)

            Button {
                viewModel.isPresentingImagePicker = true
            } label: {
                Label("Start Visualizing", systemImage: "sparkles")
                    .font(GlowTypography.glowButton)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(GlowPalette.blushPink)
                    )
                    .foregroundStyle(GlowPalette.deepRose)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 80)
    }

    private func handleSelectedImage(_ image: UIImage) {
        selectedSegment = .history
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
