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
                    NoteDetailView(note: note)
                } else {
                    Text("Note not found.")
                        .foregroundStyle(.white)
                }
            }
        }
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
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(note.summary ?? "Favorite Look")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(note.detail ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(3)

                HStack(spacing: 8) {
                    Label(note.lookCategory.displayName, systemImage: "tag.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())

                    Text((note.createdAt ?? Date()), formatter: Self.noteDateFormatter)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 58))
                .foregroundStyle(.white.opacity(0.7))
            Text("Save Your Favorites")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Tap \"I Like This Look\" in Visualize to pin detailed instructions, pro-ready notes, and image references right here.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
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

private struct NoteDetailView: View {
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
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 22, y: 14)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Professional Brief", systemImage: "doc.richtext")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(note.detail ?? "")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                if !note.keywordList.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Pinterest Keywords", systemImage: "sparkles.tv.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                        FlexibleKeywordGrid(keywords: note.keywordList)
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
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
                Text(keyword)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())
            }
        }
    }
}
