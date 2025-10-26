//
//  DiaryView.swift
//  glowup
//
//  Created by Codex on 26/11/2025.
//

import SwiftUI

struct DiaryView: View {
    @StateObject private var viewModel = DiaryViewModel()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            GlowGradient.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    editorCard
                    tagSelector
                    historySection
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 120)
            }

            addButton
        }
        .onAppear {
            viewModel.loadEntriesIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Diary")
                .font(GlowTypography.heading(34, weight: .bold))
                .foregroundStyle(GlowPalette.deepRose)
            Text("Reflect on your progress")
                .font(GlowTypography.body(16))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today’s reflection")
                .font(GlowTypography.body(16, weight: .semibold))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.8))

            ZStack(alignment: .topLeading) {
                if viewModel.activeEntryText.isEmpty {
                    Text("Write about today’s experience, mindset, or improvements.")
                        .font(GlowTypography.body(15))
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.4))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }

                TextEditor(text: viewModel.bindingForActiveEntryText)
                    .font(GlowTypography.body(15))
                    .foregroundColor(GlowPalette.deepRose)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .padding(12)
            .background(GlowPalette.creamyWhite)
            .cornerRadius(18)
        }
        .glowCard(cornerRadius: 22, padding: 20)
    }

    private var tagSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tag this entry")
                .font(GlowTypography.body(15, weight: .semibold))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.7))

            HStack(spacing: 10) {
                ForEach(DiaryTag.allCases) { tag in
                    Button {
                        viewModel.updateActiveTag(tag)
                    } label: {
                        Text(tag.displayName)
                            .font(GlowTypography.caption)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                Capsule()
                                    .fill(tag == viewModel.activeEntryTag ? GlowPalette.blushPink.opacity(0.35) : GlowPalette.softBeige.opacity(0.7))
                            )
                            .foregroundStyle(tag == viewModel.activeEntryTag ? GlowPalette.deepRose : GlowPalette.deepRose.opacity(0.7))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("History")
                .font(GlowTypography.body(16, weight: .semibold))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.8))

            if viewModel.entries.isEmpty {
                Text("Your reflections will live here. Add your first note to track how you feel over time.")
                    .font(GlowTypography.body(15))
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.5))
                    .padding(.top, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.entries) { entry in
                        Button {
                            viewModel.focus(on: entry)
                        } label: {
                            historyRow(for: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func historyRow(for entry: DiaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.title)
                    .font(GlowTypography.body(15, weight: .semibold))
                    .foregroundStyle(GlowPalette.deepRose)
                Spacer()
                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(GlowTypography.caption)
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.5))
            }
            if let tag = entry.tag {
                Text(tag.displayName)
                    .font(GlowTypography.caption)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(GlowPalette.softBeige.opacity(0.8))
                    .clipShape(Capsule())
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.75))
            }
            Text(entry.preview)
                .font(GlowTypography.body(14))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.65))
                .lineLimit(2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GlowPalette.creamyWhite)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(GlowPalette.roseGold.opacity(0.25))
        )
    }

    private var addButton: some View {
        Button {
            viewModel.createNewEntry()
        } label: {
            Label("Add New Note", systemImage: "plus")
                .font(GlowTypography.body(16, weight: .semibold))
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background(GlowPalette.blushPink)
                .foregroundStyle(GlowPalette.deepRose)
                .cornerRadius(24)
                .shadow(
                    color: GlowShadow.button.color,
                    radius: GlowShadow.button.radius,
                    x: GlowShadow.button.x,
                    y: GlowShadow.button.y
                )
        }
        .padding(.trailing, 24)
        .padding(.bottom, 32)
    }
}

// MARK: - View Model & Models

@MainActor
final class DiaryViewModel: ObservableObject {
    @Published var entries: [DiaryEntry] = []
    @Published private(set) var activeEntry: DiaryEntry?

    private let storageKey = "diary_entries_v1"
    private var autosaveTask: Task<Void, Never>?
    private var hasLoaded = false

    var activeEntryText: String {
        activeEntry?.content ?? ""
    }

    var activeEntryTag: DiaryTag? {
        activeEntry?.tag
    }

    var bindingForActiveEntryText: Binding<String> {
        Binding(
            get: { self.activeEntry?.content ?? "" },
            set: { newValue in
                self.activeEntry?.content = newValue
                self.scheduleAutosave()
            }
        )
    }

    func loadEntriesIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([DiaryEntry].self, from: data)
        else {
            createNewEntry()
            return
        }
        entries = decoded.sorted { $0.createdAt > $1.createdAt }
        if let first = entries.first {
            activeEntry = first
        } else {
            createNewEntry()
        }
    }

    func createNewEntry() {
        let entry = DiaryEntry(id: UUID(), content: "", tag: nil, createdAt: Date(), updatedAt: Date())
        entries.insert(entry, at: 0)
        activeEntry = entry
        persistEntries()
    }

    func focus(on entry: DiaryEntry) {
        activeEntry = entry
    }

    func updateActiveTag(_ tag: DiaryTag) {
        if activeEntry?.tag == tag {
            activeEntry?.tag = nil
        } else {
            activeEntry?.tag = tag
        }
        scheduleAutosave()
    }

    private func scheduleAutosave() {
        guard var entry = activeEntry else { return }
        entry.updatedAt = Date()
        activeEntry = entry

        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await self?.persistEntries()
        }
    }

    private func persistEntries() {
        guard let entry = activeEntry else { return }
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.insert(entry, at: 0)
        }
        entries.sort { $0.createdAt > $1.createdAt }
        saveToStorage()
    }

    private func saveToStorage() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    deinit {
        autosaveTask?.cancel()
    }
}

struct DiaryEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var content: String
    var tag: DiaryTag?
    var createdAt: Date
    var updatedAt: Date

    var title: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Untitled entry" }
        if let sentenceEnd = trimmed.firstIndex(where: { ".!?".contains($0) }) {
            return String(trimmed[..<sentenceEnd])
        }
        return trimmed.components(separatedBy: .newlines).first ?? "Reflection"
    }

    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Tap to add your thoughts." : trimmed
    }
}

enum DiaryTag: String, CaseIterable, Identifiable, Codable {
    case skincare
    case confidence
    case routine
    case mood

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .skincare: return "Skincare"
        case .confidence: return "Confidence"
        case .routine: return "Routine"
        case .mood: return "Mood"
        }
    }
}
