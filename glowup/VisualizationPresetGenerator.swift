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
                headline: "Face-Flattering Hair",
                description: "Haircuts that complement your structure and add balance.",
                options: hairstyleOptions(faceShape: vars?.faceShape, genderTone: vars?.genderDimorphism),
                priority: 1,
                requiresAnalysis: true
            )
        )

        presets.append(
            VisualizationPreset(
                category: .hairColors,
                headline: "Seasonal Color Play",
                description: "Hair color experiments guided by your palette.",
                options: hairColorOptions(palette: vars?.seasonalPalette, bestColors: vars?.bestColors ?? []),
                priority: 2,
                requiresAnalysis: true
            )
        )

        presets.append(
            VisualizationPreset(
                category: .makeup,
                headline: "Makeup Mood Board",
                description: "See makeup intensities that elevate your features.",
                options: makeupOptions(style: vars?.makeupStyle, eyeColor: vars?.eyeColor, quickWins: vars?.quickWins ?? []),
                priority: 3,
                requiresAnalysis: true
            )
        )

        presets.append(
            VisualizationPreset(
                category: .clothing,
                headline: "Wardrobe Palette Swaps",
                description: "Test outfit colors that boost your glow score.",
                options: clothingOptions(bestColors: vars?.bestColors ?? [], avoidColors: vars?.avoidColors ?? []),
                priority: 4,
                requiresAnalysis: true
            )
        )

        presets.append(
            VisualizationPreset(
                category: .accessories,
                headline: "Finish With Accessories",
                description: "Subtle changes that sharpen your overall vibe.",
                options: accessoryOptions(accessoryBalance: vars?.accessoryBalance ?? 5),
                priority: 5,
                requiresAnalysis: false
            )
        )

        presets.append(
            VisualizationPreset(
                category: .finishingTouches,
                headline: "Final Polish Tweaks",
                description: "Lighting, smoothing, and editorial polish options.",
                options: finishingOptions(lightingType: vars?.lightingType, compositionFeedback: vars?.compositionFeedback),
                priority: 6,
                requiresAnalysis: false
            )
        )

        return presets
    }

    private static func hairstyleOptions(
        faceShape: String?,
        genderTone: String?
    ) -> [VisualizationPresetOption] {
        let shape = faceShape?.lowercased() ?? ""

        let balancingLayers = VisualizationPresetOption(
            title: "Framing Layers",
            subtitle: "Soft curtain fringe hugging the cheeks.",
            prompt: """
            Add airy curtain bangs and jaw-grazing layers that skim the cheekbones. Maintain realistic density and ensure the fringe opens gently at the center.
            """
        )

        let sleekBob = VisualizationPresetOption(
            title: "Sleek Sculpted Bob",
            subtitle: "Precision bob grazing the jawline.",
            prompt: """
            Transform the hair into a sleek, one-length bob that hits right at the jaw for contouring. Keep the finish glossy and tuck one side behind the ear.
            """
        )

        let volumizedWaves = VisualizationPresetOption(
            title: "Voluminous Waves",
            subtitle: "Polished blowout with glam body.",
            prompt: """
            Style full, polished waves starting mid-length with softness around the face. Add modern shine and believable bounce without over-airbrushing.
            """
        )

        let liftedPony = VisualizationPresetOption(
            title: "Snatched Pony",
            subtitle: "High ponytail with face lift effect.",
            prompt: """
            Create a high, lifted ponytail with sleek roots and refined face-framing tendrils. Ensure the style feels editorial yet wearable for everyday photos.
            """
        )

        if shape.contains("heart") || shape.contains("diamond") {
            return [balancingLayers, volumizedWaves, liftedPony, sleekBob]
        } else if shape.contains("round") {
            return [sleekBob, liftedPony, volumizedWaves, balancingLayers]
        } else if shape.contains("square") {
            return [volumizedWaves, balancingLayers, liftedPony, sleekBob]
        } else {
            return [balancingLayers, volumizedWaves, sleekBob, liftedPony]
        }
    }

    private static func hairColorOptions(
        palette: String?,
        bestColors: [String]
    ) -> [VisualizationPresetOption] {
        let paletteName = (palette ?? "Neutral").lowercased()
        let heroColor = bestColors.first ?? "soft latte"

        let sunKissed = VisualizationPresetOption(
            title: "Sun-Kissed Dimension",
            subtitle: "Glossy babylights hugging the face.",
            prompt: """
            Add luminous, fine babylights around the face with a sun-kissed gradient toward the ends. Keep roots diffused and believable.
            """,
            swatchHex: paletteName.contains("spring") ? "#f6c28b" : "#d9a86c"
        )

        let coolGloss = VisualizationPresetOption(
            title: "Cool Espresso",
            subtitle: "Neutralize warmth with espresso glaze.",
            prompt: """
            Apply a cool espresso glaze that smooths warmth but keeps natural depth. Maintain high-shine finish and detailed strands.
            """,
            swatchHex: paletteName.contains("winter") ? "#2f2626" : "#3a2b27"
        )

        let copperPop = VisualizationPresetOption(
            title: "Copper Pop",
            subtitle: "Strategic ribboning for glow contrast.",
            prompt: """
            Introduce thin copper ribbons through the mid-lengths that echo \(heroColor) tones. Blend softly for a luxe, editorial feel.
            """,
            swatchHex: "#c96f3b"
        )

        let dimensionalBrunette = VisualizationPresetOption(
            title: "Dimensional Brunette",
            subtitle: "Shadow root with tonal gradient.",
            prompt: """
            Create a dimensional brunette with a shadow root and softly brushed caramel panels. Keep transitions believable and hair health intact.
            """,
            swatchHex: "#8b5a2b"
        )

        if paletteName.contains("summer") || paletteName.contains("winter") {
            return [coolGloss, sunKissed, dimensionalBrunette, copperPop]
        } else {
            return [sunKissed, dimensionalBrunette, copperPop, coolGloss]
        }
    }

    private static func makeupOptions(
        style: String?,
        eyeColor: String?,
        quickWins: [String]
    ) -> [VisualizationPresetOption] {
        let normalizedStyle = style?.lowercased() ?? "natural"
        let eyeDescriptor = eyeColor ?? "eyes"
        let quickFocus = quickWins.first ?? "Enhanced glow"

        let cleanGirl = VisualizationPresetOption(
            title: "Fresh & Dewy",
            subtitle: "Skin liquidity with brushed-up brows.",
            prompt: """
            Apply a dewy complexion, feathery brows, subtle tightlined eyes, and juicy nude lips. Showcase soft highlight on the high points and hydrated skin.
            """
        )

        let softGlam = VisualizationPresetOption(
            title: "Soft Glam",
            subtitle: "Smoky warmth hugging the lash line.",
            prompt: """
            Create a warm halo eye with shimmer at the center, a refined contour, and plush peachy lips. Keep lashes wispy and flattering for \(eyeDescriptor.lowercased()).
            """
        )

        let coolEditorial = VisualizationPresetOption(
            title: "Cool Editorial",
            subtitle: "Monochrome glaze with glossed lids.",
            prompt: """
            Layer a cool-toned monochrome look with glassy lids, sculpted cheeks, and a vinyl lip. Maintain believable skin texture and keep glow buildable.
            """
        )

        let powerLook = VisualizationPresetOption(
            title: "Statement Wing",
            subtitle: "\(quickFocus) with lifted liner.",
            prompt: """
            Add a snatched eyeliner wing, softly smoked lower lash line, and a satin berry lip. Ensure complexion remains polished but natural.
            """
        )

        if normalizedStyle.contains("glam") || normalizedStyle.contains("dramatic") {
            return [softGlam, powerLook, coolEditorial, cleanGirl]
        } else if normalizedStyle.contains("none") {
            return [cleanGirl, softGlam, powerLook, coolEditorial]
        } else {
            return [cleanGirl, softGlam, powerLook, coolEditorial]
        }
    }

    private static func clothingOptions(
        bestColors: [String],
        avoidColors: [String]
    ) -> [VisualizationPresetOption] {
        let hero = bestColors.first ?? "muted rose"
        let secondary = bestColors.dropFirst().first ?? "fresh sage"
        let avoid = avoidColors.first ?? "dull gray"

        let tonalHarmony = VisualizationPresetOption(
            title: "Monochrome Harmony",
            subtitle: "Head-to-toe \(hero) with layered textures.",
            prompt: """
            Swap clothing to a monochrome \(hero) set with layered textures. Keep fabric realistic with natural folds and a subtle sheen.
            """,
            swatchHex: "#e1b0c4"
        )

        let contrastPop = VisualizationPresetOption(
            title: "Contrast Pop",
            subtitle: "Add a statement \(secondary) jacket.",
            prompt: """
            Style a fitted base outfit in neutrals and add a \(secondary) statement layer. Maintain true-to-life fabric shadows and fit.
            """,
            swatchHex: "#a8dba8"
        )

        let eveningRefinement = VisualizationPresetOption(
            title: "Evening Elevation",
            subtitle: "Satin slip with tailored blazer.",
            prompt: """
            Transform the outfit into an elegant evening look with a satin slip dress and tailored blazer. Keep proportions flattering and realistic.
            """,
            swatchHex: "#c9b2f0"
        )

        let avoidToneFix = VisualizationPresetOption(
            title: "Color Correction",
            subtitle: "Remove \(avoid) cast from wardrobe.",
            prompt: """
            Replace any \(avoid) tones with balanced warm neutrals that complement the user's palette. Ensure lighting and shadows remain natural.
            """,
            swatchHex: "#f0d9b5"
        )

        return [tonalHarmony, contrastPop, eveningRefinement, avoidToneFix]
    }

    private static func accessoryOptions(accessoryBalance: Double) -> [VisualizationPresetOption] {
        let needsMore = accessoryBalance < 5

        let faceFramingJewelry = VisualizationPresetOption(
            title: "Face-Framing Jewelry",
            subtitle: "Add earrings that echo jawline angles.",
            prompt: """
            Introduce statement earrings that echo the face shape while staying proportional. Keep metal finish realistic and lighting consistent.
            """
        )

        let luxeLayering = VisualizationPresetOption(
            title: "Layered Neckline",
            subtitle: "Delicate layers highlighting the collarbone.",
            prompt: """
            Add layered necklaces with mixed textures that rest naturally across the collarbone. Maintain skin texture and avoid over-sharpening.
            """
        )

        let refinedHeadband = VisualizationPresetOption(
            title: "Sleek Headband",
            subtitle: "Polish the hairline with a satin band.",
            prompt: """
            Place a slim satin headband that matches the outfit palette, smoothing flyaways while retaining natural volume.
            """
        )

        let minimalistReset = VisualizationPresetOption(
            title: "Clean Minimalism",
            subtitle: "Tone down accessories for editorial focus.",
            prompt: """
            Remove busy accessories and leave a minimal, polished look with subtle sheen. Focus on highlighting facial architecture.
            """
        )

        return needsMore ? [faceFramingJewelry, luxeLayering, refinedHeadband, minimalistReset]
            : [minimalistReset, faceFramingJewelry, luxeLayering, refinedHeadband]
    }

    private static func finishingOptions(
        lightingType: String?,
        compositionFeedback: String?
    ) -> [VisualizationPresetOption] {
        let lighting = lightingType ?? "soft daylight"

        let editorialMatte = VisualizationPresetOption(
            title: "Editorial Matte",
            subtitle: "Tame shine but keep skin real.",
            prompt: """
            Apply a lightweight mattifying veil while preserving skin texture. Balance highlights on the nose, forehead, and chin to look camera-ready.
            """
        )

        let glowBoost = VisualizationPresetOption(
            title: "Glow Boost",
            subtitle: "Simulate \(lighting) bounce light.",
            prompt: """
            Enhance lighting to mimic \(lighting) with gentle rim light on the cheeks and hair. Increase vibrancy without flattening contrast.
            """
        )

        let cinematicCrop = VisualizationPresetOption(
            title: "Cinematic Crop",
            subtitle: "Refine composition & depth.",
            prompt: """
            Adjust framing to improve composition based on: \(compositionFeedback ?? "Center the subject gracefully with breathing space."). Add subtle depth-of-field blur to background only.
            """
        )

        let skinSmoothing = VisualizationPresetOption(
            title: "Texture Tidy",
            subtitle: "Diffuse texture, keep pores present.",
            prompt: """
            Smooth uneven texture while keeping pores visible and realistic. Avoid plastic sheen; maintain natural expressions and fine lines.
            """
        )

        return [glowBoost, editorialMatte, skinSmoothing, cinematicCrop]
    }
}
