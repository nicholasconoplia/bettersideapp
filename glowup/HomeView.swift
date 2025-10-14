//
//  HomeView.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import SwiftUI
import UIKit

struct HomeView: View {
    @Binding var selection: GlowTab

    @EnvironmentObject private var appModel: AppModel
    @FetchRequest(
        entity: PhotoSession.entity(),
        sortDescriptors: [NSSortDescriptor(key: "startTime", ascending: false)],
        predicate: nil,
        animation: .easeInOut
    ) private var recentSessions: FetchedResults<PhotoSession>

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground.primary
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 28) {
                        greetingHeader
                        heroCTA
                        recentSessionsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hey \(greetingName)!")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Ready to glow? Upload a fresh photo or review your recent analyses below.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
    }

    private var heroCTA: some View {
        Button {
            selection = .coach
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text("Analyze a Photo")
                    .font(.title2.bold())
                Text("Upload a snapshot and get instant coaching on light, angles, and vibe.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                HStack {
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.52, blue: 0.71),
                        Color(red: 0.76, green: 0.38, blue: 0.86)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 18, y: 10)
            .foregroundStyle(.white)
        }
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if !recentSessions.isEmpty {
                    Button {
                        selection = .results
                    } label: {
                        HStack(spacing: 6) {
                            Text("View All")
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
            
            if recentSessions.isEmpty {
                Text("Your glow journey starts with your first analysis. Tap “Analyze a Photo” to begin.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                VStack(spacing: 14) {
                    let sessionsToShow = Array(recentSessions.prefix(5))
                    ForEach(Array(sessionsToShow.enumerated()), id: \.element.objectID) { index, session in
                        if index > 0 {
                            Divider()
                                .overlay(Color.white.opacity(0.1))
                        }
                        sessionRow(for: session)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private func sessionRow(for session: PhotoSession) -> some View {
        HStack(alignment: .center, spacing: 16) {
            sessionThumbnail(for: session)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(session.sessionType ?? "Static Photo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(relativeDateString(for: session.startTime))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                if let summary = session.aiSummary {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                }

                let confidence = session.confidenceScore
                if confidence > 0 {
                    Text("Glow score \(Int(confidence * 100))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            Button {
                selection = .results
            } label: {
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(8)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func sessionThumbnail(for session: PhotoSession) -> some View {
        Group {
            if let image = session.uploadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.18)
                    Image(systemName: "camera.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(width: 68, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
    }

    private var greetingName: String {
        if let rawName = appModel.latestQuiz?.userName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawName.isEmpty {
            return rawName
        }
        if let persona = appModel.userSettings?.coachPersonaID,
           let coach = CoachPersona(rawValue: persona) {
            switch coach {
            case .bestie:
                return "Bestie"
            case .director:
                return "Muse"
            case .zenGuru:
                return "Glowbabe"
            }
        }
        return "Glow friend"
    }

    private func relativeDateString(for date: Date?) -> String {
        guard let date else { return "—" }
        return HomeView.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}
