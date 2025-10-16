//
//  VisualizationPresetGenerator.swift
//  glowup
//
//  Builds contextual visualization presets from photo analysis results.
//

import Foundation

struct VisualizationPresetGenerator {
    static func presets(from analysis: DetailedPhotoAnalysis?) -> [VisualizationPreset] {
        let vars = analysis?.variables

        var presets: [VisualizationPreset] = []

        presets.append(
            VisualizationPreset(
                category: .hairstyles,
                headline: "Hairstyle Try-Ons",
                description: "Quickly test hairstyles that fit your face shape.",
                options: hairstyleOptions(faceShape: vars?.faceShape),
                priority: 1,
                requiresAnalysis: true
            )
        )

        presets.append(
            VisualizationPreset(
                category: .hairColors,
                headline: "Palette Hair Colors",
                description: "Color ideas tuned to your seasonal palette.",
                options: hairColorOptions(
                    palette: vars?.seasonalPalette,
                    bestColors: vars?.bestColors ?? [],
                    naturalColor: vars?.hairColor
                ),
                priority: 2,
                requiresAnalysis: true
            )
        )

        presets.append(
            VisualizationPreset(
                category: .makeup,
                headline: "Makeup Lineup",
                description: "Looks that match your preferred makeup vibe.",
                options: makeupOptions(
                    style: vars?.makeupStyle,
                    palette: vars?.seasonalPalette,
                    quickWins: vars?.quickWins ?? []
                ),
                priority: 3,
                requiresAnalysis: true
            )
        )

        presets.append(
            VisualizationPreset(
                category: .clothing,
                headline: "Outfit Palette Swaps",
                description: "Outfit colors and pieces pulled from your palette.",
                options: clothingOptions(
                    palette: vars?.seasonalPalette,
                    bestColors: vars?.bestColors ?? []
                ),
                priority: 4,
                requiresAnalysis: true
            )
        )

        return presets
    }

    // MARK: - Hairstyles

    private static func hairstyleOptions(faceShape: String?) -> [VisualizationPresetOption] {
        let identityReminder = "Keep the face, features, lighting, and natural hair density identical."

        let base: [VisualizationPresetOption] = [
            VisualizationPresetOption(
                title: "French Barrette Half-Up",
                prompt: """
                Replace the hairstyle with a French barrette half-up. Smooth the crown, secure the top section at the back with a slim barrette, and leave soft face-framing pieces. \(identityReminder)
                """,
                noteDetail: "Ask for a polished half-up secured with a slim French barrette and softly waved lengths."
            ),
            VisualizationPresetOption(
                title: "Twisted Half-Up",
                prompt: """
                Twist both front sections toward the back and pin them just below the crown while the rest of the lengths fall in loose waves. Keep a clean middle part and natural volume. \(identityReminder)
                """,
                noteDetail: "Ask your stylist to twist the front sections back for a half-up style with soft texture through the lengths."
            ),
            VisualizationPresetOption(
                title: "Front Piece Clip Back",
                prompt: """
                Clip both front pieces straight back to reveal the face while the remainder stays sleek and polished. Maintain a gentle shine through the lengths. \(identityReminder)
                """,
                noteDetail: "Request a sleek front-piece clip back so the face is open while the rest stays polished."
            ),
            VisualizationPresetOption(
                title: "French Braid",
                prompt: """
                Create a classic French braid starting at the crown and running to the nape with even tension and a tidy finish. \(identityReminder)
                """,
                noteDetail: "Ask for a classic French braid with even tension and a tidy finish down the back."
            ),
            VisualizationPresetOption(
                title: "French Twist",
                prompt: """
                Sweep the hair into a structured French twist with tucked ends and a soft lift at the crown. Leave one delicate face-framing tendril if it suits the look. \(identityReminder)
                """,
                noteDetail: "Request a tailored French twist with a clean nape and softly lifted crown."
            ),
            VisualizationPresetOption(
                title: "Polished Blowout",
                prompt: """
                Blow out the hair into a polished finish with round-brush bend at the ends and realistic bounce. \(identityReminder)
                """,
                noteDetail: "Ask for a round-brush blowout with smooth bend and glossy finish."
            ),
            VisualizationPresetOption(
                title: "Straight Middle Part",
                prompt: """
                Press the hair straight with a sharp middle part while keeping subtle natural movement in the lengths. \(identityReminder)
                """,
                noteDetail: "Request a glassy straight finish with a precise middle part."
            ),
            VisualizationPresetOption(
                title: "Low Sleek Bun",
                prompt: """
                Gather the hair into a low sleek bun at the nape with a centered part, tight sides, and a neat wrapped base. \(identityReminder)
                """,
                noteDetail: "Ask for a low, sleek bun with a middle part and polished coil at the nape."
            ),
            VisualizationPresetOption(
                title: "High Ponytail",
                prompt: """
                Lift the hair into a high ponytail with smooth roots, subtle crown lift, and a wrapped section covering the elastic. Keep the ponytail glossy and full. \(identityReminder)
                """,
                noteDetail: "Ask for a high ponytail with smooth roots and a wrapped base."
            ),
            VisualizationPresetOption(
                title: "Soft Beach Waves",
                prompt: """
                Create soft, brushed-out beach waves with a center part and an even relaxed pattern throughout the lengths. \(identityReminder)
                """,
                noteDetail: "Request loose beach waves that are brushed out for a relaxed finish."
            )
        ]

        let shape = faceShape?.lowercased() ?? ""
        var recommendedTitles: [String]

        if shape.contains("round") {
            recommendedTitles = ["Straight Middle Part", "Low Sleek Bun", "French Barrette Half-Up"]
        } else if shape.contains("oval") {
            recommendedTitles = ["Soft Beach Waves", "French Barrette Half-Up", "Polished Blowout"]
        } else if shape.contains("heart") {
            recommendedTitles = ["Front Piece Clip Back", "French Twist", "Polished Blowout"]
        } else if shape.contains("diamond") {
            recommendedTitles = ["French Braid", "Twisted Half-Up", "French Twist"]
        } else if shape.contains("square") {
            recommendedTitles = ["Twisted Half-Up", "Soft Beach Waves", "French Twist"]
        } else {
            recommendedTitles = ["French Barrette Half-Up", "Polished Blowout", "Soft Beach Waves"]
        }

        return organize(options: base, recommendedTitles: recommendedTitles)
    }

    // MARK: - Hair Colors

    private static func hairColorOptions(
        palette: String?,
        bestColors: [String],
        naturalColor: String?
    ) -> [VisualizationPresetOption] {
        let paletteName = palette?.lowercased() ?? "neutral"
        let heroColorRaw = bestColors.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let identityReminder = "Keep facial features, lighting, and strand detail identical while maintaining believable depth."
        let naturalDescription = naturalColor?.lowercased() ?? "current tone"

        var options: [VisualizationPresetOption] = [
            VisualizationPresetOption(
                title: "Warm Honey Blonde",
                prompt: """
                Recolor the hair to a warm honey blonde with soft face-framing babylights and a diffused root. Keep the transitions seamless and natural. \(identityReminder)
                """,
                swatchHex: "#E3B37A",
                noteDetail: "Ask for honey blonde babylights with a soft shadow root so the color grows in naturally."
            ),
            VisualizationPresetOption(
                title: "Champagne Beige",
                prompt: """
                Glaze the hair with champagne beige to cool warmth while leaving gentle depth at the roots. Brighten the face frame and mid-lengths for glow. \(identityReminder)
                """,
                swatchHex: "#E7D3B0",
                noteDetail: "Request a champagne beige glaze with brightness around the face and gentle depth at the root."
            ),
            VisualizationPresetOption(
                title: "Soft Mushroom Brown",
                prompt: """
                Shift the color to a soft mushroom brown with cool-neutral ribbons and slightly lighter ends for dimension. \(identityReminder)
                """,
                swatchHex: "#8B7462",
                noteDetail: "Ask for a mushroom brown blend with cool-neutral ribbons that stay close to your natural depth."
            ),
            VisualizationPresetOption(
                title: "Glossy Espresso",
                prompt: """
                Deepen the \(naturalDescription) with a glossy espresso glaze that reduces warmth and keeps high shine. Define individual strands without darkening the face. \(identityReminder)
                """,
                swatchHex: "#2F2626",
                noteDetail: "Request an espresso gloss to deepen the tone while keeping it reflective and rich."
            ),
            VisualizationPresetOption(
                title: "Copper Spice",
                prompt: """
                Ribbon copper spice accents through the mid-lengths and ends for warmth and contrast while the roots stay soft. \(identityReminder)
                """,
                swatchHex: "#C96F3B",
                noteDetail: "Ask for fine copper ribbons that concentrate toward the ends for a soft sunset effect."
            ),
            VisualizationPresetOption(
                title: "Midnight Brunette",
                prompt: """
                Glaze the hair to a midnight brunette with a subtle blue-black sheen, leaving the root natural and the lengths reflective. \(identityReminder)
                """,
                swatchHex: "#241A17",
                noteDetail: "Request a midnight brunette glaze with a cool sheen and high-shine finish."
            ),
            VisualizationPresetOption(
                title: "Cool Mocha Balayage",
                prompt: """
                Paint a cool mocha balayage with soft lightness around the face and diffused mids-to-ends for a seamless melt. \(identityReminder)
                """,
                swatchHex: "#7B5D4A",
                noteDetail: "Ask for a cool mocha balayage with soft face-framing lightness and diffused blend."
            )
        ]

        var recommendedTitles = recommendedHairColorTitles(for: paletteName)

        if let hero = heroColorRaw, !hero.isEmpty {
            let personalized = VisualizationPresetOption(
                title: "\(hero) Highlights",
                prompt: """
                Weave in fine \(hero.lowercased()) highlights around the face and through the top layer while keeping the base close to the \(naturalDescription). Blend the tone softly for a polished finish. \(identityReminder)
                """,
                noteDetail: "Ask for fine \(hero.lowercased()) highlights focused around the face with a seamless melt."
            )
            options.insert(personalized, at: 0)
            recommendedTitles.insert(personalized.title, at: 0)
        }

        return organize(options: options, recommendedTitles: recommendedTitles)
    }

    private static func recommendedHairColorTitles(for palette: String) -> [String] {
        if palette.contains("spring") {
            return ["Warm Honey Blonde", "Champagne Beige", "Copper Spice"]
        } else if palette.contains("summer") {
            return ["Champagne Beige", "Soft Mushroom Brown", "Cool Mocha Balayage"]
        } else if palette.contains("autumn") || palette.contains("fall") {
            return ["Copper Spice", "Soft Mushroom Brown", "Midnight Brunette"]
        } else if palette.contains("winter") {
            return ["Glossy Espresso", "Midnight Brunette", "Cool Mocha Balayage"]
        }
        return ["Soft Mushroom Brown", "Glossy Espresso", "Warm Honey Blonde"]
    }

    // MARK: - Makeup

    private static func makeupOptions(
        style: String?,
        palette: String?,
        quickWins: [String]
    ) -> [VisualizationPresetOption] {
        let identityReminder = "Keep skin texture natural and leave the face structure unchanged."

        let base: [VisualizationPresetOption] = [
            VisualizationPresetOption(
                title: "Glazed Skin Set",
                prompt: """
                Create a hydrated base with sheer coverage, lightweight highlight on cheekbones, brushed-up brows, and a neutral balm on the lips. Keep everything glossy but lifelike. \(identityReminder)
                """,
                noteDetail: "Ask for luminous sheer skin, brushed-up brows, and a neutral glossy lip."
            ),
            VisualizationPresetOption(
                title: "Soft Winged Liner",
                prompt: """
                Define the eyes with a soft brown winged liner, diffused shimmer on the lid, and lengthened lashes. Pair with a peachy blush and nude satin lip. \(identityReminder)
                """,
                noteDetail: "Ask for a soft brown winged liner with diffused shimmer and peachy blush."
            ),
            VisualizationPresetOption(
                title: "Bronzed Monochrome",
                prompt: """
                Sweep warm bronze tones across the eyes, cheeks, and lips for a monochromatic look. Add subtle contouring while keeping the finish radiant. \(identityReminder)
                """,
                noteDetail: "Ask for bronze eyes, cheeks, and lips that stay within the same warm family."
            ),
            VisualizationPresetOption(
                title: "Statement Lip",
                prompt: """
                Keep the complexion clean with soft contour, understated eyes, and focus on a bold creamy lip in a flattering seasonal tone. \(identityReminder)
                """,
                noteDetail: "Ask for minimal eye makeup with a bold lip that suits your seasonal palette."
            ),
            VisualizationPresetOption(
                title: "Matte Smoky Eye",
                prompt: """
                Build a matte smoky eye with diffused edges, tightlined waterline, and volumized lashes. Balance with a neutral matte lip and softly sculpted cheeks. \(identityReminder)
                """,
                noteDetail: "Ask for a matte smoky eye with diffused edges and neutral matte lip."
            ),
            VisualizationPresetOption(
                title: "Rosy Flush",
                prompt: """
                Focus on fresh pink tones: glassy skin, fluffy brows, sheer pink wash on the lids, and a diffused rosy lip stain. \(identityReminder)
                """,
                noteDetail: "Ask for glassy skin with pink wash on cheeks, lids, and lips."
            )
        ]

        let styleDescriptor = style?.lowercased() ?? ""
        var recommendedTitles: [String]

        if styleDescriptor.contains("clean") || styleDescriptor.contains("minimal") {
            recommendedTitles = ["Glazed Skin Set", "Rosy Flush", "Soft Winged Liner"]
        } else if styleDescriptor.contains("soft glam") {
            recommendedTitles = ["Soft Winged Liner", "Bronzed Monochrome", "Statement Lip"]
        } else if styleDescriptor.contains("bold") || styleDescriptor.contains("dramatic") {
            recommendedTitles = ["Statement Lip", "Matte Smoky Eye", "Bronzed Monochrome"]
        } else if styleDescriptor.contains("classic") {
            recommendedTitles = ["Soft Winged Liner", "Glazed Skin Set", "Bronzed Monochrome"]
        } else {
            recommendedTitles = ["Glazed Skin Set", "Soft Winged Liner", "Bronzed Monochrome"]
        }

        if quickWins.joined(separator: " ").lowercased().contains("lip") {
            recommendedTitles.insert("Statement Lip", at: 0)
        }

        return organize(options: base, recommendedTitles: recommendedTitles)
    }

    // MARK: - Clothing

    private static func clothingOptions(
        palette: String?,
        bestColors: [String]
    ) -> [VisualizationPresetOption] {
        let paletteName = palette ?? "Neutral"
        let normalizedPalette = paletteName.lowercased()
        let displayPalette = paletteName.capitalized
        let paletteColors = defaultPaletteColors(for: normalizedPalette)
        let recommendedColors = (!bestColors.isEmpty ? Array(bestColors.prefix(3)) : Array(paletteColors.prefix(3)))
        let remainingColors = (Array(bestColors.dropFirst(recommendedColors.count)) + paletteColors)
            .filter { !recommendedColors.contains($0) }
        let identityReminder = "Keep the pose, body shape, and lighting identical while matching fabric realism."

        var options: [VisualizationPresetOption] = []

        let recommendedTemplates: [(garment: String, description: String)] = [
            ("Tank Top", "Swap the top for a fitted tank in %@ from the %@ palette."),
            ("Crewneck Tee", "Replace the top with a relaxed crewneck tee in %@ while keeping clean lines."),
            ("Soft Knit", "Layer a lightweight knit in %@, draping naturally over the shoulders.")
        ]

        for (index, color) in recommendedColors.enumerated() {
            guard index < recommendedTemplates.count else { break }
            let template = recommendedTemplates[index]
            let lowerColor = color.lowercased()
            options.append(
                VisualizationPresetOption(
                    title: "\(color) \(template.garment)",
                    prompt: """
                    Replace the current top with a \(template.garment.lowercased()) in \(lowerColor) and remove other top layers. \(identityReminder)
                    """,
                    isRecommended: true,
                    noteDetail: String(format: template.description, color, displayPalette)
                )
            )
        }

        let otherTemplates: [(garment: String, prompt: String, note: String)] = [
            (
                "Slip Dress",
                "Replace the outfit with a bias-cut slip dress in %@ that follows the existing lines and remove other tops or bottoms.",
                "Request a slip dress in %@ that aligns with the %@ palette."
            ),
            (
                "Blazer",
                "Layer a structured blazer in %@ over the existing top, keeping shoulders sharp and the fit tailored.",
                "Ask for a tailored blazer in %@ that fits within the %@ palette and has structured shoulders."
            ),
            (
                "Midi Skirt",
                "Swap the bottom for a midi skirt in %@ with gentle movement and clean pleats, removing any previous skirt or pants.",
                "Request a midi skirt in %@ that matches the %@ palette."
            ),
            (
                "Wide-Leg Pants",
                "Swap the bottom for high-waisted wide-leg pants in %@ with crisp pleats and fluid length.",
                "Ask for high-waisted wide-leg pants in %@ that align with the %@ palette."
            ),
            (
                "Cropped Cardigan",
                "Layer a cropped cardigan in %@, leaving it open to frame the outfit while keeping other layers flat.",
                "Request a cropped cardigan in %@ that layers cleanly within the %@ palette."
            )
        ]

        for (index, template) in otherTemplates.enumerated() {
            let color = remainingColors.indices.contains(index) ? remainingColors[index] : paletteColors[index % max(paletteColors.count, 1)]
            let lowerColor = color.lowercased()
            options.append(
                VisualizationPresetOption(
                    title: "\(color) \(template.garment)",
                    prompt: """
                    \(String(format: template.prompt, lowerColor)). \(identityReminder)
                    """,
                    noteDetail: String(format: template.note, color, displayPalette)
                )
            )
        }

        return options
    }

    // MARK: - Helpers

    private static func organize(
        options: [VisualizationPresetOption],
        recommendedTitles: [String]
    ) -> [VisualizationPresetOption] {
        let recommendedSet = Set(recommendedTitles)

        var recommended = options.filter { recommendedSet.contains($0.title) }
            .map { $0.withRecommended(true) }
        var remaining = options.filter { !recommendedSet.contains($0.title) }
            .map { $0.withRecommended(false) }

        if recommended.isEmpty {
            recommended = Array(options.prefix(2)).map { $0.withRecommended(true) }
            remaining = Array(options.dropFirst(2)).map { $0.withRecommended(false) }
        }

        return recommended + remaining
    }

    private static func defaultPaletteColors(for palette: String) -> [String] {
        if palette.contains("spring") {
            return ["Soft Coral", "Warm Apricot", "Light Pistachio", "Golden Butter", "Peach Beige"]
        } else if palette.contains("summer") {
            return ["Dusty Rose", "Cool Lilac", "Mist Blue", "Soft Navy", "Silver Grey"]
        } else if palette.contains("autumn") || palette.contains("fall") {
            return ["Burnt Sienna", "Olive Green", "Mustard Gold", "Rust Brown", "Deep Teal"]
        } else if palette.contains("winter") {
            return ["True Red", "Royal Blue", "Emerald", "Plum", "Soft Black"]
        }
        return ["Ivory", "Camel", "Taupe", "Slate", "Midnight Blue"]
    }
}
