//
//  DiaryView.swift
//  glowup
//
//  Created by Codex on 26/11/2025.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DiaryView: View {
    @StateObject private var viewModel = DiaryViewModel()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            GlowGradient.canvas
                .ignoresSafeArea()

            List {
                Section {
                    header
                        .listRowInsets(EdgeInsets(top: 28, leading: 24, bottom: 12, trailing: 24))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    editorCard
                        .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 16, trailing: 24))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    tagSelector
                        .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 16, trailing: 24))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    historySectionContent
                } header: {
                    Text("History")
                        .font(GlowTypography.body(16, weight: .semibold))
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
                        .padding(.leading, 24)
                        .textCase(nil)
                }

                if !viewModel.recentlyDeleted.isEmpty {
                    Section {
                        recentlyDeletedSectionContent
                    } header: {
                        Text("Recently Deleted")
                            .font(GlowTypography.body(16, weight: .semibold))
                            .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
                            .padding(.leading, 24)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listSectionSeparator(.hidden)
            .listRowSeparator(.hidden)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 110)
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

    @ViewBuilder
    private var historySectionContent: some View {
        if viewModel.entries.isEmpty {
            Text("Your reflections will live here. Add your first note to track how you feel over time.")
                .font(GlowTypography.body(15))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.5))
                .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 24, trailing: 24))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        } else {
            ForEach(viewModel.entries) { entry in
                Button {
                    viewModel.focus(on: entry)
                } label: {
                    historyRow(for: entry)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 12, trailing: 24))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteEntries)
        }
    }

    @ViewBuilder
    private var recentlyDeletedSectionContent: some View {
        ForEach(viewModel.recentlyDeleted) { entry in
            recentlyDeletedRow(for: entry)
                .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 12, trailing: 24))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) {
                        viewModel.permanentlyRemoveFromRecentlyDeleted(entry)
                    }
                    Button("Restore") {
                        viewModel.restore(entry)
                    }
                    .tint(GlowPalette.blushPink)
                }
        }
    }

    private func recentlyDeletedRow(for entry: DiaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.title)
                    .font(GlowTypography.body(15, weight: .semibold))
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
                Spacer()
                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(GlowTypography.caption)
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.4))
            }
            Text(entry.preview)
                .font(GlowTypography.body(14))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.55))
                .lineLimit(2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GlowPalette.deepRose.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(GlowPalette.deepRose.opacity(0.08))
        )
    }

    private func deleteEntries(at offsets: IndexSet) {
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.deleteEntries(at: offsets)
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
    @Published var recentlyDeleted: [DiaryEntry] = []
    @Published private(set) var activeEntry: DiaryEntry?

    private let storageKey = "diary_entries_v1"
    private let recentlyDeletedKey = "diary_entries_recently_deleted_v1"
    private let maxRecentlyDeleted = 20
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
            loadRecentlyDeletedFromStorage()
            return
        }
        entries = decoded.sorted { $0.createdAt > $1.createdAt }
        loadRecentlyDeletedFromStorage()
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

    func delete(_ entry: DiaryEntry) {
        guard let removed = entries.first(where: { $0.id == entry.id }) else { return }
        entries.removeAll { $0.id == entry.id }
        moveToRecentlyDeleted(removed)
        if activeEntry?.id == entry.id {
            activeEntry = entries.first
        }
        saveToStorage()
    }

    func deleteEntries(at offsets: IndexSet) {
        let sortedOffsets = offsets.sorted(by: >)
        var removedEntries: [DiaryEntry] = []
        for index in sortedOffsets {
            guard entries.indices.contains(index) else { continue }
            let entry = entries.remove(at: index)
            removedEntries.append(entry)
        }

        removedEntries.forEach { moveToRecentlyDeleted($0) }

        if let currentID = activeEntry?.id, removedEntries.contains(where: { $0.id == currentID }) {
            activeEntry = entries.first
        }

        if entries.isEmpty {
            createNewEntry()
        } else {
            saveToStorage()
        }

#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
#endif
    }

    func updateActiveTag(_ tag: DiaryTag) {
        if activeEntry?.tag == tag {
            activeEntry?.tag = nil
        } else {
            activeEntry?.tag = tag
        }
        scheduleAutosave()
    }

    func restore(_ entry: DiaryEntry) {
        guard let index = recentlyDeleted.firstIndex(of: entry) else { return }
        var restored = recentlyDeleted.remove(at: index)
        restored.updatedAt = Date()
        entries.insert(restored, at: 0)
        activeEntry = restored
        persistEntries()
    }

    private func moveToRecentlyDeleted(_ entry: DiaryEntry) {
        recentlyDeleted.removeAll { $0.id == entry.id }
        var updatedEntry = entry
        updatedEntry.updatedAt = Date()
        recentlyDeleted.insert(updatedEntry, at: 0)
        if recentlyDeleted.count > maxRecentlyDeleted {
            recentlyDeleted = Array(recentlyDeleted.prefix(maxRecentlyDeleted))
        }
    }

    func permanentlyRemoveFromRecentlyDeleted(_ entry: DiaryEntry) {
        recentlyDeleted.removeAll { $0.id == entry.id }
        saveToStorage()
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
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
        let defaults = UserDefaults.standard
        defaults.set(data, forKey: storageKey)
        if let deletedData = try? JSONEncoder().encode(recentlyDeleted) {
            defaults.set(deletedData, forKey: recentlyDeletedKey)
        }
    }

    private func loadRecentlyDeletedFromStorage() {
        guard
            let data = UserDefaults.standard.data(forKey: recentlyDeletedKey),
            let decoded = try? JSONDecoder().decode([DiaryEntry].self, from: data)
        else {
            recentlyDeleted = []
            return
        }
        recentlyDeleted = decoded
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
