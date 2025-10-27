//
//  GlowTheme.swift
//  glowup
//
//  Created by Codex on 26/11/2025.
//

import SwiftUI

extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 8: (a, r, g, b) = ((int >> 24) & 0xff, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        case 6: (a, r, g, b) = (255, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        default: (a, r, g, b) = (255, 255, 255, 255)
        }
        self = Color(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

enum GlowPalette {
    static let blushPink  = Color(hex: "#FFD1D9")
    static let creamyWhite = Color(hex: "#FBFAF5")
    static let roseGold   = Color(hex: "#B76E79")
    static let softBeige  = Color(hex: "#E5D9D4")
    static let deepRose   = Color(hex: "#934F5C")
    static let translucentBlush = blushPink.opacity(0.18)

    static func softOverlay(_ opacity: Double = 0.85) -> Color {
        softBeige.opacity(opacity)
    }

    static func blushOverlay(_ opacity: Double = 0.35) -> Color {
        blushPink.opacity(opacity)
    }

    static func creamOverlay(_ opacity: Double = 0.92) -> Color {
        creamyWhite.opacity(opacity)
    }

    static func roseStroke(_ opacity: Double = 0.35) -> Color {
        roseGold.opacity(opacity)
    }
}

// MARK: - Gradient Backgrounds
enum GlowGradient {
    static let canvas = LinearGradient(
        colors: [
            GlowPalette.creamyWhite,
            GlowPalette.blushPink.opacity(0.15)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let blushAccent = LinearGradient(
        colors: [
            GlowPalette.blushPink,
            GlowPalette.roseGold.opacity(0.85)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Shadow Definitions
enum GlowShadow {
    static let soft = (color: GlowPalette.deepRose.opacity(0.15), radius: CGFloat(3), x: CGFloat(0), y: CGFloat(1))
    static let button = (color: GlowPalette.deepRose.opacity(0.15), radius: CGFloat(3), x: CGFloat(0), y: CGFloat(1))
}

// MARK: - Typography
enum GlowTypography {
    static var glowHeading: Font {
        .system(size: 22, weight: .semibold, design: .rounded)
    }
    
    static var glowSubheading: Font {
        .system(size: 17, weight: .medium, design: .rounded)
    }
    
    static var glowBody: Font {
        .system(size: 15, weight: .regular, design: .rounded)
    }
    
    static var glowButton: Font {
        .system(size: 17, weight: .medium, design: .rounded)
    }
    
    static var glowCaption: Font {
        .system(size: 13, weight: .regular, design: .rounded)
    }
    
    // Legacy support
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

// MARK: - Simplified Font Extension
extension Font {
    static let glowHeading    = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let glowSubheading = Font.system(size: 17, weight: .medium, design: .rounded)
    static let glowBody       = Font.system(size: 15, weight: .regular, design: .rounded)
    static let glowButton     = Font.system(size: 17, weight: .medium, design: .rounded)
    static let glowCaption    = Font.system(size: 13, weight: .regular, design: .rounded)
}

// MARK: - View Modifiers
struct DeepRoseText: ViewModifier {
    func body(content: Content) -> some View {
        content.foregroundStyle(GlowPalette.deepRose)
    }
}

extension View {
    func deepRoseText() -> some View { modifier(DeepRoseText()) }
    
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
                    .fill(isEnabled ? GlowPalette.blushPink : GlowPalette.blushPink.opacity(0.45))
            )
            .foregroundStyle(isEnabled ? GlowPalette.deepRose : GlowPalette.deepRose.opacity(0.6))
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

// MARK: - Card Style Modifier
struct GlowCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 20
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GlowPalette.softBeige)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(GlowPalette.roseStroke(), lineWidth: 1)
            )
            .shadow(
                color: GlowShadow.soft.color,
                radius: GlowShadow.soft.radius,
                x: GlowShadow.soft.x,
                y: GlowShadow.soft.y
            )
    }
}

// MARK: - Button Styles
struct GlowFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.glowButton)
            .foregroundStyle(GlowPalette.deepRose)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(GlowPalette.blushPink)
            .cornerRadius(16)
            .shadow(
                color: GlowShadow.button.color,
                radius: GlowShadow.button.radius,
                x: GlowShadow.button.x,
                y: GlowShadow.button.y
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: configuration.isPressed)
    }
}

struct GlowPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .foregroundStyle(GlowPalette.deepRose)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(GlowPalette.blushPink)
            .cornerRadius(16)
            .opacity(configuration.isPressed ? 0.96 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .shadow(
                color: GlowShadow.button.color,
                radius: GlowShadow.button.radius,
                x: GlowShadow.button.x,
                y: GlowShadow.button.y
            )
    }
}

// MARK: - Background View
struct GlowBackground: View {
    var body: some View {
        LinearGradient(
            colors: [GlowPalette.creamyWhite, GlowPalette.blushPink.opacity(0.15)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Card Component
struct GlowCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .background(GlowPalette.softBeige)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(GlowPalette.roseStroke(), lineWidth: 1)
            )
            .shadow(
                color: GlowShadow.soft.color,
                radius: GlowShadow.soft.radius,
                x: GlowShadow.soft.x,
                y: GlowShadow.soft.y
            )
    }
}

// MARK: - Progress Bar
struct GlowProgressBar: View {
    var value: Double // 0...1
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(GlowPalette.roseGold.opacity(0.18))
                Capsule()
                    .fill(LinearGradient(colors: [GlowPalette.blushPink, GlowPalette.roseGold], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, width * value))
            }
        }
        .frame(height: 12)
        .clipShape(Capsule())
        .shadow(color: GlowShadow.soft.color.opacity(0.5), radius: GlowShadow.soft.radius, y: 1)
    }
}
