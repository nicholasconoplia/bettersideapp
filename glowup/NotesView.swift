//
//  NotesView.swift
//  glowup
//
//  Displays saved visualization notes for real-world appointments.
//

import CoreData
import SwiftUI

struct NotesView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        entity: VisualizationNote.entity(),
        sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
        animation: .easeInOut
    ) private var notes: FetchedResults<VisualizationNote>

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground.primary
                    .ignoresSafeArea()

                if notes.isEmpty {
                    emptyState
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
                        .padding(.horizontal, 18)
                        .padding(.top, 28)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Notes")
            .navigationDestination(for: NSManagedObjectID.self) { objectID in
                if let note = fetchNote(with: objectID) {
                    VisualizationNoteDetailView(note: note)
                } else {
                    Text("Note not found.")
                        .deepRoseText()
                }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(GradientBackground.primary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func fetchNote(with id: NSManagedObjectID) -> VisualizationNote? {
        try? context.existingObject(with: id) as? VisualizationNote
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

    private var emptyState: some View {
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

    private static let noteDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

extension NotesView {
    private func delete(_ note: VisualizationNote) {
        context.delete(note)
        do {
            try context.save()
        } catch {
            print("[NotesView] Failed to delete note: \(error.localizedDescription)")
        }
    }
}

struct VisualizationNoteDetailView: View {
    let note: VisualizationNote

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let image = note.renderedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(GlowPalette.creamyWhite.opacity(0.16), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 22, y: 14)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Professional Brief", systemImage: "doc.richtext")
                        .font(.glowSubheading)
                        .deepRoseText()
                    Text(note.detail ?? "")
                        .font(.glowBody)
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.85))
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .background(GlowPalette.creamyWhite.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                if !note.keywordList.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Pinterest Keywords", systemImage: "sparkles.tv.fill")
                            .font(.glowSubheading)
                            .deepRoseText()
                        FlexibleKeywordGrid(keywords: note.keywordList)
                    }
                    .padding()
                    .background(GlowPalette.creamyWhite.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 30)
        }
        .background(GradientBackground.primary.ignoresSafeArea())
        .navigationTitle(note.lookCategory.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FlexibleKeywordGrid: View {
    let keywords: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
            ForEach(keywords, id: \.self) { keyword in
                if let url = pinterestURL(for: keyword) {
                    Link(destination: url) {
                        Text(keyword)
                            .font(.caption.weight(.semibold))
                            .deepRoseText()
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(GlowPalette.creamyWhite.opacity(0.14))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(keyword)
                        .font(.caption.weight(.semibold))
                        .deepRoseText()
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(GlowPalette.creamyWhite.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func pinterestURL(for keyword: String) -> URL? {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.pinterest.com/search/pins/?q=\(query)&rs=typed"
        return URL(string: urlString)
    }
}
