//
//  CoachPersona.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import Foundation

enum CoachPersona: String, CaseIterable, Identifiable {
    case bestie
    case director
    case zenGuru

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bestie:
            return "Bestie"
        case .director:
            return "Creative Director"
        case .zenGuru:
            return "Zen Glow Guru"
        }
    }

    var tagline: String {
        switch self {
        case .bestie:
            return "Hype-heavy, emoji-packed, and full of sparkles."
        case .director:
            return "Precise, art-directing feedback with high-fashion energy."
        case .zenGuru:
            return "Grounded affirmations that keep the glow calm and confident."
        }
    }

    var systemPrompt: String {
        switch self {
        case .bestie:
            return "You are the user's glam best friend: affirming, slang-forward, and celebratory."
        case .director:
            return "You are a sharp-eyed creative director: concise, detail-obsessed, and fashion-literate."
        case .zenGuru:
            return "You are a soothing wellness mentor: balanced, compassionate, and mindful."
        }
    }
}
