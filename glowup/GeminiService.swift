//
//  GeminiService.swift
//  glowup
//
//  Provides integration with Google's Gemini Nano Banana image editing APIs.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum GeminiServiceError: Error, LocalizedError {
    case missingAPIKey
    case encodingFailed
    case unsupportedImageFormat
    case invalidHTTPResponse(status: Int, message: String)
    case emptyResponse
    case contentBlocked
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is missing. Add GEMINI_API_KEY to Secrets."
        case .encodingFailed:
            return "Failed to encode image for Gemini request."
        case .unsupportedImageFormat:
            return "The provided image could not be converted to JPEG."
        case .invalidHTTPResponse(let status, let message):
            return "Gemini API returned \(status): \(message)"
        case .emptyResponse:
            return "Gemini response did not contain any generated image data."
        case .contentBlocked:
            return "Gemini blocked the request due to safety filters."
        case .decodingFailed:
            return "Unable to decode the Gemini response payload."
        }
    }
}

struct GeminiServiceConfiguration: Sendable {
    let modelName: String
    let temperature: Double
    let maxOutputTokens: Int
    let maxRetries: Int
    let responseMimeType: String?
    let responseModalities: [String]?

    static var `default`: GeminiServiceConfiguration {
        GeminiServiceConfiguration(
            modelName: "gemini-2.5-flash-image",
            temperature: 0.55,
            maxOutputTokens: 2048,
            maxRetries: 2,
            responseMimeType: nil,
            responseModalities: ["Image"]
        )
    }
}

actor GeminiService {
    static let shared = GeminiService()

    private let configuration: GeminiServiceConfiguration
    private let urlSession: URLSession
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    init(
        configuration: GeminiServiceConfiguration = .default,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.urlSession = urlSession

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.withoutEscapingSlashes]
        jsonEncoder = encoder

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        jsonDecoder = decoder
    }

    #if canImport(UIKit)
    func generateImageEdit(
        baseImage: UIImage,
        prompt: String,
        referenceImages: [UIImage] = []
    ) async throws -> UIImage {
        let requestPayload = try buildRequestPayload(
            baseImage: baseImage,
            prompt: prompt,
            referenceImages: referenceImages
        )

        let responseData = try await performRequest(with: requestPayload)
        return try decodeImage(from: responseData)
    }

    func applyPreset(
        baseImage: UIImage,
        category: VisualizationPresetCategory,
        option: VisualizationPresetOption,
        analysis: PhotoAnalysisVariables?
    ) async throws -> UIImage {
        var prompt = """
        You are \"Nano Banana\", a professional beauty visualization specialist. Keep the person's facial structure, lighting, and overall identity intact. Carefully apply the requested transformation.

        Category: \(category.displayName)
        Selected Option: \(option.title)
        """

        if !option.subtitle.isEmpty {
            prompt.append("\nDetails: \(option.subtitle)")
        }

        prompt.append("\nRequested Look Instructions: \(option.prompt)")

        if let analysis {
            prompt.append("\n\nReference the following client analysis to keep the look realistic:\n")
            prompt.append(analysisPrompt(from: analysis))
        }

        let payload = try buildRequestPayload(
            baseImage: baseImage,
            prompt: prompt,
            referenceImages: []
        )

        let responseData = try await performRequest(with: payload)
        return try decodeImage(from: responseData)
    }
    #endif

    // MARK: - Request Construction

    #if canImport(UIKit)
    private func buildRequestPayload(
        baseImage: UIImage,
        prompt: String,
        referenceImages: [UIImage]
    ) throws -> GeminiImageEditRequest {
        guard let jpegData = baseImage
            .resized(maxDimension: 1400)?
            .jpegData(compressionQuality: 0.88) ?? baseImage.jpegData(compressionQuality: 0.88) else {
            throw GeminiServiceError.unsupportedImageFormat
        }

        let basePart = GeminiImageEditRequest.Part(
            inlineData: GeminiImageEditRequest.DataBlob(
                mimeType: "image/jpeg",
                data: jpegData.base64EncodedString()
            )
        )

        let referenceParts = try referenceImages.compactMap { reference -> GeminiImageEditRequest.Part? in
            guard let data = reference
                .resized(maxDimension: 1400)?
                .jpegData(compressionQuality: 0.85) ?? reference.jpegData(compressionQuality: 0.85) else {
                return nil
            }

            return GeminiImageEditRequest.Part(
                inlineData: GeminiImageEditRequest.DataBlob(
                    mimeType: "image/jpeg",
                    data: data.base64EncodedString()
                )
            )
        }

        let instructionPart = GeminiImageEditRequest.Part(text: prompt)

        let userContent = GeminiImageEditRequest.Content(
            role: "user",
            parts: [basePart] + [instructionPart] + referenceParts
        )

        let config = GeminiImageEditRequest.GenerationConfig(
            temperature: configuration.temperature,
            maxOutputTokens: configuration.maxOutputTokens,
            responseMimeType: configuration.responseMimeType,
            responseModalities: configuration.responseModalities
        )

        let safety: [GeminiImageEditRequest.SafetySetting] = [
            .init(category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE"),
            .init(category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE"),
            .init(category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE"),
            .init(category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE"),
            .init(category: "HARM_CATEGORY_CIVIC_INTEGRITY", threshold: "BLOCK_NONE")
        ]

        return GeminiImageEditRequest(
            contents: [userContent],
            generationConfig: config,
            safetySettings: safety
        )
    }
    #endif

    // MARK: - Network

    private func performRequest(with payload: GeminiImageEditRequest) async throws -> GeminiImageEditResponse {
        guard let apiKey = Secrets.geminiApiKey, !apiKey.isEmpty else {
            throw GeminiServiceError.missingAPIKey
        }

        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(configuration.modelName):generateContent"
        guard let url = URL(string: endpoint) else {
            throw GeminiServiceError.encodingFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try jsonEncoder.encode(payload)

        // Debug logging
        print("[GeminiService] Making request to: \(endpoint)")
        print("[GeminiService] API Key present: \(!apiKey.isEmpty)")
        print("[GeminiService] Request body size: \(request.httpBody?.count ?? 0) bytes")

        var attempt = 0
        var lastError: Error?

        while attempt <= configuration.maxRetries {
            do {
                let (data, response) = try await urlSession.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GeminiServiceError.invalidHTTPResponse(status: -1, message: "No HTTP response")
                }

                print("[GeminiService] HTTP Status: \(httpResponse.statusCode)")

                guard 200..<300 ~= httpResponse.statusCode else {
                    let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("[GeminiService] Error response: \(message)")
                    throw GeminiServiceError.invalidHTTPResponse(status: httpResponse.statusCode, message: message)
                }

                return try jsonDecoder.decode(GeminiImageEditResponse.self, from: data)
            } catch {
                lastError = error
                attempt += 1
                if attempt > configuration.maxRetries {
                    throw lastError ?? GeminiServiceError.decodingFailed
                }
                try await Task.sleep(nanoseconds: UInt64(0.6 * Double(NSEC_PER_SEC)))
            }
        }

        throw lastError ?? GeminiServiceError.decodingFailed
    }

    #if canImport(UIKit)
    private func decodeImage(from response: GeminiImageEditResponse) throws -> UIImage {
        guard let candidate = response.candidates?.first else {
            if let promptFeedback = response.promptFeedback, promptFeedback.blockReason != nil {
                throw GeminiServiceError.contentBlocked
            }
            throw GeminiServiceError.emptyResponse
        }

        guard let part = candidate.content?.parts.first(where: { $0.inlineData != nil }),
              let blob = part.inlineData,
              let imageData = Data(base64Encoded: blob.data) else {
            throw GeminiServiceError.decodingFailed
        }

        guard let image = UIImage(data: imageData) else {
            throw GeminiServiceError.decodingFailed
        }
        return image
    }

    private func analysisPrompt(from analysis: PhotoAnalysisVariables) -> String {
        var lines: [String] = []
        if let faceShape = analysis.faceShape {
            lines.append("Face Shape: \(faceShape)")
        }
        if let palette = analysis.seasonalPalette {
            lines.append("Seasonal Palette: \(palette)")
        }
        if let undertone = analysis.skinUndertone {
            lines.append("Skin Undertone: \(undertone)")
        }
        if let eye = analysis.eyeColor {
            lines.append("Eye Color: \(eye)")
        }
        if let hair = analysis.hairColor {
            lines.append("Current Hair Color: \(hair)")
        }
        lines.append("Makeup Preference: \(analysis.makeupStyle)")
        if !analysis.bestColors.isEmpty {
            let colorList = analysis.bestColors.joined(separator: ", ")
            lines.append("Best Colors: \(colorList)")
        }
        if !analysis.quickWins.isEmpty {
            let winList = analysis.quickWins.joined(separator: ", ")
            lines.append("Quick Wins: \(winList)")
        }
        return lines.joined(separator: "\n")
    }
    #endif

    // MARK: - Test Function
    
    func testConnection() async throws -> String {
        guard let apiKey = Secrets.geminiApiKey, !apiKey.isEmpty else {
            throw GeminiServiceError.missingAPIKey
        }

        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent"
        guard let url = URL(string: endpoint) else {
            throw GeminiServiceError.encodingFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        // Simple text-to-image test
        let testBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "A simple test image of a red apple on a white background"]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: testBody)
        
        print("[GeminiService] Testing connection to: \(endpoint)")
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiServiceError.invalidHTTPResponse(status: -1, message: "No HTTP response")
        }
        
        print("[GeminiService] Test HTTP Status: \(httpResponse.statusCode)")
        
        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[GeminiService] Test Error response: \(message)")
            throw GeminiServiceError.invalidHTTPResponse(status: httpResponse.statusCode, message: message)
        }
        
        return "Connection successful! Status: \(httpResponse.statusCode)"
    }
}

// MARK: - API DTOs

struct GeminiImageEditRequest: Encodable {
    struct Content: Encodable {
        let role: String
        let parts: [Part]
    }

    struct Part: Encodable {
        let text: String?
        let inlineData: DataBlob?

        init(text: String) {
            self.text = text
            self.inlineData = nil
        }

        init(inlineData: DataBlob) {
            self.text = nil
            self.inlineData = inlineData
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            if let text {
                try container.encode(text, forKey: .text)
            }
            if let inlineData {
                try container.encode(inlineData, forKey: .inlineData)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case text
            case inlineData = "inline_data"
        }
    }

    struct DataBlob: Encodable {
        let mimeType: String
        let data: String

        private enum CodingKeys: String, CodingKey {
            case mimeType = "mime_type"
            case data
        }
    }

    struct GenerationConfig: Encodable {
        let temperature: Double
        let maxOutputTokens: Int
        let responseMimeType: String?
        let responseModalities: [String]?

        private enum CodingKeys: String, CodingKey {
            case temperature
            case maxOutputTokens
            case responseMimeType = "response_mime_type"
            case responseModalities = "response_modalities"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(temperature, forKey: .temperature)
            try container.encode(maxOutputTokens, forKey: .maxOutputTokens)
            if let responseMimeType {
                try container.encode(responseMimeType, forKey: .responseMimeType)
            }
            if let responseModalities {
                try container.encode(responseModalities, forKey: .responseModalities)
            }
        }
    }

    struct SafetySetting: Encodable {
        let category: String
        let threshold: String
    }

    let contents: [Content]
    let generationConfig: GenerationConfig
    let safetySettings: [SafetySetting]
}

struct GeminiImageEditResponse: Decodable {
    struct Candidate: Decodable {
        let content: Content?
        let finishReason: String?
        let safetyRatings: [SafetyRating]?
    }

    struct Content: Decodable {
        let role: String?
        let parts: [Part]
    }

    struct Part: Decodable {
        let text: String?
        let inlineData: DataBlob?

        private enum CodingKeys: String, CodingKey {
            case text
            case inlineData = "inline_data"
        }
    }

    struct DataBlob: Decodable {
        let mimeType: String?
        let data: String

        private enum CodingKeys: String, CodingKey {
            case mimeType = "mime_type"
            case data
        }
    }

    struct SafetyRating: Decodable {
        let category: String
        let probability: String
    }

    struct PromptFeedback: Decodable {
        let blockReason: String?
        let safetyRatings: [SafetyRating]?
    }

    let candidates: [Candidate]?
    let promptFeedback: PromptFeedback?
}
