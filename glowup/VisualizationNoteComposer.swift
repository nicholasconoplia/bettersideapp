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
        presetCategory: VisualizationPresetCategory?
    ) -> VisualizationNoteContent {
        let professional = category.professionalTitle.capitalized
        let summary = "Bring this look to your \(professional.lowercased())"

        var sections: [String] = []
        if let prompt, !prompt.isEmpty {
            sections.append("Inspiration cue: \(prompt.trimmingCharacters(in: .whitespacesAndNewlines)).")
        }

        if let analysis {
            sections.append(contentsOf: analysisHighlights(for: category, analysis: analysis))
        }

        if sections.isEmpty {
            sections.append("Capture reference photos of this AI look and show them to your \(professional.lowercased()).")
        }

        let detail = sections.joined(separator: " ")
        let keywords = buildKeywords(
            category: category,
            analysis: analysis,
            presetCategory: presetCategory,
            prompt: prompt
        )

        return VisualizationNoteContent(summary: summary, detail: detail, keywords: keywords)
    }

    private static func analysisHighlights(
        for category: VisualizationLookCategory,
        analysis: PhotoAnalysisVariables
    ) -> [String] {
        switch category {
        case .hair:
            var hints: [String] = []
            if let shape = analysis.faceShape {
                hints.append("Design the cut around a \(shape.lowercased()) face shape.")
            }
            if let palette = analysis.seasonalPalette {
                hints.append("Keep color placement harmonious with a \(palette.lowercased()) seasonal palette.")
            }
            if let hairColor = analysis.hairColor {
                hints.append("Current hair color: \(hairColor). Blend transitions smoothly.")
            }
            return hints
        case .makeup:
            var hints: [String] = []
            hints.append("Preferred makeup vibe: \(analysis.makeupStyle).")
            if let eye = analysis.eyeColor {
                hints.append("Play up \(eye.lowercased()) eyes with complementary tones.")
            }
            if let undertone = analysis.skinUndertone {
                hints.append("Skin undertone leans \(undertone.lowercased()); match base products accordingly.")
            }
            return hints
        case .outfit:
            var hints: [String] = []
            if let palette = analysis.seasonalPalette {
                hints.append("Stick to a \(palette.lowercased()) seasonal palette for fabrics.")
            }
            if !analysis.bestColors.isEmpty {
                let favorites = analysis.bestColors.prefix(3).joined(separator: ", ")
                hints.append("Hero colors: \(favorites).")
            }
            hints.append("Outfit vibe score: \(String(format: "%.1f", analysis.outfitColorMatch))/10 for color coordination.")
            return hints
        case .other:
            return [
                "Lean into poses and expression that scored \(String(format: "%.1f", analysis.poseNaturalness))/10 on naturalness.",
                "Overall glow score: \(String(format: "%.1f", analysis.overallGlowScore))/10."
            ]
        }
    }

    private static func buildKeywords(
        category: VisualizationLookCategory,
        analysis: PhotoAnalysisVariables?,
        presetCategory: VisualizationPresetCategory?,
        prompt: String?
    ) -> [String] {
        var keywords: Set<String> = []

        if let prompt {
            keywords.formUnion(prompt
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" })
                .map { String($0) }
                .filter { $0.count > 2 })
        }

        if let analysis {
            if let palette = analysis.seasonalPalette {
                keywords.insert("\(palette.lowercased()) palette")
            }
            keywords.formUnion(
                analysis.bestColors
                    .map { "\($0.lowercased()) outfit" }
            )
        }

        switch category {
        case .hair:
            keywords.insert("hair transformation")
            keywords.insert("salon inspiration")
        case .makeup:
            keywords.insert("makeup tutorial")
            keywords.insert("face chart")
        case .outfit:
            keywords.insert("wardrobe styling")
            keywords.insert("lookbook")
        case .other:
            keywords.insert("beauty inspo")
        }

        if let presetCategory {
            keywords.insert(presetCategory.displayName.lowercased())
        }

        return Array(keywords.prefix(8))
    }
}
