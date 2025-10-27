//
//  RoadmapWeekCard.swift
//  glowup
//
//  Created by Codex on 02/11/2025.
//

import SwiftUI

struct RoadmapWeekCard: View {
    enum LockReason {
        case future
        case subscription
    }

    let week: RoadmapViewModel.Week
    let onOpenDetail: () -> Void
    let onLockedTap: (LockReason) -> Void

    private let accentColor = Color(red: 0.94, green: 0.34, blue: 0.56)
    private let gradient = LinearGradient(
        colors: [
            Color(red: 0.94, green: 0.34, blue: 0.56),
            Color(red: 1.0, green: 0.6, blue: 0.78)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        let futureLocked = !week.isUnlocked
        let subscriptionLocked = week.subscriptionLocked
        let isLocked = futureLocked || subscriptionLocked

        VStack(alignment: .leading, spacing: 20) {
            header

            Text(week.summary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.78))

            if week.isUnlocked && !week.tasks.isEmpty {
                highlightList
            }

            if week.isUnlocked && !week.tasks.isEmpty {
                progressBar
            }

            if let lockMessage = week.lockMessage {
                lockBanner(message: lockMessage)
            }

            callToAction(isLocked: isLocked)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(GlowPalette.softOverlay(week.isCurrent ? 0.9 : 0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    week.isCurrent ? AnyShapeStyle(gradient) : AnyShapeStyle(GlowPalette.roseStroke(week.isCompleted ? 0.45 : 0.25)),
                    lineWidth: week.isCurrent ? 2 : 1
                )
        )
        .overlay(alignment: .topTrailing) {
            if week.isCompleted {
                Label("Completed", systemImage: "checkmark.seal.fill")
                    .font(.caption.bold())
                    .deepRoseText()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(accentColor.opacity(0.75))
                    )
                    .padding(14)
            } else if !week.isUnlocked || week.subscriptionLocked {
                Image(systemName: week.subscriptionLocked ? "crown.fill" : "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
                    .padding(14)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "chevron.right.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.65))
                .padding(18)
        }
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            if isLocked {
                onLockedTap(subscriptionLocked ? .subscription : .future)
            } else {
                onOpenDetail()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Week \(week.number)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GlowPalette.deepRose.opacity(0.85))
                    if week.isCurrent {
                        Text("Current focus")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(GlowPalette.creamyWhite.opacity(0.16))
                            .clipShape(Capsule())
                    }
                }
                Text(week.title)
                    .font(.title3.bold())
                    .deepRoseText()
            }
            Spacer()
            Text("\(Int(round(week.progress * 100)))%")
                .font(.caption.bold())
                .foregroundStyle(GlowPalette.deepRose.opacity(0.85))
        }
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Progress")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.65))
                Spacer()
                Text("\(Int(round(week.progress * 100)))%")
                    .font(.footnote.bold())
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.85))
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(GlowPalette.creamyWhite.opacity(0.12))
                    Capsule()
                        .fill(gradient)
                        .frame(width: max(0, geometry.size.width * min(1, CGFloat(week.progress))))
                }
            }
            .frame(height: 10)
        }
    }

    private var highlightList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(week.tasks.prefix(2))) { task in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(task.isCompleted ? accentColor : GlowPalette.creamyWhite.opacity(0.5))
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.subheadline.weight(.semibold))
                            .deepRoseText()
                        Text(task.timeframe)
                            .font(.glowBody)
                            .foregroundStyle(GlowPalette.deepRose.opacity(0.6))
                    }
                }
            }
            if week.tasks.count > 2 {
                Text("+ \(week.tasks.count - 2) more actions inside →")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GlowPalette.deepRose.opacity(0.65))
            }
        }
    }

    private func lockBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: week.subscriptionLocked ? "crown.fill" : "lock.fill")
                .foregroundStyle(GlowPalette.deepRose.opacity(0.75))
            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(GlowPalette.deepRose.opacity(0.75))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(GlowPalette.creamyWhite.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func callToAction(isLocked: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isLocked ? "lock" : "sparkles")
                .font(.subheadline.weight(.semibold))
            Text(isLocked ? "Unlock to view the detailed plan" : "Tap to open this week's action plan")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(GlowPalette.deepRose.opacity(0.85))
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(GlowPalette.softOverlay(0.85))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(GlowPalette.roseStroke(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
