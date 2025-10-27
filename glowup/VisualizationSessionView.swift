//
//  VisualizationSessionView.swift
//  glowup
//
//  Interactive editing surface for an active visualization session.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif // canImport(UIKit)

struct VisualizationSessionView: View {
    @EnvironmentObject private var viewModel: VisualizationViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: VisualizationPresetCategory?
    @State private var selectedEditID: UUID?
    @State private var showLikeDialog = false
    @State private var showLikeSheet = false   // ✅ Added for iPad fix
    @State private var showSavedAlert = false
    @State private var showInspirationInput = false

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
                Text("We pinned this look to Notes so you can show it to your \(note.professionalTitle).")
            } else {
                Text("Saved to Notes for later.")
            }
        })
        // ✅ Added simple iPad-safe sheet
        .sheet(isPresented: $showLikeSheet) {
            VStack(spacing: 20) {
                Text("Who is this look for?")
                    .font(.glowSubheading)
                ForEach(VisualizationLookCategory.allCases, id: \.self) { category in
                    Button(category.displayName) {
                        Task {
                            await viewModel.saveLikedLook(as: category)
                            showLikeSheet = false
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    showLikeSheet = false
                }
            }
            .padding()
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }

        .confirmationDialog(
            "Who is this look for?",
            isPresented: $showLikeDialog,
            titleVisibility: .visible
        ) {
            ForEach(VisualizationLookCategory.allCases, id: \.self) { category in
                Button(category.displayName) {
                    Task {
                        await viewModel.saveLikedLook(as: category)
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .background(GradientBackground.primary.ignoresSafeArea())
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(GradientBackground.primary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showInspirationInput = true
                } label: {
                    Label("Add Inspiration", systemImage: "photo.badge.plus")
                        .font(.glowSubheading)
                }
                .tint(GlowPalette.roseGold)
            }
        }
        .sheet(isPresented: $showInspirationInput) {
            InspirationInputView()
                .environmentObject(viewModel)
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
                LoadingOverlay(label: viewModel.activityMessage ?? "Working…")
            }
        }
    }

    private func likeLookButton(session: VisualizationSession) -> some View {
        let canSave = !session.sortedEdits.isEmpty
        return Button {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                showLikeSheet = true   // ✅ On iPad, use sheet
            } else {
                showLikeDialog = true  // ✅ On iPhone, use dialog
            }
            #else
            showLikeDialog = true
            #endif
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
            .deepRoseText()
            .frame(maxWidth: .infinity)
            .padding()
            .background(GlowGradient.blushAccent)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: GlowShadow.soft.color.opacity(0.8), radius: 10, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!canSave || viewModel.isProcessing)
        .opacity((canSave && !viewModel.isProcessing) ? 1 : 0.45)
        .padding(.top, 8)
    }

    private func sessionHeader(_ session: VisualizationSession) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Visualization Session")
                    .font(.glowSubheading)
                    .deepRoseText()

                if let createdAt = session.createdAt {
                    Text(createdAt, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
                }

                if let reference = session.analysisReference {
                    Text("Linked to analysis #\(reference.uuidString.prefix(6))")
                        .font(.glowBody)
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.55))
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
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
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
                    .stroke(GlowPalette.creamyWhite.opacity(0.12), lineWidth: 1)
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
                    .font(.glowSubheading)
                    .deepRoseText()
                Spacer()
                Button {
                    viewModel.isPresentingImagePicker = true
                } label: {
                    Label("Change Image", systemImage: "camera.rotate")
                        .font(.footnote.weight(.semibold))
                        .padding(8)
                        .background(GlowPalette.creamyWhite.opacity(0.08))
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
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.deleteEdit(edit)
                                    if selectedEditID == edit.id {
                                        selectedEditID = viewModel.activeSession?.sortedEdits.last?.id
                                    }
                                } label: {
                                    Label("Delete Edit", systemImage: "trash")
                                }
                            }
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
                    .deepRoseText()
                Spacer()
            }

            // Inspiration quick entry card
            Button {
                showInspirationInput = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "photo.stack.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(GlowPalette.deepRose)
                        .frame(width: 48, height: 48)
                        .background(GlowPalette.blushOverlay(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Upload Inspiration Photo")
                            .font(.glowSubheading)
                            .deepRoseText()
                        Text("Upload an inspiration photo of the look you want to try")
                            .font(.subheadline)
                            .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(GlowPalette.roseGold.opacity(0.6))
                        .font(.body.weight(.semibold))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(GlowPalette.softOverlay(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(GlowPalette.roseStroke(), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)

            if activePresets.isEmpty {
                Text("Once you have an analysis linked, smart presets will appear here.")
                    .font(.callout)
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GlowPalette.creamyWhite.opacity(0.05))
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
                                            .fill(isSelected ? GlowPalette.blushOverlay(0.35) : GlowPalette.softOverlay(0.8))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? GlowPalette.roseStroke(0.6) : GlowPalette.roseStroke(0.25), lineWidth: 1.2)
                                    )
                                    .foregroundStyle(GlowPalette.deepRose)
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
                            .foregroundStyle(GlowPalette.deepRose.opacity(0.7))

                        let recommended = preset.options.filter { $0.isRecommended }
                        let others = preset.options.filter { !$0.isRecommended }

                        if !recommended.isEmpty {
                            Text("Recommended")
                                .font(.glowSubheading)
                                .foregroundStyle(GlowPalette.deepRose.opacity(0.85))

                            LazyVStack(spacing: 12) {
                                ForEach(recommended, id: \.id) { option in
                                    PresetCard(category: preset.category, option: option) {
                                        Task {
                                            await viewModel.applyPreset(option, category: preset.category)
                                        }
                                    }
                                }
                            }
                        }

                        if !others.isEmpty {
                            Text(recommended.isEmpty ? "Options" : "More Options")
                                .font(.glowSubheading)
                                .foregroundStyle(GlowPalette.deepRose.opacity(0.85))
                                .padding(.top, recommended.isEmpty ? 0 : 8)

                            LazyVStack(spacing: 12) {
                                ForEach(others, id: \.id) { option in
                                    PresetCard(category: preset.category, option: option) {
                                        Task {
                                            await viewModel.applyPreset(option, category: preset.category)
                                        }
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
                .font(.glowSubheading)
                .deepRoseText()

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
                .background(GlowPalette.softOverlay(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(GlowPalette.roseStroke(0.35), lineWidth: 1)
                )
            } else {
                Text("Run a fresh analysis to unlock tailored presets and insights.")
                    .font(.callout)
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
                    .padding()
                    .background(GlowPalette.softOverlay(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(GlowPalette.roseStroke(0.25), lineWidth: 1)
                    )
            }
        }
    }

    private func insightRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(GlowPalette.creamyWhite.opacity(0.15))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.75))
                Text(value)
                    .font(.glowBody)
                    .deepRoseText()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 56))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.65))

            Text("Visualize Your Next Look")
                .font(.title2.weight(.bold))
                .deepRoseText()

            Text("Send a look from your analysis or upload a fresh photo to start transforming your glow story.")
                .font(.glowBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.75))
                .padding(.horizontal, 28)

            Button {
                viewModel.isPresentingImagePicker = true
            } label: {
                Label("Start Visualization", systemImage: "sparkles")
                    .font(.glowSubheading)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.94, green: 0.34, blue: 0.56))
                    )
                    .deepRoseText()
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
