//
//  RoadmapTaskRow.swift
//  glowup
//
//  Created by Codex on 02/11/2025.
//

import SwiftUI

struct RoadmapTaskRow: View {
    let task: RoadmapViewModel.Week.Task
    let onToggle: () -> Void
    let onTap: (() -> Void)?
    let maxBodyLines: Int?

    private let accentColor = Color(red: 0.94, green: 0.34, blue: 0.56)

    init(
        task: RoadmapViewModel.Week.Task,
        onToggle: @escaping () -> Void,
        onTap: (() -> Void)? = nil,
        maxBodyLines: Int? = 3
    ) {
        self.task = task
        self.onToggle = onToggle
        self.onTap = onTap
        self.maxBodyLines = maxBodyLines
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    onToggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(task.isCompleted ? accentColor.opacity(0.28) : Color.white.opacity(0.08))
                        .frame(width: 36, height: 36)
                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(task.subscriptionLocked)

            VStack(alignment: .leading, spacing: 8) {
                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)

                Text(task.body)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(maxBodyLines)

                HStack(spacing: 10) {
                    Label(task.category.uppercased(), systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentColor.opacity(0.85))
                    Divider()
                        .frame(height: 12)
                        .background(Color.white.opacity(0.3))
                    Text(task.timeframe)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer(minLength: 8)
            if onTap != nil {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.3))
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(task.isCompleted ? 0.06 : 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(task.isCompleted ? accentColor.opacity(0.25) : Color.clear, lineWidth: 1)
        )
        .opacity(task.subscriptionLocked ? 0.5 : 1.0)
        .onTapGesture {
            onTap?()
        }
    }
}
