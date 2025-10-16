//
//  VisualizationPresetGenerator.swift
//  glowup
//
//  Generates smart presets based on PhotoAnalysisVariables
//

import Foundation

struct VisualizationPresetGenerator {
    
    static func generatePresets(from analysis: PhotoAnalysisVariables) -> [VisualizationPresetCategory: [VisualizationPresetOption]] {
        var presets: [VisualizationPresetCategory: [VisualizationPresetOption]] = [:]
        
        // Generate hair style presets based on face shape
        presets[.hairStyles] = generateHairStylePresets(from: analysis)
        
        // Generate hair color presets based on seasonal palette
        presets[.hairColors] = generateHairColorPresets(from: analysis)
        
        // Generate makeup presets based on analysis
        presets[.makeup] = generateMakeupPresets(from: analysis)
        
        // Generate clothing presets based on best colors
        presets[.clothing] = generateClothingPresets(from: analysis)
        
        // Generate accessory presets
        presets[.accessories] = generateAccessoryPresets(from: analysis)
        
        // Generate style variation presets
        presets[.styleVariations] = generateStyleVariationPresets(from: analysis)
        
        return presets
    }
    
    // MARK: - Hair Style Presets
    
    private static func generateHairStylePresets(from analysis: PhotoAnalysisVariables) -> [VisualizationPresetOption] {
        let faceShape = analysis.faceShape?.lowercased() ?? ""
        let genderDimorphism = analysis.genderDimorphism.lowercased()
        
        var presets: [VisualizationPresetOption] = []
        
        // Face shape based recommendations
        if faceShape.contains("oval") || faceShape.contains("round") {
            presets.append(VisualizationPresetOption(
                title: "Long Layers",
                subtitle: "Flatters oval and round faces",
                prompt: "Change the hairstyle to long, face-framing layers that enhance the natural face shape. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairStyles
            ))
            
            presets.append(VisualizationPresetOption(
                title: "Side Part",
                subtitle: "Adds definition to round faces",
                prompt: "Change the hairstyle to a side-parted style that adds definition and length to the face. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairStyles
            ))
        }
        
        if faceShape.contains("square") || faceShape.contains("angular") {
            presets.append(VisualizationPresetOption(
                title: "Soft Waves",
                subtitle: "Softens angular features",
                prompt: "Change the hairstyle to soft, flowing waves that soften angular features. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairStyles
            ))
        }
        
        if faceShape.contains("heart") || faceShape.contains("triangle") {
            presets.append(VisualizationPresetOption(
                title: "Chin-Length Bob",
                subtitle: "Balances heart-shaped faces",
                prompt: "Change the hairstyle to a chin-length bob that balances the face shape. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairStyles
            ))
        }
        
        // Gender-appropriate styles
        if genderDimorphism.contains("feminine") || genderDimorphism.contains("female") {
            presets.append(VisualizationPresetOption(
                title: "Loose Curls",
                subtitle: "Natural, romantic look",
                prompt: "Change the hairstyle to loose, natural curls for a romantic and feminine look. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairStyles
            ))
        } else if genderDimorphism.contains("masculine") || genderDimorphism.contains("male") {
            presets.append(VisualizationPresetOption(
                title: "Textured Crop",
                subtitle: "Modern, professional look",
                prompt: "Change the hairstyle to a modern textured crop that's professional and stylish. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairStyles
            ))
        }
        
        // Fallback options
        if presets.isEmpty {
            presets.append(VisualizationPresetOption(
                title: "Natural Waves",
                subtitle: "Universal flattering style",
                prompt: "Change the hairstyle to natural, flowing waves that enhance the person's features. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairStyles
            ))
        }
        
        return presets
    }
    
    // MARK: - Hair Color Presets
    
    private static func generateHairColorPresets(from analysis: PhotoAnalysisVariables) -> [VisualizationPresetOption] {
        let seasonalPalette = analysis.seasonalPalette?.lowercased() ?? ""
        let currentHairColor = analysis.hairColor?.lowercased() ?? ""
        let bestColors = analysis.bestColors.map { $0.lowercased() }
        
        var presets: [VisualizationPresetOption] = []
        
        // Seasonal palette based colors
        if seasonalPalette.contains("spring") {
            presets.append(VisualizationPresetOption(
                title: "Golden Blonde",
                subtitle: "Perfect for Spring palette",
                prompt: "Change the hair color to a warm, golden blonde that complements the Spring color palette. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairColors
            ))
            
            presets.append(VisualizationPresetOption(
                title: "Copper Highlights",
                subtitle: "Warm Spring tones",
                prompt: "Add warm copper highlights to enhance the Spring palette colors. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairColors
            ))
        }
        
        if seasonalPalette.contains("summer") {
            presets.append(VisualizationPresetOption(
                title: "Ash Blonde",
                subtitle: "Cool Summer tones",
                prompt: "Change the hair color to a cool, ash blonde that complements the Summer color palette. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairColors
            ))
            
            presets.append(VisualizationPresetOption(
                title: "Soft Brown",
                subtitle: "Natural Summer color",
                prompt: "Change the hair color to a soft, natural brown with cool undertones. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairColors
            ))
        }
        
        if seasonalPalette.contains("autumn") {
            presets.append(VisualizationPresetOption(
                title: "Rich Auburn",
                subtitle: "Warm Autumn tones",
                prompt: "Change the hair color to a rich, warm auburn that complements the Autumn color palette. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairColors
            ))
            
            presets.append(VisualizationPresetOption(
                title: "Deep Chestnut",
                subtitle: "Warm brown with red undertones",
                prompt: "Change the hair color to a deep chestnut brown with warm red undertones. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairColors
            ))
        }
        
        if seasonalPalette.contains("winter") {
            presets.append(VisualizationPresetOption(
                title: "Jet Black",
                subtitle: "Bold Winter contrast",
                prompt: "Change the hair color to a deep, rich black that creates striking contrast. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairColors
            ))
            
            presets.append(VisualizationPresetOption(
                title: "Platinum Blonde",
                subtitle: "Cool Winter tones",
                prompt: "Change the hair color to a cool platinum blonde that complements the Winter palette. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairColors
            ))
        }
        
        // Best colors based recommendations
        if bestColors.contains(where: { $0.contains("gold") || $0.contains("amber") }) {
            presets.append(VisualizationPresetOption(
                title: "Honey Highlights",
                subtitle: "Matches your best colors",
                prompt: "Add honey-colored highlights that match your best colors. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairColors
            ))
        }
        
        // Fallback options
        if presets.isEmpty {
            presets.append(VisualizationPresetOption(
                title: "Natural Highlights",
                subtitle: "Subtle enhancement",
                prompt: "Add subtle natural highlights that enhance the current hair color. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality.",
                category: .hairColors
            ))
        }
        
        return presets
    }
    
    // MARK: - Makeup Presets
    
    private static func generateMakeupPresets(from analysis: PhotoAnalysisVariables) -> [VisualizationPresetOption] {
        let makeupStyle = analysis.makeupStyle.lowercased()
        let eyeColor = analysis.eyeColor?.lowercased() ?? ""
        let bestColors = analysis.bestColors.map { $0.lowercased() }
        
        var presets: [VisualizationPresetOption] = []
        
        // Style-based makeup
        if makeupStyle.contains("natural") || makeupStyle.contains("minimal") {
            presets.append(VisualizationPresetOption(
                title: "Natural Glow",
                subtitle: "Enhances natural beauty",
                prompt: "Apply natural makeup with subtle glow and definition. Use soft, neutral tones that enhance the natural features. Keep the person's face shape, hair, and clothing unchanged, maintaining the original photo quality.",
                category: .makeup
            ))
        }
        
        if makeupStyle.contains("glam") || makeupStyle.contains("dramatic") {
            presets.append(VisualizationPresetOption(
                title: "Glamorous Evening",
                subtitle: "Bold and sophisticated",
                prompt: "Apply glamorous evening makeup with bold eyes and defined features. Use rich, sophisticated colors that create drama. Keep the person's face shape, hair, and clothing unchanged, maintaining the original photo quality.",
                category: .makeup
            ))
        }
        
        // Eye color based makeup
        if eyeColor.contains("blue") || eyeColor.contains("green") {
            presets.append(VisualizationPresetOption(
                title: "Warm Eye Makeup",
                subtitle: "Complements cool eyes",
                prompt: "Apply warm-toned eye makeup that makes blue or green eyes pop. Use golds, bronzes, and warm browns. Keep the person's face shape, hair, and clothing unchanged, maintaining the original photo quality.",
                category: .makeup
            ))
        }
        
        if eyeColor.contains("brown") || eyeColor.contains("hazel") {
            presets.append(VisualizationPresetOption(
                title: "Cool Eye Makeup",
                subtitle: "Enhances brown eyes",
                prompt: "Apply cool-toned eye makeup that enhances brown or hazel eyes. Use purples, blues, and cool grays. Keep the person's face shape, hair, and clothing unchanged, maintaining the original photo quality.",
                category: .makeup
            ))
        }
        
        // Best colors based lip makeup
        if bestColors.contains(where: { $0.contains("red") || $0.contains("coral") }) {
            presets.append(VisualizationPresetOption(
                title: "Red Lip Classic",
                subtitle: "Matches your best colors",
                prompt: "Apply a classic red lipstick that matches your best colors. Keep the rest of the makeup natural and balanced. Keep the person's face shape, hair, and clothing unchanged, maintaining the original photo quality.",
                category: .makeup
            ))
        }
        
        // Fallback options
        if presets.isEmpty {
            presets.append(VisualizationPresetOption(
                title: "Soft Natural Look",
                subtitle: "Universal flattering makeup",
                prompt: "Apply soft, natural makeup that enhances the person's features without being overwhelming. Use neutral tones and subtle definition. Keep the person's face shape, hair, and clothing unchanged, maintaining the original photo quality.",
                category: .makeup
            ))
        }
        
        return presets
    }
    
    // MARK: - Clothing Presets
    
    private static func generateClothingPresets(from analysis: PhotoAnalysisVariables) -> [VisualizationPresetOption] {
        let bestColors = analysis.bestColors
        let avoidColors = analysis.avoidColors
        
        var presets: [VisualizationPresetOption] = []
        
        // Use best colors for clothing
        for color in bestColors.prefix(3) {
            presets.append(VisualizationPresetOption(
                title: "\(color.capitalized) Top",
                subtitle: "Matches your best colors",
                prompt: "Change the clothing to a stylish \(color) top that flatters the person's coloring. Keep the person's face, hair, and background exactly the same, maintaining the original photo quality.",
                category: .clothing
            ))
        }
        
        // Professional outfit
        presets.append(VisualizationPresetOption(
            title: "Professional Blazer",
            subtitle: "Business casual look",
            prompt: "Change the clothing to a professional blazer outfit suitable for business settings. Use colors that complement the person's palette. Keep the person's face, hair, and background exactly the same, maintaining the original photo quality.",
            category: .clothing
        ))
        
        // Casual outfit
        presets.append(VisualizationPresetOption(
            title: "Casual Chic",
            subtitle: "Relaxed but stylish",
            prompt: "Change the clothing to a casual but stylish outfit that's perfect for everyday wear. Use flattering colors and cuts. Keep the person's face, hair, and background exactly the same, maintaining the original photo quality.",
            category: .clothing
        ))
        
        return presets
    }
    
    // MARK: - Accessory Presets
    
    private static func generateAccessoryPresets(from analysis: PhotoAnalysisVariables) -> [VisualizationPresetOption] {
        let bestColors = analysis.bestColors
        let makeupStyle = analysis.makeupStyle.lowercased()
        
        var presets: [VisualizationPresetOption] = []
        
        // Statement jewelry
        if makeupStyle.contains("glam") || makeupStyle.contains("dramatic") {
            presets.append(VisualizationPresetOption(
                title: "Statement Earrings",
                subtitle: "Bold and glamorous",
                prompt: "Add bold statement earrings that complement the glamorous look. Keep the person's face, hair, and clothing unchanged, maintaining the original photo quality.",
                category: .accessories
            ))
        }
        
        // Delicate jewelry for natural looks
        if makeupStyle.contains("natural") || makeupStyle.contains("minimal") {
            presets.append(VisualizationPresetOption(
                title: "Delicate Necklace",
                subtitle: "Subtle and elegant",
                prompt: "Add a delicate, elegant necklace that enhances without overwhelming. Keep the person's face, hair, and clothing unchanged, maintaining the original photo quality.",
                category: .accessories
            ))
        }
        
        // Color-coordinated accessories
        for color in bestColors.prefix(2) {
            presets.append(VisualizationPresetOption(
                title: "\(color.capitalized) Scarf",
                subtitle: "Matches your palette",
                prompt: "Add a stylish \(color) scarf that complements the person's color palette. Keep the person's face, hair, and other clothing unchanged, maintaining the original photo quality.",
                category: .accessories
            ))
        }
        
        // Classic accessories
        presets.append(VisualizationPresetOption(
            title: "Classic Watch",
            subtitle: "Timeless elegance",
            prompt: "Add a classic, elegant watch that adds sophistication to the look. Keep the person's face, hair, and clothing unchanged, maintaining the original photo quality.",
            category: .accessories
        ))
        
        return presets
    }
    
    // MARK: - Style Variation Presets
    
    private static func generateStyleVariationPresets(from analysis: PhotoAnalysisVariables) -> [VisualizationPresetOption] {
        var presets: [VisualizationPresetOption] = []
        
        // Lighting variations
        presets.append(VisualizationPresetOption(
            title: "Golden Hour",
            subtitle: "Warm, flattering light",
            prompt: "Transform the lighting to golden hour with warm, flattering light that creates a natural glow. Keep the person's face, features, and clothing exactly the same, only changing the lighting.",
            category: .styleVariations
        ))
        
        presets.append(VisualizationPresetOption(
            title: "Studio Lighting",
            subtitle: "Professional portrait look",
            prompt: "Transform the lighting to professional studio lighting that creates even, flattering illumination. Keep the person's face, features, and clothing exactly the same, only changing the lighting.",
            category: .styleVariations
        ))
        
        // Style variations
        presets.append(VisualizationPresetOption(
            title: "Vintage Style",
            subtitle: "Classic, timeless look",
            prompt: "Transform the overall style to a vintage, timeless aesthetic while keeping the person's features and face shape unchanged. Apply vintage-inspired makeup and styling.",
            category: .styleVariations
        ))
        
        presets.append(VisualizationPresetOption(
            title: "Modern Minimalist",
            subtitle: "Clean, contemporary look",
            prompt: "Transform the overall style to modern minimalist aesthetic with clean lines and contemporary styling. Keep the person's features and face shape unchanged.",
            category: .styleVariations
        ))
        
        return presets
    }
}