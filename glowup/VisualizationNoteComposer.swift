//
//  VisualizationNoteComposer.swift
//  glowup
//
//  Generates descriptive guidance and keywords for liked looks.
//

import Foundation

struct VisualizationNoteContent {
    let summary: String
    let detail: String
    let keywords: [String]
}

enum VisualizationNoteComposer {
    static func compose(
        category: VisualizationLookCategory,
        prompt: String?,
        analysis: PhotoAnalysisVariables?,
        presetCategory: VisualizationPresetCategory?,
        presetOption: VisualizationPresetOption?,
        lookDescription: LookDescription?
    ) -> VisualizationNoteContent {
        let professional = category.professionalTitle.lowercased()
        let focusTitle: String? = {
            if let look = lookDescription {
                let title = look.styleName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty { return title }
            }
            if let option = presetOption {
                let title = option.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty { return title }
            }
            return nil
        }()
        let summary: String
        if let focusTitle {
            summary = "\(focusTitle) for your \(professional)"
        } else {
            summary = "Bring this look to your \(professional)"
        }

        let detailLines = makeDetailLines(
            category: category,
            prompt: prompt,
            analysis: analysis,
            presetOption: presetOption,
            lookDescription: lookDescription
        )
        let formattedDetail: String
        if detailLines.isEmpty {
            formattedDetail = "Capture this AI-rendered look from multiple angles and show it to your \(professional)."
        } else {
            formattedDetail = detailLines
                .map { "• \($0.ensureSentence())" }
                .joined(separator: "\n")
        }

        let keywords = buildKeywords(
            category: category,
            analysis: analysis,
            presetCategory: presetCategory,
            prompt: prompt,
            presetOption: presetOption,
            lookDescription: lookDescription
        )

        return VisualizationNoteContent(summary: summary, detail: formattedDetail, keywords: keywords)
    }

    private static func makeDetailLines(
        category: VisualizationLookCategory,
        prompt: String?,
        analysis: PhotoAnalysisVariables?,
        presetOption: VisualizationPresetOption?,
        lookDescription: LookDescription?
    ) -> [String] {
        var lines: [String] = []

        if let look = lookDescription {
            let request = look.whatToRequest.trimmingCharacters(in: .whitespacesAndNewlines)
            if !request.isEmpty {
                lines.append(request)
            }
            lines.append(contentsOf: look.combinedNotes)
        } else if let option = presetOption {
            let baseInstruction = option.noteDetail?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let instruction = baseInstruction, !instruction.isEmpty {
                lines.append("\(option.title): \(instruction)")
            } else {
                lines.append("Ask for \(option.title) by name.")
            }
        }

        switch category {
        case .hair:
            if let shape = analysis?.faceShape {
                lines.append("Tailor the finish to flatter a \(shape.lowercased()) face shape.")
            }
            if let color = analysis?.hairColor {
                lines.append("Blend the style with your current \(color.lowercased()) so the grow-out stays seamless.")
            }
            if let palette = analysis?.seasonalPalette {
                lines.append("Keep tone and shine aligned with the \(palette.lowercased()) palette.")
            }
        case .makeup:
            if let style = analysis?.makeupStyle, !style.isEmpty {
                lines.append("Overall vibe: \(style). Build the look with that finish in mind.")
            }
            if let eye = analysis?.eyeColor {
                lines.append("Accent \(eye.lowercased()) eyes with tones that mirror this render.")
            }
            if let undertone = analysis?.skinUndertone {
                lines.append("Match base products to your \(undertone.lowercased()) undertone.")
            }
        case .outfit:
            if let palette = analysis?.seasonalPalette {
                lines.append("Stay within the \(palette.lowercased()) seasonal palette for fabrics and accessories.")
            }
            if let colors = analysis?.bestColors, !colors.isEmpty {
                lines.append("Hero colors from your analysis: \(colors.prefix(3).joined(separator: ", ")).")
            }
        case .other:
            if let analysis {
                lines.append("Pose naturally—your pose score is \(String(format: "%.1f", analysis.poseNaturalness))/10.")
                lines.append("Overall glow score: \(String(format: "%.1f", analysis.overallGlowScore))/10.")
            }
        }

        if let prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, presetOption == nil, lookDescription == nil {
            lines.append("Inspiration cue: \(prompt.trimmingCharacters(in: .whitespacesAndNewlines)).")
        }

        return lines
    }

    private static func buildKeywords(
        category: VisualizationLookCategory,
        analysis: PhotoAnalysisVariables?,
        presetCategory: VisualizationPresetCategory?,
        prompt: String?,
        presetOption: VisualizationPresetOption?,
        lookDescription: LookDescription?
    ) -> [String] {
        var list: [String] = []
        var seen: Set<String> = []

        func append(_ keyword: String) {
            let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let normalized = trimmed.lowercased()
            if seen.insert(normalized).inserted {
                list.append(trimmed.capitalized)
            }
        }

        if let option = presetOption {
            append(option.title)
            switch category {
            case .hair:
                append("\(option.title) hairstyle")
            case .makeup:
                append("\(option.title) makeup")
            case .outfit:
                append("\(option.title) outfit")
            case .other:
                break
            }
        }

        if let look = lookDescription {
            append(look.styleName)
            look.pinterestKeywords.forEach { append($0) }
        }

        if let analysis {
            if let palette = analysis.seasonalPalette {
                append("\(palette) palette")
            }
            if category == .outfit || category == .hair {
                analysis.bestColors.forEach { append("\($0) color story") }
            }
            if category == .hair, let hairColor = analysis.hairColor {
                append("\(hairColor) hair")
            }
        }

        if let presetCategory {
            append(presetCategory.displayName)
        }

        if let prompt {
            prompt
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" })
                .map { String($0) }
                .filter { $0.count > 3 }
                .forEach { append($0) }
        }

        switch category {
        case .hair:
            append("Hair inspiration")
            append("Salon reference")
        case .makeup:
            append("Makeup tutorial")
        case .outfit:
            append("Wardrobe styling")
        case .other:
            append("Beauty inspo")
        }

        return Array(list.prefix(8))
    }
}

private extension String {
    func ensureSentence() -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if let last = trimmed.last, ".!?".contains(last) {
            return trimmed
        }
        return "\(trimmed)."
    }
}
