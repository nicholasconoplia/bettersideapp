//
//  PersonalizedRecommendationBuilder.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import Foundation

struct PersonalizedRecommendationPlan: Codable {
    let shortTerm: [AppearanceActionTip]
    let longTerm: [AppearanceActionTip]
    let celebrityMatches: [CelebrityMatchSuggestion]
    let pinterestIdeas: [PinterestSearchIdea]
}

struct PersonalizedRecommendationBuilder {
    private let analysis: DetailedPhotoAnalysis
    private let vars: PhotoAnalysisVariables
    
    init(analysis: DetailedPhotoAnalysis) {
        self.analysis = analysis
        self.vars = analysis.variables
    }
    
    func buildPlan() -> PersonalizedRecommendationPlan {
        let short = buildShortTermTips()
        let long = buildLongTermProjects()
        let matches = buildCelebrityMatches()
        let pinterest = buildPinterestIdeas(short: short, long: long, matches: matches)
        return PersonalizedRecommendationPlan(
            shortTerm: short,
            longTerm: long,
            celebrityMatches: matches,
            pinterestIdeas: pinterest
        )
    }
    
    // MARK: - Short-Term (actionable within a shoot)
    
    private func buildShortTermTips() -> [AppearanceActionTip] {
        var tips: [AppearanceActionTip] = []
        
        if vars.lightingQuality < 7.0 || vars.lightingType.lowercased() != "natural" {
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Window-Light Reset",
                    body: "Face a window or soft light source and angle your shoulders 45° so light wraps evenly without harsh shadows.",
                    category: .shortTerm,
                    relatedQueries: [
                        "window light portrait pose ideas",
                        "soft natural lighting indoor selfies",
                        "how to find flattering window light"
                    ]
                )
            )
        }
        
        if vars.poseNaturalness < 7.0 || vars.angleFlatter < 6.5 {
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Angle Practice Drill",
                    body: "Run a 3-shot burst: chin down slightly, chin neutral, chin forward-and-down. Keep the angle that shows the sharpest jawline.",
                    category: .shortTerm,
                    relatedQueries: [
                        "best poses for \(vars.faceShape ?? "oval") face",
                        "camera angles to define jawline",
                        "posing flow for portraits at home"
                    ]
                )
            )
        }
        
        if vars.makeupSuitability < 7.0 {
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Complexion Touch-Up",
                    body: "Diffuse any shine on the T‑zone and tap a cream highlight on top of cheekbones to balance lighting quickly.",
                    category: .shortTerm,
                    relatedQueries: [
                        "quick photo ready complexion routine",
                        "cream highlighter for \(vars.skinUndertone ?? "neutral") undertones",
                        "shine control tips before photos"
                    ]
                )
            )
        }
        
        if vars.skinTextureScore < 7.0 {
            let highlight = vars.skinConcernHighlights.first?.lowercased() ?? "texture"
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Texture Prep Reset",
                    body: "Mist a hydrating spray, press a silicone-free blurring primer over \(highlight), then finish with a damp sponge to diffuse texture under bright light.",
                    category: .shortTerm,
                    relatedQueries: [
                        "instant texture smoothing before makeup",
                        "how to blur \(highlight) quickly",
                        "skin icing routine for photos"
                    ]
                )
            )
        }
        
        if vars.eyebrowDensityScore < 6.5 {
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Brow Lift Swipe",
                    body: "Backcomb brows upward with a clear lamination gel, then sketch hair-like strokes with a fine brow pen to simulate density on-camera.",
                    category: .shortTerm,
                    relatedQueries: [
                        "soap brows tutorial",
                        "clear brow gel laminated look",
                        "micro stroke brow pen technique"
                    ]
                )
            )
        }
        
        if vars.facialHarmonyScore < 6.5 {
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Soft Contour Alignment",
                    body: "Angle your key light 45° and tap a cream contour just under cheekbones, then brighten the inner eye with concealer to rebalance facial thirds.",
                    category: .shortTerm,
                    relatedQueries: [
                        "cream contour for \(vars.faceShape ?? "oval") face",
                        "how to balance facial thirds with makeup",
                        "lighting setup for stronger jawline"
                    ]
                )
            )
        }
        
        if vars.backgroundSuitability < 7.0 || vars.compositionFeedback.contains("clutter") {
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Backdrop Clean Sweep",
                    body: "Slide two steps away from busy objects or use a doorway corner so only one neutral background plane sits behind you.",
                    category: .shortTerm,
                    relatedQueries: [
                        "minimalist home photo backdrop ideas",
                        "how to blur background without portrait mode",
                        "DIY neutral backdrop setup"
                    ]
                )
            )
        }
        
        if tips.isEmpty {
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Finisher: Micro Adjustments",
                    body: "Roll shoulders back, relax your tongue on the roof of your mouth, and soften your lower lid for an instant energy lift.",
                    category: .shortTerm,
                    relatedQueries: [
                        "micro expression tips for confident photos",
                        "how to soften eyes in portraits",
                        "posture checklist before taking photos"
                    ]
                )
            )
        }
        
        return tips
    }
    
    // MARK: - Long-Term (projects / styling upgrades)
    
    private func buildLongTermProjects() -> [AppearanceActionTip] {
        var tips: [AppearanceActionTip] = []
        
        if vars.colorHarmony < 7.0 || vars.seasonalPalette == nil {
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Palette Capsule Refresh",
                    body: "Audit your closet for pieces in your strongest tones and plan a mini capsule with 5 tops and 2 jackets that stay within your palette.",
                    category: .longTerm,
                    relatedQueries: [
                        "capsule wardrobe for \(vars.seasonalPalette ?? "neutral") season",
                        "color analysis wardrobe planner",
                        "how to build photo-ready color palette outfits"
                    ]
                )
            )
        }
        
        if let palette = vars.seasonalPalette,
           let hairColor = vars.hairColor,
           needsPaletteAlignedHair(palette: palette, hairColor: hairColor) {
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Hair Tone Alignment",
                    body: "Book a salon gloss that shifts your \(hairColor.lowercased()) toward a \(recommendedHairTone(for: palette)) tone that flatters a \(palette.lowercased()) palette.",
                    category: .longTerm,
                    relatedQueries: [
                        "\(palette.lowercased()) season hair color ideas",
                        "\(recommendedHairTone(for: palette)) gloss inspiration",
                        "celebrity \(palette.lowercased()) palette hair transformations"
                    ]
                )
            )
        }
        
        if vars.skinTextureScore < 7.5 {
            let highlight = vars.skinConcernHighlights.first?.lowercased() ?? "texture"
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Skin Barrier Series",
                    body: "Commit to an 8-week routine with nightly gentle exfoliation and barrier-repair serums so \(highlight) smooths under daily light.",
                    category: .longTerm,
                    relatedQueries: [
                        "skin cycling plan for smoother texture",
                        "barrier repair routine for \(highlight)",
                        "dermatologist approved exfoliation schedule"
                    ]
                )
            )
        }
        
        if vars.eyebrowDensityScore < 7.5 {
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Brow Density Project",
                    body: "Map a 6-week brow growth plan: nightly peptide serum, weekly brow tint or henna, and monthly shaping to build a thicker frame.",
                    category: .longTerm,
                    relatedQueries: [
                        "peptide brow serum results timeline",
                        "brow tint vs henna for sparse brows",
                        "brow lamination maintenance guide"
                    ]
                )
            )
        }
        
        if vars.facialHarmonyScore < 7.0 {
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Feature Balancing Playbook",
                    body: "Audit hairstyles, parting, and accessory placement monthly to emphasize your strongest angles and create equilibrium in facial thirds.",
                    category: .longTerm,
                    relatedQueries: [
                        "best hair part for \(vars.faceShape ?? "oval") face",
                        "earring styles to balance facial thirds",
                        "soft contour techniques for facial harmony"
                    ]
                )
            )
        }
        
        if let blocker = vars.holdingBackFactors.first {
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Blocker Breakthrough",
                    body: "Design a monthly focus sprint around \"\(blocker)\": stack habit trackers, wardrobe tweaks, and weekly photo check-ins so progress is measurable.",
                    category: .longTerm,
                    relatedQueries: [
                        "habit tracker for beauty goals",
                        "monthly glow up challenge ideas",
                        "how to review photo progress weekly"
                    ]
                )
            )
        }
        
        if vars.lightingQuality < 7.5 {
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Lighting Toolkit Upgrade",
                    body: "Invest in a dimmable clamp light or compact ring light and practice three setups: window fill, bounce off a wall, and golden-hour reflector.",
                    category: .longTerm,
                    relatedQueries: [
                        "best affordable lighting kit for content creators",
                        "how to use reflectors for portraits",
                        "dimmable clamp light setup ideas"
                    ]
                )
            )
        }
        
        if vars.poseNaturalness < 7.5 {
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Gesture Library",
                    body: "Build a lookbook with 10 poses that highlight your \(vars.faceShape?.lowercased() ?? "face")—test them weekly and rate which ones feel effortless.",
                    category: .longTerm,
                    relatedQueries: [
                        "\(vars.faceShape ?? "oval") face posing ideas",
                        "dynamic posing prompts for portraits",
                        "how to build a personal posing library"
                    ]
                )
            )
        }
        
        if tips.isEmpty {
            tips.append(
                AppearanceActionTip(
                    id: UUID().uuidString,
                    title: "Signature Look Playbook",
                    body: "Document one signature makeup look, one daytime hair set, and one photo-ready outfit that always photograph well together.",
                    category: .longTerm,
                    relatedQueries: [
                        "signature makeup look planning worksheet",
                        "photo ready hair routine ideas",
                        "building a personal brand photo uniform"
                    ]
                )
            )
        }
        
        return tips
    }
    
    // MARK: - Celebrity Vibe Matches
    
    private func buildCelebrityMatches() -> [CelebrityMatchSuggestion] {
        guard let palette = vars.seasonalPalette else { return [] }
        let normalizedHair = (vars.hairColor ?? "").lowercased()
        let normalizedEyes = (vars.eyeColor ?? "").lowercased()
        let normalizedShape = (vars.faceShape ?? "").lowercased()
        
        var matches: [CelebrityMatchSuggestion] = []
        let templates = celebrityTemplates(for: palette)
        
        for template in templates {
            var descriptor = template.baseDescriptor
            if !normalizedShape.isEmpty {
                descriptor += " • \(normalizedShape.capitalized) face"
            }
            if !normalizedEyes.isEmpty {
                descriptor += " • \(normalizedEyes.capitalized) eyes"
            }
            
            let why = buildWhyStatement(for: template, hair: normalizedHair, eyes: normalizedEyes)
            let queries = template.queryKeywords.map { keyword in
                "\(template.name) \(keyword)"
            }
            
            matches.append(
                CelebrityMatchSuggestion(
                    id: UUID().uuidString,
                    name: template.name,
                    descriptor: descriptor,
                    whyItWorks: why,
                    pinterestQueries: queries
                )
            )
        }
        
        return matches
    }
    
    // MARK: - Pinterest Search
    
    private func buildPinterestIdeas(
        short: [AppearanceActionTip],
        long: [AppearanceActionTip],
        matches: [CelebrityMatchSuggestion]
    ) -> [PinterestSearchIdea] {
        var collected = Set<String>()
        var ideas: [PinterestSearchIdea] = []
        
        for tip in short + long {
            for query in tip.relatedQueries {
                if collected.insert(query).inserted {
                    ideas.append(PinterestSearchIdea(label: query.capitalized, query: query))
                }
            }
        }
        
        for match in matches {
            for query in match.pinterestQueries {
                if collected.insert(query).inserted {
                    ideas.append(PinterestSearchIdea(label: query.capitalized, query: query))
                }
            }
        }
        
        return ideas
    }
    
    // MARK: - Helpers
    
    private func needsPaletteAlignedHair(palette: String, hairColor: String) -> Bool {
        let hair = hairColor.lowercased()
        switch palette {
        case "Spring":
            return hair.contains("ash") || hair.contains("black")
        case "Summer":
            return hair.contains("warm") || hair.contains("copper") || hair.contains("gold")
        case "Autumn":
            return hair.contains("ash") || hair.contains("platinum")
        case "Winter":
            return hair.contains("warm") || hair.contains("honey") || hair.contains("copper")
        default:
            return false
        }
    }
    
    private func recommendedHairTone(for palette: String) -> String {
        switch palette {
        case "Spring": return "sunlit caramel"
        case "Summer": return "cool smoky"
        case "Autumn": return "rich coppery"
        case "Winter": return "glossy espresso"
        default: return "balanced"
        }
    }
    
    private func buildWhyStatement(for template: CelebrityTemplate, hair: String, eyes: String) -> String {
        var components: [String] = []
        components.append(template.reason)
        
        if !hair.isEmpty {
            components.append("Try referencing how \(template.name.split(separator: " ").first ?? Substring("they")) styles \(hair) hair in editorials.")
        }
        if !eyes.isEmpty {
            components.append("Notice their eye styling—search looks that highlight \(eyes) eyes with similar palettes.")
        }
        return components.joined(separator: " ")
    }
    
    private func celebrityTemplates(for palette: String) -> [CelebrityTemplate] {
        switch palette {
        case "Spring":
            return [
                CelebrityTemplate(
                    name: "Blake Lively",
                    baseDescriptor: "Fresh spring radiance",
                    reason: "She leans into luminous peach-gold tones that flatter warm complexions.",
                    queryKeywords: ["spring makeup", "blowout tutorial", "glow outfit"]
                ),
                CelebrityTemplate(
                    name: "Jessica Chastain",
                    baseDescriptor: "Warm cinematic glam",
                    reason: "Rust and coral styling show how to emphasize warm undertones with polished silhouettes.",
                    queryKeywords: ["copper hair color", "warm wardrobe palette", "beauty look tutorial"]
                )
            ]
        case "Summer":
            return [
                CelebrityTemplate(
                    name: "Gemma Chan",
                    baseDescriptor: "Cool summer elegance",
                    reason: "She pairs soft charcoal eyes with muted pastels to stay luminous without heavy contrast.",
                    queryKeywords: ["muted pastel outfits", "cool tone makeup", "soft wave hair"]
                ),
                CelebrityTemplate(
                    name: "Saoirse Ronan",
                    baseDescriptor: "Ethereal soft glam",
                    reason: "Her pearlescent skin and brushed-up brows show how to keep light, airy definition.",
                    queryKeywords: ["soft glam tutorial", "summer palette style", "pearl highlight makeup"]
                )
            ]
        case "Autumn":
            return [
                CelebrityTemplate(
                    name: "Zendaya",
                    baseDescriptor: "Spiced autumn power",
                    reason: "She uses burnished metals and warm tailoring to spotlight deep autumn coloring.",
                    queryKeywords: ["bronze makeup look", "autumn wardrobe inspiration", "voluminous curls tutorial"]
                ),
                CelebrityTemplate(
                    name: "Eva Mendes",
                    baseDescriptor: "Golden sunset glam",
                    reason: "Caramel contouring and honey highlights keep her glow warm and dimensional.",
                    queryKeywords: ["honey balayage ideas", "warm glam makeup", "autumn color blocking"]
                )
            ]
        case "Winter":
            return [
                CelebrityTemplate(
                    name: "Lupita Nyong'o",
                    baseDescriptor: "High-contrast brilliance",
                    reason: "She balances jewel tones with sculpted shapes—perfect for winter palettes.",
                    queryKeywords: ["jewel tone outfits", "winter palette makeup", "bold lip tutorial"]
                ),
                CelebrityTemplate(
                    name: "Anne Hathaway",
                    baseDescriptor: "Tailored winter polish",
                    reason: "Crisp monochrome looks and cool smokey eyes highlight her icy undertones.",
                    queryKeywords: ["winter monochrome style", "cool smokey eye", "sleek bob inspiration"]
                )
            ]
        default:
            return [
                CelebrityTemplate(
                    name: "JLo",
                    baseDescriptor: "Universal glow",
                    reason: "Classic glam references that translate across palettes and undertones.",
                    queryKeywords: ["glow makeup tutorial", "voluminous wave hair", "glam outfit inspiration"]
                )
            ]
        }
    }
}

// MARK: - Templates

private struct CelebrityTemplate {
    let name: String
    let baseDescriptor: String
    let reason: String
    let queryKeywords: [String]
}
