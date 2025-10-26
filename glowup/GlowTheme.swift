//
//  GlowTheme.swift
//  glowup
//
//  Created by Codex on 26/11/2025.
//

import SwiftUI

enum GlowPalette {
    // Fixed tokens (same in dark & light)
    static let blushPink = Color(hex: "#FFD1D9")
    static let creamyWhite = Color(hex: "#FBFAF5")
    static let roseGold = Color(hex: "#B76E79")
    static let softBeige = Color(hex: "#E5D9D4")
    static let deepRose = Color(hex: "#934F5C")

    static let translucentBlush = blushPink.opacity(0.18)
}

enum GlowGradient {
    static let canvas = LinearGradient(
        colors: [
            GlowPalette.creamyWhite,
            GlowPalette.blushPink.opacity(0.15)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let blushAccent = LinearGradient(
        colors: [
            GlowPalette.blushPink,
            GlowPalette.roseGold.opacity(0.85)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum GlowShadow {
    static let soft = (color: GlowPalette.deepRose.opacity(0.15), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(8))
    static let button = (color: GlowPalette.deepRose.opacity(0.12), radius: CGFloat(6), x: CGFloat(0), y: CGFloat(4))
}

enum GlowTypography {
    static func heading(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    
    static func body(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    
    static var button: Font {
        .system(size: 17, weight: .medium, design: .rounded)
    }
    
    static var caption: Font {
        .system(size: 13, weight: .regular, design: .rounded)
    }
}

struct GlowCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 20
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GlowPalette.softBeige)
            .cornerRadius(cornerRadius)
            .shadow(
                color: GlowShadow.soft.color,
                radius: GlowShadow.soft.radius,
                x: GlowShadow.soft.x,
                y: GlowShadow.soft.y
            )
    }
}

extension View {
    func glowBackground() -> some View {
        background(GlowGradient.canvas.ignoresSafeArea())
    }
    
    func glowCard(cornerRadius: CGFloat = 20, padding: CGFloat = 20) -> some View {
        modifier(GlowCardStyle(cornerRadius: cornerRadius, padding: padding))
    }
    
    func glowRoundedButtonBackground(isEnabled: Bool = true) -> some View {
        self
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? GlowPalette.deepRose : GlowPalette.deepRose.opacity(0.45))
            )
            .foregroundStyle(GlowPalette.creamyWhite)
            .shadow(
                color: GlowShadow.button.color,
                radius: GlowShadow.button.radius,
                x: GlowShadow.button.x,
                y: GlowShadow.button.y
            )
    }
    
    func glowSecondaryButtonBackground() -> some View {
        self
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(GlowPalette.roseGold.opacity(0.5), lineWidth: 1.5)
            )
            .foregroundStyle(GlowPalette.deepRose)
    }
}

// MARK: - Global helpers & components

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        case 8: (a, r, g, b) = ((int >> 24) & 255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        default: (a, r, g, b) = (255, 1, 1, 0)
        }
        self = Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct GlowPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .foregroundStyle(GlowPalette.creamyWhite)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(GlowPalette.deepRose)
            .cornerRadius(16)
            .opacity(configuration.isPressed ? 0.96 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
    }
}

struct GlowProgressBar: View {
    var value: Double // 0...1
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(GlowPalette.roseGold.opacity(0.2))
                Capsule()
                    .fill(LinearGradient(colors: [GlowPalette.blushPink, GlowPalette.roseGold], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, width * value))
            }
        }
        .frame(height: 12)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }
}
