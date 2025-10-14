//
//  GradientBackground.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import SwiftUI

enum GradientBackground {
    static var lavenderRose: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.69, green: 0.56, blue: 0.99),
                Color(red: 0.98, green: 0.77, blue: 0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var mintPeach: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.63, green: 0.91, blue: 0.86),
                Color(red: 1.0, green: 0.86, blue: 0.72)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var twilightAura: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.18, green: 0.16, blue: 0.32),
                Color(red: 0.47, green: 0.26, blue: 0.66)
            ],
            startPoint: .top,
            endPoint: .bottomTrailing
        )
    }

    static var primary: LinearGradient { twilightAura }
}
