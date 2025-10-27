//
//  RoadmapWeekDetailView.swift
//  glowup
//
//  Created by Codex on 06/01/2026.
//

import SwiftUI

struct RoadmapWeekDetailView: View {
    let week: RoadmapViewModel.Week
    let onToggleTask: (RoadmapViewModel.Week.Task) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    summarySection
                    tasksSection
                }
                .padding(24)
            }
            .background(GradientBackground.twilightAura.ignoresSafeArea())
            .navigationTitle("Week \(week.number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .deepRoseText()
                }
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(week.title)
                    .font(.title2.bold())
                    .deepRoseText()
                Text(week.summary)
                    .font(.glowBody)
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Plan progress")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
                    Spacer()
                    Text("\(Int(round(week.progress * 100)))%")
                        .font(.caption.bold())
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.85))
                }
                ProgressView(value: week.progress)
                    .tint(GlowPalette.roseGold)
                    .tint(GlowPalette.roseGold)
            }

            if let lockMessage = week.lockMessage {
                HStack(spacing: 8) {
                    Image(systemName: week.subscriptionLocked ? "crown.fill" : "lock.fill")
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.75))
                    Text(lockMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.75))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(GlowPalette.creamyWhite.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(GlowPalette.creamyWhite.opacity(0.12))
        )
    }

    @ViewBuilder
    private var tasksSection: some View {
        if week.tasks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("No actions yet")
                    .font(.glowSubheading)
                    .deepRoseText()
                Text("Generate a fresh photo analysis to unlock a personalized plan for this focus.")
                    .font(.subheadline)
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(GlowPalette.creamyWhite.opacity(0.08))
            )
        } else {
            VStack(alignment: .leading, spacing: 18) {
                Text("Action plan")
                    .font(.glowSubheading)
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.85))

                ForEach(week.tasks) { task in
                    VStack(alignment: .leading, spacing: 10) {
                        RoadmapTaskRow(
                            task: task,
                            onToggle: { onToggleTask(task) },
                            onTap: nil,
                            maxBodyLines: nil
                        )

                        if !task.productSuggestions.isEmpty {
                            suggestionList(for: task)
                        }
                    }
                }

                Text("Check off each action, then rescan to unlock Week \(week.number + 1).")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.65))
                    .padding(.top, 4)
            }
        }
    }

    private func suggestionList(for task: RoadmapViewModel.Week.Task) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try searching:")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.65))
            ForEach(task.productSuggestions, id: \.self) { suggestion in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.glowBody)
                        .foregroundStyle(Color(red: 1.0, green: 0.7, blue: 0.88))
                    Text(suggestion)
                        .font(.glowBody)
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(GlowPalette.creamyWhite.opacity(0.18), lineWidth: 1)
        )
    }
}
