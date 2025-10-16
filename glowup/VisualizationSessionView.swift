//
//  VisualizationSessionView.swift
//  glowup
//
//  Interactive editing surface for an active visualization session.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct VisualizationSessionView: View {
    @EnvironmentObject private var viewModel: VisualizationViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: VisualizationPresetCategory?
    @State private var selectedEditID: UUID?
    @State private var showLikeDialog = false
    @State private var showSavedAlert = false

    private var activePresets: [VisualizationPreset] {
        viewModel.activePresets
    }

    var body: some View {
        VStack(spacing: 0) {
            if let session = viewModel.activeSession,
               let displayImage = viewModel.activeImage ?? session.latestUIImage {
                content(for: session, displayImage: displayImage)
            } else {
                emptyState
            }
        }
        .onAppear {
            syncSelectionState()
        }
        .onChange(of: viewModel.activePresets.map(\.category)) { _ in
            syncCategorySelection()
        }
        .onChange(of: viewModel.activeSession?.sortedEdits.count ?? 0) { _ in
            syncEditSelection()
        }
        .onChange(of: viewModel.lastSavedNote?.id) { id in
            if id != nil {
                showSavedAlert = true
            }
        }
        .alert(
            "Unable to Visualize",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { newValue in
                    if !newValue { viewModel.errorMessage = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Look Saved", isPresented: $showSavedAlert, actions: {
            Button("Great!", role: .cancel) {
                viewModel.lastSavedNote = nil
            }
        }, message: {
            if let note = viewModel.lastSavedNote {
                Text("We pinned this look to Notes so you can show it to your \(note.targetProfessional).")
            } else {
                Text("Saved to Notes for later.")
            }
        })
        .confirmationDialog(
            "Who is this look for?",
            isPresented: $showLikeDialog,
            titleVisibility: .visible
        ) {
            ForEach(VisualizationLookCategory.allCases, id: \.self) { category in
                Button(category.displayName) {
                    viewModel.saveLikedLook(as: category)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func content(for session: VisualizationSession, displayImage: UIImage) -> some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 26) {
                    sessionHeader(session)
                    heroImage(displayImage)
                    editHistoryStrip(session)
                    likeLookButton(session: session)
                    presetsSection()
                    analysisInsights(session)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 120) // space for prompt bar
            }

            PromptInputBar(
                text: Binding(
                    get: { viewModel.customPrompt },
                    set: { viewModel.customPrompt = $0 }
                ),
                onSubmit: {
                    Task {
                        await viewModel.submitCustomPrompt(viewModel.customPrompt)
                    }
                },
                isLoading: viewModel.isProcessing
            )
        }
        .overlay {
            if viewModel.isProcessing {
                LoadingOverlay(label: "Rendering your new look…")
            }
        }
    }

    private func likeLookButton(session: VisualizationSession) -> some View {
        let canSave = !session.sortedEdits.isEmpty
        return Button {
            showLikeDialog = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.headline.weight(.semibold))
                Text("I Like This Look")
                    .font(.headline.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color(red: 0.94, green: 0.34, blue: 0.56))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.45)
        .padding(.top, 8)
    }

    private func sessionHeader(_ session: VisualizationSession) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Visualization Session")
                    .font(.headline)
                    .foregroundStyle(.white)

                if let createdAt = session.createdAt {
                    Text(createdAt, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                if let reference = session.analysisReference {
                    Text("Linked to analysis #\(reference.uuidString.prefix(6))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            Spacer()

            Menu {
                Button {
                    viewModel.resetActiveSession()
                    selectedEditID = nil
                } label: {
                    Label("Revert to Original", systemImage: "arrow.uturn.backward.circle")
                }

                Button {
                    viewModel.startFromLatestAnalysis()
                } label: {
                    Label("Reload Latest Analysis", systemImage: "sparkles.rectangle.stack.fill")
                }

                Button(role: .destructive) {
                    viewModel.delete(session: session)
                    dismiss()
                } label: {
                    Label("Delete Session", systemImage: "trash.fill")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(6)
            }
        }
    }

    private func heroImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 16)
            .contextMenu {
                Button {
                    viewModel.isPresentingImagePicker = true
                } label: {
                    Label("Change Base Image", systemImage: "photo.on.rectangle")
                }
            }
    }

    private func editHistoryStrip(_ session: VisualizationSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Edit History")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    viewModel.isPresentingImagePicker = true
                } label: {
                    Label("Change Image", systemImage: "camera.rotate")
                        .font(.footnote.weight(.semibold))
                        .padding(8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if let base = session.baseUIImage {
                        EditThumbnail(
                            image: base,
                            isActive: selectedEditID == nil,
                            tapAction: {
                                viewModel.resetActiveSession()
                                selectedEditID = nil
                            }
                        )
                    }

                    ForEach(session.sortedEdits, id: \.objectID) { edit in
                        if let image = edit.resultUIImage {
                            EditThumbnail(
                                image: image,
                                isActive: selectedEditID == edit.id,
                                tapAction: {
                                    viewModel.restoreEdit(edit)
                                    selectedEditID = edit.id
                                }
                            )
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func presetsSection() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("AI Presets")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            if activePresets.isEmpty {
                Text("Once you have an analysis linked, smart presets will appear here.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(activePresets, id: \.category) { preset in
                            let isSelected = preset.category == selectedCategory
                            Button {
                                selectedCategory = preset.category
                            } label: {
                                Text(preset.category.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let category = selectedCategory,
                   let preset = activePresets.first(where: { $0.category == category }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(preset.description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))

                        LazyVStack(spacing: 12) {
                            ForEach(preset.options, id: \.id) { option in
                                PresetCard(category: preset.category, option: option) {
                                    Task {
                                        await viewModel.applyPreset(option, category: preset.category)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 6)
                }
            }
        }
    }

    private func analysisInsights(_ session: VisualizationSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Guidance Notes")
                .font(.headline)
                .foregroundStyle(.white)

            if let analysis = viewModel.analysisForActiveSession() {
                VStack(alignment: .leading, spacing: 10) {
                    if let faceShape = analysis.variables.faceShape {
                        insightRow(title: "Face Shape", value: faceShape)
                    }
                    if let palette = analysis.variables.seasonalPalette {
                        insightRow(title: "Palette", value: palette)
                    }
                    if let makeupStyle = analysis.variables.makeupStyle as String? {
                        insightRow(title: "Preferred Makeup", value: makeupStyle)
                    }
                    if !analysis.variables.bestColors.isEmpty {
                        insightRow(
                            title: "Power Colors",
                            value: analysis.variables.bestColors.joined(separator: ", ")
                        )
                    }
                    if !analysis.variables.quickWins.isEmpty {
                        insightRow(
                            title: "Quick Wins",
                            value: analysis.variables.quickWins.prefix(2).joined(separator: ", ")
                        )
                    }
                }
                .padding()
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                Text("Run a fresh analysis to unlock tailored presets and insights.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private func insightRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Text(value)
                    .font(.body)
                    .foregroundStyle(.white)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.65))

            Text("Visualize Your Next Look")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("Send a look from your analysis or upload a fresh photo to start transforming your glow story.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 28)

            Button {
                viewModel.isPresentingImagePicker = true
            } label: {
                Label("Start Visualization", systemImage: "sparkles")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.94, green: 0.34, blue: 0.56))
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .padding(.bottom, 80)
    }

    private func syncSelectionState() {
        syncCategorySelection()
        syncEditSelection()
    }

    private func syncCategorySelection() {
        if selectedCategory == nil, let first = activePresets.first {
            selectedCategory = first.category
        } else if let selected = selectedCategory,
                  !activePresets.contains(where: { $0.category == selected }) {
            selectedCategory = activePresets.first?.category
        }
    }

    private func syncEditSelection() {
        guard let session = viewModel.activeSession else {
            selectedEditID = nil
            return
        }
        selectedEditID = session.sortedEdits.last?.id
    }
}
