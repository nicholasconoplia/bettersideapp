//
//  SeasonDeterminationService.swift
//  glowup
//
//  Created by Codex on 16/10/2025.
//

import CoreImage
import UIKit

struct SeasonClassification {
    let seasonName: String
    let confidence: Double
    let summary: String
    let bestColors: [SeasonColorSwatch]
    let avoidColors: [String]
}

struct SeasonColorSwatch {
    let label: String
    let hex: String

    var displayName: String {
        "\(label) (#\(hex))"
    }

    var uiColor: UIColor {
        UIColor(hex: hex)
    }
}

private enum UndertoneCategory: String {
    case cool
    case warm
    case neutral
}

private struct SeasonProfile {
    let name: String
    let undertone: UndertoneCategory
    let brightnessRange: ClosedRange<Double>
    let contrastRange: ClosedRange<Double>
    let saturationRange: ClosedRange<Double>
    let palette: [SeasonColorSwatch]
    let avoidHints: [String]
    let summaryHook: String
}

struct SeasonDeterminationService {
    private let context = CIContext(options: [.workingColorSpace: NSNull()])
    private let profiles: [SeasonProfile] = SeasonDeterminationService.referenceProfiles

    func classify(faceData: Data, skinData: Data, eyeData: Data, variables: PhotoAnalysisVariables) -> SeasonClassification? {
        guard
            let faceImage = UIImage(data: faceData),
            let skinImage = UIImage(data: skinData),
            let eyesImage = UIImage(data: eyeData),
            let faceColor = averageColor(for: faceImage),
            let skinColor = averageColor(for: skinImage),
            let eyeColor = averageColor(for: eyesImage)
        else {
            return nil
        }

        let features = deriveFeatures(face: faceColor, skin: skinColor, eye: eyeColor, variables: variables)

        var bestScore: Double = 0
        var bestProfile: SeasonProfile?

        for profile in profiles {
            let score = scoreProfile(profile, with: features)
            if score > bestScore {
                bestScore = score
                bestProfile = profile
            }
        }

        guard let profile = bestProfile else { return nil }

        let clampedConfidence = min(max(bestScore, 0.0), 1.0)
        let summary = buildSummary(for: profile, features: features, confidence: clampedConfidence)

        return SeasonClassification(
            seasonName: profile.name,
            confidence: clampedConfidence,
            summary: summary,
            bestColors: profile.palette,
            avoidColors: profile.avoidHints
        )
    }

    // MARK: - Feature Extraction

    private func deriveFeatures(face: UIColor, skin: UIColor, eye: UIColor, variables: PhotoAnalysisVariables) -> SeasonFeatureSnapshot {
        let skinComponents = skin.components
        let eyeComponents = eye.components
        let faceComponents = face.components

        let derivedUndertone: UndertoneCategory = {
            if let descriptor = variables.skinUndertone?.lowercased() {
                if descriptor.contains("warm") { return .warm }
                if descriptor.contains("cool") { return .cool }
            }
            // Use hue-based heuristic
            switch skinComponents.hue {
            case 0.0..<0.10, 0.90..<1.0:
                return .warm
            case 0.10..<0.44:
                return .warm
            case 0.44..<0.66:
                return .neutral
            default:
                return .cool
            }
        }()

        let hairBrightness = brightnessEstimate(from: variables.hairColor)
        let eyeBrightness = eyeComponents.brightness
        let skinBrightness = skinComponents.brightness

        let brightnessValues = [hairBrightness, eyeBrightness, skinBrightness]
        let contrast = (brightnessValues.max() ?? skinBrightness) - (brightnessValues.min() ?? skinBrightness)
        let avgBrightness = brightnessValues.reduce(0, +) / Double(brightnessValues.count)
        let avgSaturation = (skinComponents.saturation + eyeComponents.saturation + faceComponents.saturation) / 3.0

        return SeasonFeatureSnapshot(
            undertone: derivedUndertone,
            brightness: avgBrightness,
            contrast: contrast,
            saturation: avgSaturation,
            skinDescriptor: skinDescriptor(from: variables.skinUndertone, components: skinComponents),
            hairDescriptor: variables.hairColor ?? "unknown",
            eyeDescriptor: variables.eyeColor ?? "unknown"
        )
    }

    private func brightnessEstimate(from hairColor: String?) -> Double {
        guard let hairColor else { return 0.5 }
        let normalized = hairColor.lowercased()
        if normalized.contains("blonde") || normalized.contains("platinum") {
            return 0.8
        }
        if normalized.contains("ginger") || normalized.contains("copper") || normalized.contains("auburn") {
            return 0.65
        }
        if normalized.contains("light brown") {
            return 0.6
        }
        if normalized.contains("brown") {
            return 0.45
        }
        if normalized.contains("brunette") || normalized.contains("espresso") {
            return 0.35
        }
        if normalized.contains("black") || normalized.contains("ebony") {
            return 0.2
        }
        return 0.5
    }

    private func skinDescriptor(from undertone: String?, components: ColorComponents) -> String {
        if let undertone {
            return undertone.capitalized
        }
        if components.saturation < 0.2 {
            return "Soft Neutral"
        }
        if components.hue < 0.1 || components.hue > 0.9 {
            return "Golden Warm"
        }
        if components.hue > 0.6 && components.hue < 0.85 {
            return "Cool Rosy"
        }
        return "Balanced Neutral"
    }

    // MARK: - Scoring

    private func scoreProfile(_ profile: SeasonProfile, with features: SeasonFeatureSnapshot) -> Double {
        let undertoneScore = matchUndertone(expected: profile.undertone, actual: features.undertone)
        let brightnessScore = score(value: features.brightness, in: profile.brightnessRange)
        let contrastScore = score(value: features.contrast, in: profile.contrastRange)
        let saturationScore = score(value: features.saturation, in: profile.saturationRange)

        // Weighted total
        let total = undertoneScore * 0.4
            + brightnessScore * 0.2
            + contrastScore * 0.2
            + saturationScore * 0.2

        return total
    }

    private func matchUndertone(expected: UndertoneCategory, actual: UndertoneCategory) -> Double {
        if expected == actual {
            return 1.0
        }
        if actual == .neutral {
            return 0.6
        }
        if expected == .neutral {
            return 0.8
        }
        return 0.0
    }

    private func score(value: Double, in range: ClosedRange<Double>) -> Double {
        if range.contains(value) {
            return 1.0
        }
        let distance = min(abs(value - range.lowerBound), abs(value - range.upperBound))
        let tolerance = 0.25
        return max(0.0, 1.0 - distance / tolerance)
    }

    private func buildSummary(for profile: SeasonProfile, features: SeasonFeatureSnapshot, confidence: Double) -> String {
        let confidencePercent = Int(confidence * 100)
        return "\(profile.summaryHook) Your skin reads \(features.skinDescriptor.lowercased()), hair registers as \(features.hairDescriptor.lowercased()), and eye brightness sits at \(String(format: "%.0f%%", features.brightness * 100)). That balance aligns with \(profile.name) (\(confidencePercent)% confident)."
    }

    // MARK: - Image Helpers

    private func averageColor(for image: UIImage) -> UIColor? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let extentVector = CIVector(x: ciImage.extent.origin.x,
                                    y: ciImage.extent.origin.y,
                                    z: ciImage.extent.size.width,
                                    w: ciImage.extent.size.height)
        guard
            let filter = CIFilter(name: "CIAreaAverage", parameters: [
                kCIInputImageKey: ciImage,
                kCIInputExtentKey: extentVector
            ]),
            let outputImage = filter.outputImage
        else {
            return nil
        }
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        return UIColor(
            red: CGFloat(bitmap[0]) / 255.0,
            green: CGFloat(bitmap[1]) / 255.0,
            blue: CGFloat(bitmap[2]) / 255.0,
            alpha: 1.0
        )
    }

    // MARK: - Reference Data

    private static let referenceProfiles: [SeasonProfile] = {
        // Color swatches approximated from the provided seasonal charts
        let trueWinterColors: [SeasonColorSwatch] = [
            .init(label: "Icy Raspberry", hex: "C9184A"),
            .init(label: "Electric Fuchsia", hex: "FF3BAC"),
            .init(label: "Royal Sapphire", hex: "3C4CAD"),
            .init(label: "Deep Emerald", hex: "006D77"),
            .init(label: "Cerulean Pop", hex: "3DB2FF"),
            .init(label: "Midnight Navy", hex: "041C40"),
            .init(label: "Velvet Plum", hex: "4C1D57"),
            .init(label: "Vivid Magenta", hex: "FF008E"),
            .init(label: "Blue-Black", hex: "0A0814"),
            .init(label: "Frosted Lilac", hex: "C3A6FF")
        ]

        let trueAutumnColors: [SeasonColorSwatch] = [
            .init(label: "Burnished Copper", hex: "BF6B04"),
            .init(label: "Spiced Pumpkin", hex: "DC582A"),
            .init(label: "Rust Cabernet", hex: "8C1C13"),
            .init(label: "Olive Grove", hex: "5A6B2C"),
            .init(label: "Cedar Brown", hex: "6F4518"),
            .init(label: "Mossy Pine", hex: "1F4D2B"),
            .init(label: "Teal Lagoon", hex: "1B6A6C"),
            .init(label: "Honey Mustard", hex: "D4A017"),
            .init(label: "Mulberry Wine", hex: "6B2737"),
            .init(label: "Marigold Glow", hex: "F4A300")
        ]

        let trueSpringColors: [SeasonColorSwatch] = [
            .init(label: "Sunrise Coral", hex: "FF7F6A"),
            .init(label: "Golden Daffodil", hex: "FFBE0B"),
            .init(label: "Fresh Melon", hex: "FF9B85"),
            .init(label: "Mint Mojito", hex: "70E4B6"),
            .init(label: "Seafoam Teal", hex: "1ECFD6"),
            .init(label: "Sky Periwinkle", hex: "8AB6FF"),
            .init(label: "Juicy Apricot", hex: "FFA552"),
            .init(label: "Warm Sorbet Pink", hex: "FF6FB5"),
            .init(label: "Lime Zest", hex: "B5E550"),
            .init(label: "Buttercream Beige", hex: "F6E6C5")
        ]

        let trueSummerColors: [SeasonColorSwatch] = [
            .init(label: "Soft Rose", hex: "D08CA7"),
            .init(label: "Mauve Mist", hex: "A686B1"),
            .init(label: "Smoky Plum", hex: "6A4C7D"),
            .init(label: "Blue Hydrangea", hex: "7BA9D6"),
            .init(label: "Sea Glass", hex: "6BB4B6"),
            .init(label: "Slate Navy", hex: "284B63"),
            .init(label: "Dusty Periwinkle", hex: "A6B6ED"),
            .init(label: "Cool Raspberry", hex: "C05FA5"),
            .init(label: "Blueberry", hex: "395F8F"),
            .init(label: "Silver Birch", hex: "D8DCE4")
        ]

        return [
            SeasonProfile(
                name: "True Winter",
                undertone: .cool,
                brightnessRange: 0.45...0.75,
                contrastRange: 0.35...0.7,
                saturationRange: 0.45...0.9,
                palette: trueWinterColors,
                avoidHints: [
                    "Muted olives or mustard yellows that flatten cool contrast",
                    "Dusty browns or beiges without crispness"
                ],
                summaryHook: "Your features carry bold contrast and a cool pulse."
            ),
            SeasonProfile(
                name: "True Autumn",
                undertone: .warm,
                brightnessRange: 0.35...0.6,
                contrastRange: 0.2...0.45,
                saturationRange: 0.35...0.8,
                palette: trueAutumnColors,
                avoidHints: [
                    "Icy pastels that wash out warmth",
                    "Stark black/white combos that overpower softness"
                ],
                summaryHook: "Rich warmth shows up in your skin and hair depth."
            ),
            SeasonProfile(
                name: "True Spring",
                undertone: .warm,
                brightnessRange: 0.55...0.85,
                contrastRange: 0.18...0.4,
                saturationRange: 0.45...0.85,
                palette: trueSpringColors,
                avoidHints: [
                    "Heavy earth tones that dull lively skin",
                    "Muted greys that sap brightness"
                ],
                summaryHook: "Bright, clear warmth lights up your features."
            ),
            SeasonProfile(
                name: "True Summer",
                undertone: .cool,
                brightnessRange: 0.45...0.7,
                contrastRange: 0.15...0.4,
                saturationRange: 0.2...0.55,
                palette: trueSummerColors,
                avoidHints: [
                    "High-contrast neons that feel too sharp",
                    "Overly warm chestnut or pumpkin shades"
                ],
                summaryHook: "Soft cool contrast and velvety saturation show through."
            )
        ]
    }()
}

// MARK: - Supporting Models

private struct SeasonFeatureSnapshot {
    let undertone: UndertoneCategory
    let brightness: Double
    let contrast: Double
    let saturation: Double
    let skinDescriptor: String
    let hairDescriptor: String
    let eyeDescriptor: String
}

private struct ColorComponents {
    let red: Double
    let green: Double
    let blue: Double
    let hue: Double
    let saturation: Double
    let brightness: Double
}

private extension UIColor {
    convenience init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if sanitized.count == 3 {
            sanitized = sanitized.map { "\($0)\($0)" }.joined()
        }
        var int = UInt64()
        Scanner(string: sanitized).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255.0
        let g = CGFloat((int >> 8) & 0xFF) / 255.0
        let b = CGFloat(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    var components: ColorComponents {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)

        return ColorComponents(
            red: Double(r),
            green: Double(g),
            blue: Double(b),
            hue: Double(hue),
            saturation: Double(saturation),
            brightness: Double(brightness)
        )
    }
}
