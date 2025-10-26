//
//  GradientBackground.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import SwiftUI

enum GradientBackground {
    static var blushCanvas: LinearGradient {
        GlowGradient.canvas
    }
    
    static var accent: LinearGradient {
        GlowGradient.blushAccent
    }
    
    static var primary: LinearGradient { blushCanvas }
    static var lavenderRose: LinearGradient { blushCanvas }
    static var twilightAura: LinearGradient { blushCanvas }
    static var mintPeach: LinearGradient { accent }
}
