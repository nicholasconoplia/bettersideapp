//
//  DashboardView.swift
//  glowup
//
//  Created by Codex on 26/11/2025.
//

import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#endif

struct DashboardView: View {
    @Binding var selection: GlowTab

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        entity: PhotoSession.entity(),
        sortDescriptors: [NSSortDescriptor(key: "startTime", ascending: false)],
        animation: .easeInOut
    ) private var recentSessions: FetchedResults<PhotoSession>

    @FetchRequest(
        entity: DailyStreak.entity(),
        sortDescriptors: [],
        animation: .easeInOut
    ) private var streakRecords: FetchedResults<DailyStreak>

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    @State private var isPresentingNameEditor = false
    @State private var nameEditorInitialValue: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                GlowGradient.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        header
                        profileStrip
                        quickActionButtons
                        if let analysis = latestAnalysis {
                            latestAnalysisCard(for: analysis)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selection = .analyze
                                }
                        }
                        recentActivitySection
                        streakFooter
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 36)
                    .padding(.bottom, 48)
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $isPresentingNameEditor) {
            NameEditorSheet(
                originalName: nameEditorInitialValue,
                onSave: { newValue in
                    appModel.updateUserName(newValue)
                }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dashboard")
                .font(GlowTypography.heading(34, weight: .bold))
                .foregroundStyle(GlowPalette.deepRose)
            Text("Good to see you, \(displayName). Let’s keep the momentum going.")
                .font(GlowTypography.body(15))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var profileStrip: some View {
        VStack(spacing: 16) {
            avatarView
                .frame(width: 96, height: 96)
                .shadow(
                    color: GlowShadow.soft.color,
                    radius: GlowShadow.soft.radius,
                    x: GlowShadow.soft.x,
                    y: GlowShadow.soft.y
                )

            VStack(spacing: 6) {
                Button {
                    nameEditorInitialValue = appModel.latestQuiz?.userName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    isPresentingNameEditor = true
                } label: {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(GlowTypography.heading(24, weight: .semibold))
                            .foregroundStyle(GlowPalette.deepRose)
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(GlowPalette.roseGold.opacity(0.8))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(GlowPalette.creamyWhite.opacity(0.35))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit name")

                Text("Level \(levelInfo.level)")
                    .font(GlowTypography.body(15, weight: .medium))
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
            }

            VStack(spacing: 8) {
                ProgressView(value: levelInfo.progress)
                    .tint(GlowPalette.blushPink)
                    .background(GlowPalette.creamyWhite.opacity(0.6))
                    .clipShape(Capsule())
                Text(xpLabel)
                    .font(GlowTypography.caption)
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(GlowPalette.softBeige)
        .cornerRadius(24)
        .shadow(
            color: GlowShadow.soft.color,
            radius: GlowShadow.soft.radius,
            x: GlowShadow.soft.x,
            y: GlowShadow.soft.y
        )
    }

    private var quickActionButtons: some View {
        VStack(spacing: 16) {
            Text("Quick Actions")
                .font(GlowTypography.body(17, weight: .semibold))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                Button {
                    selection = .roadmap
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Start Today’s Tasks")
                                .font(GlowTypography.body(17, weight: .semibold))
                            Text("Jump straight into your personalized checklist.")
                                .font(GlowTypography.caption)
                                .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .padding(.horizontal, 18)
                }
                .glowRoundedButtonBackground(isEnabled: true)

                Button {
                    selection = .visualize
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Visualise a New Look")
                                .font(GlowTypography.body(17, weight: .semibold))
                            Text("Try outfits, makeup, and hair with instant previews.")
                                .font(GlowTypography.caption)
                                .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
                        }
                        Spacer()
                        Image(systemName: "wand.and.stars")
                    }
                    .padding(.horizontal, 18)
                }
                .glowSecondaryButtonBackground()
            }
        }
    }

    private func latestAnalysisCard(for analysis: DetailedPhotoAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Latest Glow Analysis")
                    .font(GlowTypography.body(17, weight: .semibold))
                    .foregroundStyle(GlowPalette.deepRose)
                Spacer()
                if let score = analysisScore {
                    Text(score)
                        .font(GlowTypography.body(17, weight: .semibold))
                        .foregroundStyle(GlowPalette.deepRose)
                }
            }

            if let summary = analysis.summary.split(separator: ".").first {
                Text(String(summary) + ".")
                    .font(GlowTypography.body(15))
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
            }

            if let quickWins = analysis.variables.quickWins.first {
                Divider()
                    .background(GlowPalette.roseGold.opacity(0.25))
                Text("Next Focus")
                    .font(GlowTypography.body(14, weight: .semibold))
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
                Text(quickWins)
                    .font(GlowTypography.body(15))
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.8))
            }
        }
        .glowCard()
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(GlowTypography.body(17, weight: .semibold))
                    .foregroundStyle(GlowPalette.deepRose)
                Spacer()
                if !recentSessions.isEmpty {
                    Button("See all") {
                        selection = .analyze
                    }
                    .font(GlowTypography.caption)
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.65))
                }
            }

            if recentSessions.isEmpty {
                Text("Upload your first analysis to start building momentum.")
                    .font(GlowTypography.body(15))
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
            } else {
                VStack(spacing: 12) {
                    ForEach(recentSessions.prefix(3), id: \.objectID) { session in
                        recentSessionRow(for: session)
                    }
                }
            }
        }
    }

    private func recentSessionRow(for session: PhotoSession) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(GlowPalette.blushPink.opacity(0.35))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "camera.aperture")
                        .font(.glowHeading)
                        .foregroundStyle(GlowPalette.deepRose)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(sessionLabel(for: session))
                    .font(GlowTypography.body(15, weight: .semibold))
                    .foregroundStyle(GlowPalette.deepRose)
                Text(Self.relativeFormatter.localizedString(for: session.startTime ?? Date(), relativeTo: Date()))
                    .font(GlowTypography.caption)
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.4))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GlowPalette.softBeige.opacity(0.8))
        )
    }

    private var streakFooter: some View {
        VStack(spacing: 12) {
            Divider()
                .background(GlowPalette.roseGold.opacity(0.3))
            Text("Streak: \(streakCount) day\(streakCount == 1 ? "" : "s") • Last completed: \(lastCompletedLabel)")
                .font(GlowTypography.caption)
                .foregroundStyle(GlowPalette.deepRose.opacity(0.65))
                .frame(maxWidth: .infinity, alignment: .leading)
            ProgressView(value: streakProgress)
                .tint(GlowPalette.blushPink)
                .background(GlowPalette.creamyWhite.opacity(0.6))
                .clipShape(Capsule())
        }
    }

    // MARK: - Helpers

    private var displayName: String {
        let raw = appModel.latestQuiz?.userName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw?.isEmpty == false ? raw! : "GlowFriend"
    }

    private var initials: String {
        let components = displayName.split(separator: " ").map { String($0.prefix(1)) }
        return components.prefix(2).joined()
    }

    private var avatarImage: UIImage? {
        recentSessions.first?.uploadedImage
    }

    private var avatarView: some View {
        Group {
            if let image = avatarImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(GlowPalette.blushPink.opacity(0.4))
                    .overlay {
                        Text(initials.isEmpty ? "G" : initials.uppercased())
                            .font(GlowTypography.heading(24, weight: .bold))
                            .foregroundStyle(GlowPalette.deepRose)
                    }
            }
        }
    }

    private var levelInfo: (level: Int, progress: Double) {
        let completed = recentSessions.count
        let level = max(1, completed / 4 + 1)
        let progress = Double(completed % 4) / 4.0
        return (level, progress)
    }

    private var xpLabel: String {
        let progressPercent = Int(levelInfo.progress * 100)
        return "\(progressPercent)% of next level"
    }

    private var latestAnalysis: DetailedPhotoAnalysis? {
        recentSessions.first?.decodedAnalysis
    }

    private var analysisScore: String? {
        guard let score = latestAnalysis?.variables.overallGlowScore else { return nil }
        return String(format: "%.1f / 10", score)
    }

    private var streakCount: Int {
        Int(streakRecords.first?.currentCount ?? 0)
    }

    private var lastCompletedLabel: String {
        guard let date = appModel.userSettings?.lastSessionDate else {
            return "Not yet"
        }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private var streakProgress: Double {
        let goal = 7.0
        return min(Double(streakCount) / goal, 1.0)
    }

    private func sessionLabel(for session: PhotoSession) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: session.startTime ?? Date())
    }

    private struct NameEditorSheet: View {
        let originalName: String
        let onSave: (String) -> Void

        @State private var name: String
        @Environment(\.dismiss) private var dismiss
        @FocusState private var isNameFieldFocused: Bool

        init(originalName: String, onSave: @escaping (String) -> Void) {
            self.originalName = originalName
            self.onSave = onSave
            _name = State(initialValue: originalName)
        }

        var body: some View {
            NavigationStack {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Update your name")
                            .font(GlowTypography.heading(24, weight: .bold))
                            .foregroundStyle(GlowPalette.deepRose)

                        TextField("Your name", text: $name)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .focused($isNameFieldFocused)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(GlowPalette.softBeige)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(GlowPalette.roseGold.opacity(0.3), lineWidth: 1)
                            )

                        Text("Leave blank to use the default greeting.")
                            .font(GlowTypography.caption)
                            .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
                    }

                    Spacer(minLength: 0)

                    Button {
                        onSave(name)
                        dismiss()
                    } label: {
                        Text("Save")
                            .font(GlowTypography.button)
                            .frame(maxWidth: .infinity)
                    }
                    .glowRoundedButtonBackground(isEnabled: canSave)
                    .disabled(!canSave)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(GlowGradient.canvas.ignoresSafeArea())
                .navigationTitle("Edit Name")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .presentationDetents([.fraction(0.35), .large])
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isNameFieldFocused = true
                }
            }
        }

        private var canSave: Bool {
            name.trimmingCharacters(in: .whitespacesAndNewlines)
                != originalName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
