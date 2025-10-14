//
//  OpenAIService.swift
//  glowup
//
//  Created by AI Assistant
//

import CoreData
import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct PhotoAnalysisBundle {
    let face: Data
    let skin: Data
    let eyes: Data
}

private struct VisionImageAttachment {
    let descriptor: String
    let base64: String
}

struct PhotoAnalysisInput {
    let persona: CoachPersona
    let bundle: PhotoAnalysisBundle
    let quizResult: QuizResult?
}

// MARK: - Analysis Variables Structure

struct PhotoAnalysisVariables: Codable {
    // Physical Features (nullable if AI can't detect)
    let faceShape: String?
    let skinUndertone: String?
    let eyeColor: String?
    let hairColor: String?
    
    // Facial Structure & Harmony
    let facialHarmonyScore: Double     // 0-10
    let featureBalanceDescription: String
    let genderDimorphism: String       // "Feminine", "Masculine", "Androgynous", etc.
    let facialAngularityScore: Double  // 0-10 (higher means sharper angles)
    let faceFullnessDescriptor: String // "Lean", "Balanced", "Soft", etc.

    // Technical Photo Quality
    let lightingQuality: Double        // 0-10
    let lightingType: String           // "Natural", "Artificial", "Mixed", "Golden Hour"
    let lightingDirection: String      // "Front", "Side", "Backlit", "Overhead"
    let exposure: String               // "Underexposed", "Perfect", "Overexposed"
    
    // Aesthetic Harmony
    let colorHarmony: Double           // 0-10
    let overallComposition: Double     // 0-10
    let backgroundSuitability: Double  // 0-10
    
    // Style & Presentation
    let makeupSuitability: Double      // 0-10 (0 if no makeup)
    let makeupStyle: String            // "Natural", "Glam", "Dramatic", "None"
    let outfitColorMatch: Double       // 0-10
    let accessoryBalance: Double       // 0-10
    
    // Skin & Texture
    let skinTextureScore: Double       // 0-10
    let skinTextureDescription: String
    let skinConcernHighlights: [String]
    
    // Brows & Framing
    let eyebrowDensityScore: Double    // 0-10
    let eyebrowFeedback: String

    // Posing & Expression
    let poseNaturalness: Double        // 0-10
    let angleFlatter: Double           // 0-10
    let facialExpression: String       // "Confident", "Natural", "Forced", "Relaxed"
    let eyeContact: String             // "Direct", "Averted", "Soft", "Intense"
    
    // Color Analysis (nullable if unclear)
    let seasonalPalette: String?       // "Spring", "Summer", "Autumn", "Winter"
    let bestColors: [String]           // Recommended color palette
    let avoidColors: [String]          // Colors to avoid
    
    // Confidence & Presence
    let confidenceScore: Double        // 0-10
    let overallGlowScore: Double       // 0-10
    
    // Personalized Recommendations
    let strengthAreas: [String]        // What's working well
    let improvementAreas: [String]     // What needs work
    let bestTraits: [String]           // Explicit best traits breakdown
    let traitsToImprove: [String]      // Traits needing refinement (soft max focus)
    let holdingBackFactors: [String]   // Key blockers holding the user back
    let roadmap: [ImprovementRoadmapStep]
    let quickWins: [String]            // Easy immediate improvements
    let longTermGoals: [String]        // Strategic improvements
    let foundationalHabits: [String]   // Tailored zero-cost lifestyle resets
    
    // AI-Generated Feedback Sections (nullable if detection failed)
    let lightingFeedback: String
    let eyeColorFeedback: String?
    let skinToneFeedback: String?
    let hairColorFeedback: String?
    let poseFeedback: String
    let makeupFeedback: String
    let compositionFeedback: String
}

struct DetailedPhotoAnalysis: Codable {
    let variables: PhotoAnalysisVariables
    let summary: String
    let personalizedTips: [String]
    let isFallback: Bool
}

// MARK: - OpenAI Service

actor OpenAIService {
    static let shared = OpenAIService()
    
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let session: URLSession
    private let analysisResponseFormat: [String: Any] = ["type": "json_object"]
    private let fallbackSummaryDefault = "We're still processing your photo. Keep this view open and we'll update your glow score automatically."
    private let fallbackTipsDefault = [
        "Keep your device awake and connected while we finish the photo analysis",
        "If nothing changes after a few minutes, tap retry or upload a crisper photo with your face well lit",
        "For best results, use a recent photo where your features are clearly visible"
    ]
    
    private var apiKey: String? {
        Secrets.openAIApiKey
    }
    
    init(session: URLSession = .shared) {
        if session === URLSession.shared {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 240
            configuration.timeoutIntervalForResource = 300
            configuration.waitsForConnectivity = true
            self.session = URLSession(configuration: configuration)
        } else {
            self.session = session
        }
    }
    
    // MARK: - Main Photo Analysis
    
    func analyzePhoto(_ input: PhotoAnalysisInput) async -> DetailedPhotoAnalysis {
        var fallbackSummary: String?
        var fallbackTips: [String]?
        
        do {
            let faceEncoded = encodeImageData(
                input.bundle.face,
                maxDimension: 1024,
                compressionQuality: 0.75
            )
            let skinEncoded = encodeImageData(
                input.bundle.skin,
                maxDimension: 768,
                compressionQuality: 0.8
            )
            let eyeEncoded = encodeImageData(
                input.bundle.eyes,
                maxDimension: 768,
                compressionQuality: 0.8
            )
            let attachments = [
                VisionImageAttachment(descriptor: "Face reference portrait", base64: faceEncoded.base64),
                VisionImageAttachment(descriptor: "Skin texture close-up", base64: skinEncoded.base64),
                VisionImageAttachment(descriptor: "Eye detail close-up", base64: eyeEncoded.base64)
            ]
            
            print("\n========== [OpenAIService] PHOTO ANALYSIS START ==========")
            print("[OpenAIService] Encoded face image size: \(faceEncoded.base64.count) characters")
            print("[OpenAIService] Encoded skin image size: \(skinEncoded.base64.count) characters")
            print("[OpenAIService] Encoded eye image size: \(eyeEncoded.base64.count) characters")
            
            let prompt = buildAnalysisPrompt(for: input)
            print("[OpenAIService] Prompt length: \(prompt.count) characters")
            print("[OpenAIService] Calling GPT-4 Vision API...")
            
            let response = try await callGPT4Vision(prompt: prompt, attachments: attachments)
            
            print("[OpenAIService] ✅ GPT-4 Vision response received!")
            print("[OpenAIService] Response length: \(response.count) characters")
            print("[OpenAIService] Response preview:\n\(response.prefix(800))...")
            
            if let analysis = parseAnalysisResponse(response) {
                print("[OpenAIService] ✅ Successfully parsed analysis!")
                print("[OpenAIService] Glow Score: \(analysis.variables.overallGlowScore)/10")
                print("[OpenAIService] Confidence: \(analysis.variables.confidenceScore)/10")
                print("[OpenAIService] Face Shape: \(analysis.variables.faceShape ?? "Not detected")")
                print("[OpenAIService] Seasonal Palette: \(analysis.variables.seasonalPalette ?? "Not detected")")
                print("[OpenAIService] Eye Color: \(analysis.variables.eyeColor ?? "Not detected")")
                print("[OpenAIService] Lighting Quality: \(analysis.variables.lightingQuality)/10")
                print("[OpenAIService] Summary: \(analysis.summary)")
                print("========== [OpenAIService] ANALYSIS COMPLETE ==========\n")
                return analysis
            } else {
                print("[OpenAIService] ❌ Failed to parse JSON response")
                print("[OpenAIService] Full response:\n\(response)")
                print("[OpenAIService] Attempting to extract JSON...")
                fallbackSummary = "We reached GPT-4 Vision, but the response wasn't valid JSON. Please try again in a moment."
            }
        } catch let error as OpenAIError {
            print("[OpenAIService] ❌ OpenAI API Error: \(error)")
            switch error {
            case .apiKeyMissing:
                print("[OpenAIService] Missing API key. Set OPENAI_API_KEY in Secrets.plist, Info.plist overrides, or environment.")
                fallbackSummary = "Your OpenAI API key is missing. Add it in Secrets.plist, Info.plist overrides, or the OPENAI_API_KEY environment variable."
                fallbackTips = [
                    "Open Secrets.plist and paste a valid OpenAI key under OPENAI_API_KEY",
                    "Alternatively, set the OPENAI_API_KEY environment variable in your Xcode scheme",
                    "Re-run the photo analysis once a valid key is in place"
                ]
            case .apiError(let code, let message):
                print("[OpenAIService] HTTP \(code): \(message)")
                let cleanMessage = message.isEmpty ? "Check your key and network connection, then try again." : message
                fallbackSummary = "OpenAI returned HTTP \(code). \(cleanMessage)"
            case .invalidResponse:
                print("[OpenAIService] Invalid response from API")
                fallbackSummary = "OpenAI sent back a response we couldn't understand. Please retry the analysis."
            case .emptyResponse:
                print("[OpenAIService] Empty response from API")
                fallbackSummary = "OpenAI returned an empty response. Try again with a smaller photo or wait a few seconds."
            case .refused(let reason):
                print("[OpenAIService] OpenAI refused the request: \(reason)")
                fallbackSummary = "OpenAI declined to analyze this image: \(reason)"
                fallbackTips = [
                    "Use a clear photo that follows OpenAI's usage policies",
                    "Avoid illustrations or sensitive content that may trigger a refusal",
                    "Try another photo with more neutral framing and lighting"
                ]
            }
        } catch {
            print("[OpenAIService] ❌ Unexpected error: \(error.localizedDescription)")
            print("[OpenAIService] Error details: \(error)")
            fallbackSummary = "We hit a delay (\(error.localizedDescription)). Leave this screen open and we'll keep trying in the background."
        }
        
        print("[OpenAIService] ⚠️ FALLING BACK TO MOCK ANALYSIS")
        print("[OpenAIService] This means the API call failed - check logs above")
        return createFallbackAnalysis(
            for: input.persona,
            summary: fallbackSummary,
            tips: fallbackTips
        )
    }
    
    // MARK: - Tips Generation
    
    func generateTips(profile: GlowProfile?, quiz: QuizResult?, mode: TipMode) async -> [GeneratedTip] {
        do {
            let prompt = buildTipsPrompt(profile: profile, quiz: quiz, mode: mode)
            let response = try await callGPT4(prompt: prompt)
            
            if let tipsPayload: TipsResponse = parseJSON(from: response) {
                return tipsPayload.tips.map { tip in
                    GeneratedTip(
                        id: tip.id ?? UUID().uuidString,
                        title: tip.title,
                        body: tip.body,
                        source: "GPT-4",
                        type: tip.type
                    )
                }
            }
        } catch let error as OpenAIError {
            switch error {
            case .apiKeyMissing:
                print("[OpenAIService] Tips generation skipped - missing API key.")
            case .apiError(let code, let message):
                print("[OpenAIService] Tips API error (\(code)): \(message)")
            case .invalidResponse, .emptyResponse:
                print("[OpenAIService] Tips API returned invalid response: \(error)")
            case .refused(let reason):
                print("[OpenAIService] Tips request refused: \(reason)")
            }
        } catch {
            print("[OpenAIService] Tips generation failed: \(error)")
        }
        
        return createFallbackTips(for: mode)
    }
    
    // MARK: - Conversational Coaching
    
    func respond(to message: String, persona: CoachPersona) async -> String {
        let prompt = """
        You are a \(persona.displayName) photo coach. The user asks: "\(message)"
        
        Respond in 1-2 sentences with actionable advice in the persona's voice.
        """
        
        do {
            let response = try await callGPT4(prompt: prompt)
            return response
        } catch {
            return persona.fallbackResponse
        }
    }
    
    // MARK: - API Calls
    
    private func callGPT4Vision(prompt: String, attachments: [VisionImageAttachment]) async throws -> String {
        print("[OpenAIService] Building API request...")
        
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            print("[OpenAIService] ❌ Missing OpenAI API key")
            print("[OpenAIService] Check: Secrets.plist, Info.plist overrides, or OPENAI_API_KEY env variable")
            throw OpenAIError.apiKeyMissing
        }
        
        // Debug: Show key prefix (first 10 chars) to verify it's loaded
        let keyPrefix = String(apiKey.prefix(10))
        print("[OpenAIService] API Key loaded: \(keyPrefix)... (length: \(apiKey.count))")
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 210  // allow long-running vision responses
        
        print("[OpenAIService] Request URL: \(baseURL.absoluteString)")
        print("[OpenAIService] Request headers set: Content-Type, Authorization")
        print("[OpenAIService] Attachments count: \(attachments.count)")
        
        var contentBlocks: [[String: Any]] = [
            [
                "type": "text",
                "text": prompt
            ]
        ]
        
        for attachment in attachments {
            contentBlocks.append([
                "type": "text",
                "text": "[\(attachment.descriptor)]"
            ])
            contentBlocks.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(attachment.base64)",
                    "detail": "high"
                ]
            ])
        }
        
        var payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": contentBlocks
                ]
            ],
            "max_tokens": 2000,
            "temperature": 0.7
        ]
        payload["response_format"] = analysisResponseFormat
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("[OpenAIService] ❌ Failed to serialize JSON payload: \(error)")
            throw OpenAIError.invalidResponse
        }
        
        let payloadSize = request.httpBody?.count ?? 0
        print("[OpenAIService] Request payload size: \(payloadSize) bytes")
        for attachment in attachments.enumerated() {
            print("[OpenAIService] Attachment \(attachment.offset + 1) base64 size: \(attachment.element.base64.count) characters")
        }
        print("[OpenAIService] Making API call to OpenAI...")
        print("[OpenAIService] Using model: gpt-4o")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as NSError {
            print("[OpenAIService] ❌ Network request failed!")
            print("[OpenAIService] Error domain: \(error.domain)")
            print("[OpenAIService] Error code: \(error.code)")
            print("[OpenAIService] Error description: \(error.localizedDescription)")
            if error.domain == NSURLErrorDomain {
                switch error.code {
                case NSURLErrorNotConnectedToInternet:
                    print("[OpenAIService] → Device is not connected to the internet")
                case NSURLErrorTimedOut:
                    print("[OpenAIService] → Request timed out")
                case NSURLErrorCannotFindHost:
                    print("[OpenAIService] → Cannot find host (DNS issue)")
                case NSURLErrorCannotConnectToHost:
                    print("[OpenAIService] → Cannot connect to host")
                case NSURLErrorNetworkConnectionLost:
                    print("[OpenAIService] → Network connection lost")
                case NSURLErrorAppTransportSecurityRequiresSecureConnection:
                    print("[OpenAIService] → App Transport Security blocking connection")
                default:
                    print("[OpenAIService] → Network error code: \(error.code)")
                }
            }
            throw error
        }
        
        print("[OpenAIService] Received response from OpenAI")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[OpenAIService] ❌ Invalid HTTP response")
            throw OpenAIError.invalidResponse
        }
        
        print("[OpenAIService] HTTP Status Code: \(httpResponse.statusCode)")
        
        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? ""
            print("[OpenAIService] ❌ API Error (\(httpResponse.statusCode)):")
            print("[OpenAIService] Response: \(message)")
            throw OpenAIError.apiError(code: httpResponse.statusCode, message: message)
        }
        
        print("[OpenAIService] ✅ Success! Parsing response...")
        
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("[OpenAIService] Raw API response:\n\(rawResponse.prefix(1000))")
        }
        
        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let message = result.choices.first?.message else {
            print("[OpenAIService] ❌ No message in response")
            throw OpenAIError.emptyResponse
        }
        
        if let content = message.textContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           !content.isEmpty {
            print("[OpenAIService] ✅ Extracted content from response")
            return content
        }
        
        if let refusal = message.refusal {
            print("[OpenAIService] ❌ OpenAI refusal: \(refusal)")
            throw OpenAIError.refused(reason: refusal)
        }
        
        print("[OpenAIService] ❌ No usable content in response")
        throw OpenAIError.emptyResponse
    }
    
    private func callGPT4(prompt: String) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw OpenAIError.apiKeyMissing
        }
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1000,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw OpenAIError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let message = result.choices.first?.message else {
            throw OpenAIError.emptyResponse
        }
        
        if let content = message.textContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           !content.isEmpty {
            return content
        }
        
        if let refusal = message.refusal {
            throw OpenAIError.refused(reason: refusal)
        }
        
        throw OpenAIError.emptyResponse
    }
    
    // MARK: - Prompt Building
    
    private func buildAnalysisPrompt(for input: PhotoAnalysisInput) -> String {
        var contextLines: [String] = []
        
        if let quiz = input.quizResult {
            if let concern = quiz.answers["mirror_focus"]?.first {
                contextLines.append("User focus area: \(concern)")
            }
            if let goal = quiz.primaryGoal {
                contextLines.append("Goal: \(goal)")
            }
        }
        
        let context = contextLines.isEmpty ? "" : "\nUser Context: \(contextLines.joined(separator: ", "))"
        
        return """
        You are an expert beauty and photo analysis AI. You have three images captured in this order: [Face reference portrait], [Skin texture close-up], [Eye detail close-up]. Cross-reference all attachments to judge structure, skin, and eyes. Never guess beyond the pixels.
        \(context)
        
        Principles:
        - Base every statement on the imagery. If something is unclear, return "Unknown" (strings) or 0.0 (scores) and explain the limitation.
        - When hair details are partially occluded, inspect the root, mid-length, and highlight tones; output the closest descriptive color phrase (e.g., "dark espresso brown", "honey blond"). Only use null if the hair is fully hidden.
        - All numeric scores must be on a 0-10 scale with one decimal place.
        - Improvements must be **soft-maxing only** (makeup, skincare, grooming, styling, lighting, posture, lifestyle). Never mention surgical or injectable options.
        - The roadmap must be staged (e.g., "This week", "30 days", "90 days") and each step must include concrete soft-max actions connected to the measured metrics.
        
        SEASONAL COLOR ANALYSIS RULES (CRITICAL):
        Determine seasonalPalette by analyzing THREE KEY FACTORS from the images:
        
        1. UNDERTONE (Warm vs Cool):
           - Analyze skin tone in the close-up: Does it have golden/peachy warmth or pink/blue coolness?
           - Cross-reference with vein color if visible (warm = greenish veins, cool = blue/purple veins)
           - Hair natural tones: Warm has golden/red/auburn highlights, Cool has ash/blue-black tones
           - Eye color: Warm often has golden, amber, hazel, warm brown; Cool has blue, gray, violet, cool brown
        
        2. VALUE (Light vs Deep):
           - Overall lightness/darkness of hair, skin, and eyes together
           - Light: Blonde/light brown hair + light eyes + fair-to-medium skin
           - Deep: Dark brown/black hair + dark eyes + medium-to-deep skin
        
        3. CHROMA (Clear/Bright vs Muted/Soft):
           - Clear: High contrast between features, vibrant coloring, pure color tones
           - Muted: Low contrast, soft blended features, dusty/grayed color tones
        
        SEASON DETERMINATION:
        - Spring: Warm undertone + Light-to-Medium value + Clear/Bright chroma
          Example: Light golden blonde hair, bright blue/green eyes, peachy skin, freckles
        
        - Summer: Cool undertone + Light-to-Medium value + Muted/Soft chroma
          Example: Ash blonde/brown hair, soft blue/gray/green eyes, pink-toned skin, low contrast
        
        - Autumn: Warm undertone + Medium-to-Deep value + Muted/Rich chroma
          Example: Auburn/chestnut/dark brown hair with warm tones, hazel/brown eyes, golden/olive skin
        
        - Winter: Cool undertone + Deep value OR High Contrast + Clear/Bright chroma
          Example: Black/dark brown hair, striking blue/dark brown eyes, cool-toned skin, high contrast
        
        Cross-validate: Hair + Skin + Eyes must align with the chosen season. If conflicting signals, choose the season that matches 2 out of 3 factors, or return null if truly ambiguous.
        
        Output ONLY valid JSON (no markdown, no extra text) with this exact structure:
        {
          "faceShape": "Oval/Round/Square/Heart/Diamond/Oblong or null",
          "skinUndertone": "Warm/Cool/Neutral or null",
          "eyeColor": "Brown/Blue/Green/Hazel/etc. or null",
          "hairColor": "descriptive string (include depth + tone, only null if hair fully hidden)",
          "facialHarmonyScore": number (0-10),
          "featureBalanceDescription": "string referencing facial thirds, symmetry, and proportional harmony",
          "genderDimorphism": "Feminine/Masculine/Androgynous/Mixed with a short qualifier",
          "facialAngularityScore": number (0-10 where 10 = highly angular),
          "faceFullnessDescriptor": "Lean/Balanced/Soft/Puffy/etc.",
          "lightingQuality": number (0-10),
          "lightingType": "Natural/Artificial/Mixed/Golden Hour/Unknown",
          "lightingDirection": "Front/Side/Backlit/Overhead/Unknown",
          "exposure": "Underexposed/Perfect/Overexposed",
          "colorHarmony": number (0-10),
          "overallComposition": number (0-10),
          "backgroundSuitability": number (0-10),
          "makeupSuitability": number (0-10),
          "makeupStyle": "Natural/Glam/Dramatic/None/Minimal",
          "outfitColorMatch": number (0-10),
          "accessoryBalance": number (0-10),
          "skinTextureScore": number (0-10),
          "skinTextureDescription": "string detailing clarity, texture, pores from the close-up",
          "skinConcernHighlights": ["array of concise bullet points about texture/clarity issues"],
          "eyebrowDensityScore": number (0-10),
          "eyebrowFeedback": "string describing density, symmetry, grooming opportunities",
          "poseNaturalness": number (0-10),
          "angleFlatter": number (0-10),
          "facialExpression": "Confident/Natural/Forced/Relaxed/etc.",
          "eyeContact": "Direct/Averted/Soft/Intense/etc.",
          "seasonalPalette": "Spring/Summer/Autumn/Winter or null (use SEASONAL COLOR ANALYSIS RULES above)",
          "bestColors": ["array of 8-12 specific color names matching the determined season - for Spring use warm bright colors like coral, peach, golden yellow; for Summer use cool muted colors like soft blue, lavender, rose; for Autumn use warm muted colors like olive, rust, camel; for Winter use cool bright colors like royal blue, emerald, magenta"],
          "avoidColors": ["array of 4-6 color names that clash with the season - opposite undertone colors"],
          "confidenceScore": number (0-10),
          "overallGlowScore": number (0-10),
          "strengthAreas": ["array of strengths tied to measured metrics"],
          "improvementAreas": ["array of improvement themes tied to measured metrics"],
          "bestTraits": ["array highlighting standout traits and why they work"],
          "traitsToImprove": ["array highlighting traits to refine with soft-max tactics"],
          "holdingBackFactors": ["array explaining what is holding the user back right now"],
          "roadmap": [
            {
              "timeframe": "This week/30 days/90 days/etc.",
              "focus": "string summarizing the priority area",
              "actions": ["array of 2-4 concrete soft-max steps (skincare, makeup, grooming, lighting practice, lifestyle)"]
            }
          ],
          "quickWins": ["array of immediate soft-max tweaks for today"],
          "longTermGoals": ["array of strategic improvements (still non-surgical)"],
          "foundationalHabits": ["array of 3-5 zero-cost lifestyle resets (hydration, sleep, sunlight, nutrition) tied to the lowest-scoring areas"],
          "summary": "2-3 sentence overall assessment referencing key scores",
          "personalizedTips": ["array of 3-5 persona-aligned coaching tips"],
          "lightingFeedback": "2-3 paragraph lighting analysis referencing scores",
          "eyeColorFeedback": "2-3 paragraph eye color & brow framing guidance, mention how eye color influenced seasonal determination" or null,
          "skinToneFeedback": "2-3 paragraph undertone/season guidance - EXPLAIN the seasonal determination: state the undertone (warm/cool), value (light/deep), chroma (clear/muted) observed, and WHY this led to the chosen season. Reference vein color theory if relevant" or null,
          "hairColorFeedback": "2-3 paragraph hair harmony guidance" or null,
          "poseFeedback": "2-3 paragraph posing/angles/expression feedback",
          "makeupFeedback": "2-3 paragraph makeup strategy (soft-max only)",
          "compositionFeedback": "2-3 paragraph background/framing feedback"
        }
        
        For every feedback field: write complete, supportive paragraphs that cite the relevant scores or detected attributes. If any upstream value is Unknown/null, set the related feedback field to null and call out the limitation in the summary.
        
        Keep the tone direct, encouraging, and rooted in soft-maxing strategies only.
        """
    }
    
    private func buildTipsPrompt(profile: GlowProfile?, quiz: QuizResult?, mode: TipMode) -> String {
        var lines: [String] = []
        
        if let profile = profile {
            if let shape = profile.faceShape { lines.append("Face: \(shape)") }
            if let palette = profile.colorPalette { lines.append("Palette: \(palette)") }
        }
        
        let modeDesc = mode == .shortTerm ? "quick daily actions" : "long-term strategic improvements"
        let tipType = mode == .shortTerm ? "short" : "long"
        
        return """
        Generate \(modeDesc) for a beauty/confidence coaching app.
        User context: \(lines.joined(separator: ", "))
        
        Return ONLY valid JSON:
        {
          "tips": [
            {"id": "uuid", "title": "Catchy Title", "body": "1-2 sentence action", "type": "\(tipType)"}
          ]
        }
        
        Provide 3 tips.
        """
    }
    
    // MARK: - Response Parsing
    
    private func parseAnalysisResponse(_ text: String) -> DetailedPhotoAnalysis? {
        print("[OpenAIService] Parsing analysis response...")
        
        // Try to extract JSON if wrapped in markdown or extra text
        let cleanedText: String
        if let jsonRange = text.firstJSONRange {
            cleanedText = String(text[jsonRange])
            print("[OpenAIService] Extracted JSON from response (found { } markers)")
        } else {
            cleanedText = text
            print("[OpenAIService] Using full response as JSON")
        }
        
        print("[OpenAIService] JSON to parse:\n\(cleanedText.prefix(500))...")
        
        guard let data = cleanedText.data(using: .utf8) else {
            print("[OpenAIService] ❌ Could not convert response to data")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            print("[OpenAIService] Attempting to decode AnalysisResponse struct...")
            let response = try decoder.decode(AnalysisResponse.self, from: data)
            
            print("[OpenAIService] ✅ Successfully decoded! Building PhotoAnalysisVariables...")
            
            let variables = PhotoAnalysisVariables(
                faceShape: response.faceShape,
                skinUndertone: response.skinUndertone,
                eyeColor: response.eyeColor,
                hairColor: response.hairColor,
                facialHarmonyScore: response.facialHarmonyScore,
                featureBalanceDescription: response.featureBalanceDescription,
                genderDimorphism: response.genderDimorphism,
                facialAngularityScore: response.facialAngularityScore,
                faceFullnessDescriptor: response.faceFullnessDescriptor,
                lightingQuality: response.lightingQuality,
                lightingType: response.lightingType,
                lightingDirection: response.lightingDirection,
                exposure: response.exposure,
                colorHarmony: response.colorHarmony,
                overallComposition: response.overallComposition,
                backgroundSuitability: response.backgroundSuitability,
                makeupSuitability: response.makeupSuitability,
                makeupStyle: response.makeupStyle,
                outfitColorMatch: response.outfitColorMatch,
                accessoryBalance: response.accessoryBalance,
                skinTextureScore: response.skinTextureScore,
                skinTextureDescription: response.skinTextureDescription,
                skinConcernHighlights: response.skinConcernHighlights,
                eyebrowDensityScore: response.eyebrowDensityScore,
                eyebrowFeedback: response.eyebrowFeedback,
                poseNaturalness: response.poseNaturalness,
                angleFlatter: response.angleFlatter,
                facialExpression: response.facialExpression,
                eyeContact: response.eyeContact,
                seasonalPalette: response.seasonalPalette,
                bestColors: response.bestColors,
                avoidColors: response.avoidColors,
                confidenceScore: response.confidenceScore,
                overallGlowScore: response.overallGlowScore,
                strengthAreas: response.strengthAreas,
                improvementAreas: response.improvementAreas,
                bestTraits: response.bestTraits.isEmpty ? response.strengthAreas : response.bestTraits,
                traitsToImprove: response.traitsToImprove.isEmpty ? response.improvementAreas : response.traitsToImprove,
                holdingBackFactors: response.holdingBackFactors,
                roadmap: response.roadmap,
                quickWins: response.quickWins,
                longTermGoals: response.longTermGoals,
                foundationalHabits: response.foundationalHabits,
                lightingFeedback: response.lightingFeedback,
                eyeColorFeedback: response.eyeColorFeedback,
                skinToneFeedback: response.skinToneFeedback,
                hairColorFeedback: response.hairColorFeedback,
                poseFeedback: response.poseFeedback,
                makeupFeedback: response.makeupFeedback,
                compositionFeedback: response.compositionFeedback
            )
            
            print("[OpenAIService] ✅ PhotoAnalysisVariables created successfully")
            print("[OpenAIService] - Face Shape: \(variables.faceShape ?? "Not detected")")
            print("[OpenAIService] - Eye Color: \(variables.eyeColor ?? "Not detected")")
            print("[OpenAIService] - Lighting Type: \(variables.lightingType)")
            print("[OpenAIService] - Seasonal Palette: \(variables.seasonalPalette ?? "Not detected")")
            
            return DetailedPhotoAnalysis(
                variables: variables,
                summary: response.summary,
                personalizedTips: response.personalizedTips,
                isFallback: false
            )
        } catch let DecodingError.keyNotFound(key, context) {
            print("[OpenAIService] ❌ JSON missing key: \(key.stringValue)")
            print("[OpenAIService] Context: \(context.debugDescription)")
            print("[OpenAIService] CodingPath: \(context.codingPath)")
        } catch let DecodingError.typeMismatch(type, context) {
            print("[OpenAIService] ❌ JSON type mismatch for type: \(type)")
            print("[OpenAIService] Context: \(context.debugDescription)")
            print("[OpenAIService] CodingPath: \(context.codingPath)")
        } catch let DecodingError.valueNotFound(type, context) {
            print("[OpenAIService] ❌ JSON value not found for type: \(type)")
            print("[OpenAIService] Context: \(context.debugDescription)")
        } catch let DecodingError.dataCorrupted(context) {
            print("[OpenAIService] ❌ JSON data corrupted")
            print("[OpenAIService] Context: \(context.debugDescription)")
        } catch {
            print("[OpenAIService] ❌ Unknown JSON decoding error: \(error)")
            print("[OpenAIService] Error type: \(type(of: error))")
        }
        
        return nil
    }
    
    private func parseJSON<T: Decodable>(from text: String) -> T? {
        if let data = text.data(using: .utf8), let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }
        if let range = text.firstJSONRange, let data = String(text[range]).data(using: .utf8) {
            return try? JSONDecoder().decode(T.self, from: data)
        }
        return nil
    }
    
    // MARK: - Helper Methods
    
    private func encodeImageData(
        _ data: Data,
        maxDimension: CGFloat,
        compressionQuality: CGFloat
    ) -> (base64: String, mimeType: String) {
        #if canImport(UIKit)
        if let image = UIImage(data: data) {
            let resizedImage: UIImage = {
                let maxSide = max(image.size.width, image.size.height)
                guard maxSide > maxDimension else { return image }
                let scale = maxDimension / maxSide
                let newSize = CGSize(
                    width: image.size.width * scale,
                    height: image.size.height * scale
                )
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                let result = UIGraphicsGetImageFromCurrentImageContext() ?? image
                UIGraphicsEndImageContext()
                return result
            }()
            
            if let jpeg = resizedImage.jpegData(compressionQuality: compressionQuality) {
                return (jpeg.base64EncodedString(), "image/jpeg")
            }
        }
        #endif
        return (data.base64EncodedString(), "image/jpeg")
    }
    
    // MARK: - Fallback Data
    
    private func createFallbackAnalysis(
        for persona: CoachPersona,
        summary: String?,
        tips: [String]?
    ) -> DetailedPhotoAnalysis {
        let variables = PhotoAnalysisVariables(
            faceShape: nil,
            skinUndertone: nil,
            eyeColor: nil,
            hairColor: nil,
            facialHarmonyScore: 0.0,
            featureBalanceDescription: "Analysis unavailable.",
            genderDimorphism: "Unknown",
            facialAngularityScore: 0.0,
            faceFullnessDescriptor: "Unknown",
            lightingQuality: 0.0,
            lightingType: "Unknown",
            lightingDirection: "Unknown",
            exposure: "Unknown",
            colorHarmony: 0.0,
            overallComposition: 0.0,
            backgroundSuitability: 0.0,
            makeupSuitability: 0.0,
            makeupStyle: "Unknown",
            outfitColorMatch: 0.0,
            accessoryBalance: 0.0,
            skinTextureScore: 0.0,
            skinTextureDescription: "Skin analysis unavailable.",
            skinConcernHighlights: [],
            eyebrowDensityScore: 0.0,
            eyebrowFeedback: "Brow analysis unavailable.",
            poseNaturalness: 0.0,
            angleFlatter: 0.0,
            facialExpression: "Unknown",
            eyeContact: "Unknown",
            seasonalPalette: nil,
            bestColors: [],
            avoidColors: [],
            confidenceScore: 0.0,
            overallGlowScore: 0.0,
            strengthAreas: [],
            improvementAreas: [],
            bestTraits: [],
            traitsToImprove: [],
            holdingBackFactors: [],
            roadmap: [],
            quickWins: [],
            longTermGoals: [],
            foundationalHabits: [],
            lightingFeedback: "Unable to analyze - please check your connection and API key.",
            eyeColorFeedback: nil,
            skinToneFeedback: nil,
            hairColorFeedback: nil,
            poseFeedback: "Unable to analyze - please check your connection and API key.",
            makeupFeedback: "Unable to analyze - please check your connection and API key.",
            compositionFeedback: "Unable to analyze - please check your connection and API key."
        )
        
        let trimmedSummary = summary?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSummary = (trimmedSummary?.isEmpty ?? true) ? fallbackSummaryDefault : trimmedSummary!
        let resolvedTips: [String]
        if let tips, !tips.isEmpty {
            let cleaned = tips
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            resolvedTips = cleaned.isEmpty ? fallbackTipsDefault : cleaned
        } else {
            resolvedTips = fallbackTipsDefault
        }
        
        return DetailedPhotoAnalysis(
            variables: variables,
            summary: resolvedSummary,
            personalizedTips: resolvedTips,
            isFallback: true
        )
    }
    
    private func createFallbackTips(for mode: TipMode) -> [GeneratedTip] {
        switch mode {
        case .shortTerm:
            return [
                GeneratedTip(id: UUID().uuidString, title: "Golden Hour Magic", body: "Shoot during the hour after sunrise or before sunset for naturally flattering light.", source: "GPT-4", type: "short"),
                GeneratedTip(id: UUID().uuidString, title: "The Window Trick", body: "Position yourself facing a window for instant soft, diffused lighting.", source: "GPT-4", type: "short"),
                GeneratedTip(id: UUID().uuidString, title: "Confidence Breath", body: "Take three slow breaths before your photo. Your eyes will naturally soften.", source: "GPT-4", type: "short")
            ]
        case .longTerm:
            return [
                GeneratedTip(id: UUID().uuidString, title: "Build Your Color Story", body: "Create a capsule wardrobe in your seasonal palette colors for consistent photogenic results.", source: "GPT-4", type: "long"),
                GeneratedTip(id: UUID().uuidString, title: "Angle Mastery", body: "Spend two weeks practicing your optimal angles in different lighting conditions.", source: "GPT-4", type: "long"),
                GeneratedTip(id: UUID().uuidString, title: "Signature Style Development", body: "Curate a Pinterest board of looks that match your coloring and face shape.", source: "GPT-4", type: "long")
            ]
        }
    }
}

// MARK: - API Models

private struct OpenAIResponse: Decodable {
    let choices: [Choice]
    
    struct Choice: Decodable {
        let message: Message
    }
    
    struct Message: Decodable {
        let refusal: String?
        private let stringContent: String?
        private let partContent: [ContentPart]?
        
        var textContent: String? {
            if let stringContent {
                let trimmed = stringContent.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
            
            guard let partContent else { return nil }
            let combined = partContent.compactMap { $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            return combined.isEmpty ? nil : combined
        }
        
        struct ContentPart: Decodable {
            let type: String?
            let text: String?
        }
        
        enum CodingKeys: String, CodingKey {
            case refusal
            case content
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            refusal = try container.decodeIfPresent(String.self, forKey: .refusal)
            
            if let stringValue = try? container.decode(String.self, forKey: .content) {
                stringContent = stringValue
                partContent = nil
            } else if let contentParts = try? container.decode([ContentPart].self, forKey: .content) {
                stringContent = nil
                partContent = contentParts
            } else {
                stringContent = nil
                partContent = nil
            }
        }
    }
}

private struct AnalysisResponse: Decodable {
    let faceShape: String?
    let skinUndertone: String?
    let eyeColor: String?
    let hairColor: String?
    let facialHarmonyScore: Double
    let featureBalanceDescription: String
    let genderDimorphism: String
    let facialAngularityScore: Double
    let faceFullnessDescriptor: String
    let lightingQuality: Double
    let lightingType: String
    let lightingDirection: String
    let exposure: String
    let colorHarmony: Double
    let overallComposition: Double
    let backgroundSuitability: Double
    let makeupSuitability: Double
    let makeupStyle: String
    let outfitColorMatch: Double
    let accessoryBalance: Double
    let skinTextureScore: Double
    let skinTextureDescription: String
    let skinConcernHighlights: [String]
    let eyebrowDensityScore: Double
    let eyebrowFeedback: String
    let poseNaturalness: Double
    let angleFlatter: Double
    let facialExpression: String
    let eyeContact: String
    let seasonalPalette: String?
    let bestColors: [String]
    let avoidColors: [String]
    let confidenceScore: Double
    let overallGlowScore: Double
    let strengthAreas: [String]
    let improvementAreas: [String]
    let bestTraits: [String]
    let traitsToImprove: [String]
    let holdingBackFactors: [String]
    let roadmap: [ImprovementRoadmapStep]
    let quickWins: [String]
    let longTermGoals: [String]
    let foundationalHabits: [String]
    let summary: String
    let personalizedTips: [String]
    let lightingFeedback: String
    let eyeColorFeedback: String?
    let skinToneFeedback: String?
    let hairColorFeedback: String?
    let poseFeedback: String
    let makeupFeedback: String
    let compositionFeedback: String
    
    enum CodingKeys: String, CodingKey {
        case faceShape, skinUndertone, eyeColor, hairColor
        case facialHarmonyScore, featureBalanceDescription, genderDimorphism
        case facialAngularityScore, faceFullnessDescriptor
        case lightingQuality, lightingType, lightingDirection, exposure
        case colorHarmony, overallComposition, backgroundSuitability
        case makeupSuitability, makeupStyle, outfitColorMatch, accessoryBalance
        case skinTextureScore, skinTextureDescription, skinConcernHighlights
        case eyebrowDensityScore, eyebrowFeedback
        case poseNaturalness, angleFlatter, facialExpression, eyeContact
        case seasonalPalette, bestColors, avoidColors
        case confidenceScore, overallGlowScore
        case strengthAreas, improvementAreas, bestTraits, traitsToImprove
        case holdingBackFactors, roadmap
        case quickWins, longTermGoals, foundationalHabits
        case summary, personalizedTips
        case lightingFeedback, eyeColorFeedback, skinToneFeedback, hairColorFeedback
        case poseFeedback, makeupFeedback, compositionFeedback
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        faceShape = try container.decodeIfPresent(String.self, forKey: .faceShape)
        skinUndertone = try container.decodeIfPresent(String.self, forKey: .skinUndertone)
        eyeColor = try container.decodeIfPresent(String.self, forKey: .eyeColor)
        hairColor = try container.decodeIfPresent(String.self, forKey: .hairColor)
        facialHarmonyScore = container.decodeFlexibleDouble(forKey: .facialHarmonyScore)
        featureBalanceDescription = try container.decodeIfPresent(String.self, forKey: .featureBalanceDescription) ?? "Unable to determine facial balance."
        genderDimorphism = try container.decodeIfPresent(String.self, forKey: .genderDimorphism) ?? "Neutral"
        facialAngularityScore = container.decodeFlexibleDouble(forKey: .facialAngularityScore)
        faceFullnessDescriptor = try container.decodeIfPresent(String.self, forKey: .faceFullnessDescriptor) ?? "Unknown"
        lightingQuality = container.decodeFlexibleDouble(forKey: .lightingQuality)
        lightingType = try container.decodeIfPresent(String.self, forKey: .lightingType) ?? "Unknown"
        lightingDirection = try container.decodeIfPresent(String.self, forKey: .lightingDirection) ?? "Unknown"
        exposure = try container.decodeIfPresent(String.self, forKey: .exposure) ?? "Unknown"
        colorHarmony = container.decodeFlexibleDouble(forKey: .colorHarmony)
        overallComposition = container.decodeFlexibleDouble(forKey: .overallComposition)
        backgroundSuitability = container.decodeFlexibleDouble(forKey: .backgroundSuitability)
        makeupSuitability = container.decodeFlexibleDouble(forKey: .makeupSuitability)
        makeupStyle = try container.decodeIfPresent(String.self, forKey: .makeupStyle) ?? "Unknown"
        outfitColorMatch = container.decodeFlexibleDouble(forKey: .outfitColorMatch)
        accessoryBalance = container.decodeFlexibleDouble(forKey: .accessoryBalance)
        skinTextureScore = container.decodeFlexibleDouble(forKey: .skinTextureScore)
        skinTextureDescription = try container.decodeIfPresent(String.self, forKey: .skinTextureDescription) ?? "Skin texture observations unavailable."
        skinConcernHighlights = container.decodeStringArray(forKey: .skinConcernHighlights)
        eyebrowDensityScore = container.decodeFlexibleDouble(forKey: .eyebrowDensityScore)
        eyebrowFeedback = try container.decodeIfPresent(String.self, forKey: .eyebrowFeedback) ?? "Brow feedback unavailable."
        poseNaturalness = container.decodeFlexibleDouble(forKey: .poseNaturalness)
        angleFlatter = container.decodeFlexibleDouble(forKey: .angleFlatter)
        facialExpression = try container.decodeIfPresent(String.self, forKey: .facialExpression) ?? "Unknown"
        eyeContact = try container.decodeIfPresent(String.self, forKey: .eyeContact) ?? "Unknown"
        seasonalPalette = try container.decodeIfPresent(String.self, forKey: .seasonalPalette)
        bestColors = container.decodeStringArray(forKey: .bestColors)
        avoidColors = container.decodeStringArray(forKey: .avoidColors)
        confidenceScore = container.decodeFlexibleDouble(forKey: .confidenceScore)
        overallGlowScore = container.decodeFlexibleDouble(forKey: .overallGlowScore)
        strengthAreas = container.decodeStringArray(forKey: .strengthAreas)
        improvementAreas = container.decodeStringArray(forKey: .improvementAreas)
        bestTraits = container.decodeStringArray(forKey: .bestTraits)
        traitsToImprove = container.decodeStringArray(forKey: .traitsToImprove)
        holdingBackFactors = container.decodeStringArray(forKey: .holdingBackFactors)
        roadmap = container.decodeRoadmapArray(forKey: .roadmap)
        quickWins = container.decodeStringArray(forKey: .quickWins)
        longTermGoals = container.decodeStringArray(forKey: .longTermGoals)
        foundationalHabits = container.decodeStringArray(forKey: .foundationalHabits)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? "No summary available."
        personalizedTips = container.decodeStringArray(forKey: .personalizedTips)
        lightingFeedback = try container.decodeIfPresent(String.self, forKey: .lightingFeedback) ?? "Lighting feedback unavailable."
        eyeColorFeedback = try container.decodeIfPresent(String.self, forKey: .eyeColorFeedback)
        skinToneFeedback = try container.decodeIfPresent(String.self, forKey: .skinToneFeedback)
        hairColorFeedback = try container.decodeIfPresent(String.self, forKey: .hairColorFeedback)
        poseFeedback = try container.decodeIfPresent(String.self, forKey: .poseFeedback) ?? "Pose feedback unavailable."
        makeupFeedback = try container.decodeIfPresent(String.self, forKey: .makeupFeedback) ?? "Makeup feedback unavailable."
        compositionFeedback = try container.decodeIfPresent(String.self, forKey: .compositionFeedback) ?? "Composition feedback unavailable."
    }
}

private struct TipsResponse: Codable {
    let tips: [Tip]
    
    struct Tip: Codable {
        let id: String?
        let title: String
        let body: String
        let type: String
    }
}

private extension KeyedDecodingContainer where Key == AnalysisResponse.CodingKeys {
    func decodeFlexibleDouble(forKey key: Key) -> Double {
        if let value = try? decode(Double.self, forKey: key) {
            return value
        }
        if let stringValue = try? decode(String.self, forKey: key),
           let double = Double(stringValue) {
            return double
        }
        return 0
    }
    
    func decodeStringArray(forKey key: Key) -> [String] {
        if let values = try? decode([String].self, forKey: key) {
            return values
        }
        if let value = try? decode(String.self, forKey: key) {
            return value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }
    
    func decodeRoadmapArray(forKey key: Key) -> [ImprovementRoadmapStep] {
        if let steps = try? decode([ImprovementRoadmapStep].self, forKey: key) {
            return steps
        }
        return []
    }
}

private enum OpenAIError: Error {
    case apiKeyMissing
    case invalidResponse
    case apiError(code: Int, message: String)
    case emptyResponse
    case refused(reason: String)
}

// MARK: - Extensions

private extension CoachPersona {
    var fallbackResponse: String {
        switch self {
        case .bestie:
            return "Bestie, you're glowing! Try tilting your chin slightly and letting that confidence shine through."
        case .director:
            return "Good. Now turn 30 degrees, drop your shoulder, and think power. You've got this."
        case .zenGuru:
            return "Breathe in light, breathe out tension. Your natural radiance is already present."
        }
    }
}

private extension String {
    var firstJSONRange: Range<String.Index>? {
        guard let start = firstIndex(of: "{"), let end = lastIndex(of: "}") else { return nil }
        return start..<index(after: end)
    }
}
