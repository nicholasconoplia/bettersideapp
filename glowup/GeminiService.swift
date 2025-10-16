//
//  GeminiService.swift
//  glowup
//
//  Provides integration with Google's Gemini Nano Banana image editing APIs.
//

import Foundation
#if canImport(OSLog)
import OSLog
#endif
#if canImport(UIKit)
import UIKit
#endif

// Helper type for decoding dynamic JSON values
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

enum GeminiServiceError: Error, LocalizedError {
    case missingAPIKey
    case encodingFailed
    case unsupportedImageFormat
    case invalidHTTPResponse(status: Int, message: String)
    case emptyResponse
    case contentBlocked
    case decodingFailed
    case quotaExceeded(retryAfter: TimeInterval)

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
        case .quotaExceeded(let retryAfter):
            return "Rate limit exceeded. Please wait \(Int(retryAfter)) seconds and try again. Consider upgrading to a paid plan for higher limits."
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

#if canImport(OSLog)
    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    private let logger = Logger(subsystem: "com.glowup.app", category: "GeminiService")
#endif

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

    private func debugLog(_ message: String) {
#if canImport(OSLog)
        if #available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *) {
            logger.debug("\(message, privacy: .public)")
        }
#endif
        print("[GeminiService] \(message)")
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

        let responseResult = try await performRequest(with: requestPayload)
        return try await decodeImage(from: responseResult.response, rawData: responseResult.rawData)
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

        let responseResult = try await performRequest(with: payload)
        return try await decodeImage(from: responseResult.response, rawData: responseResult.rawData)
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

    private func performRequest(with payload: GeminiImageEditRequest) async throws -> (response: GeminiImageEditResponse, rawData: Data) {
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
        debugLog("Making request to: \(endpoint)")
        debugLog("API Key present: \(!apiKey.isEmpty)")
        debugLog("Request body size: \(request.httpBody?.count ?? 0) bytes")

        var attempt = 0
        var lastError: Error?

        while attempt <= configuration.maxRetries {
            do {
                let (data, response) = try await urlSession.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GeminiServiceError.invalidHTTPResponse(status: -1, message: "No HTTP response")
                }

                debugLog("HTTP Status: \(httpResponse.statusCode)")

                guard 200..<300 ~= httpResponse.statusCode else {
                    let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                    debugLog("Error response: \(message)")
                    
                    // Handle rate limiting specifically
                    if httpResponse.statusCode == 429 {
                        // Try to parse retry-after from response
                        let retryAfter = parseRetryAfter(from: data) ?? 15.0
                        throw GeminiServiceError.quotaExceeded(retryAfter: retryAfter)
                    }
                    
                    throw GeminiServiceError.invalidHTTPResponse(status: httpResponse.statusCode, message: message)
                }

                // Debug: Print the raw response
                if let responseString = String(data: data, encoding: .utf8) {
                    debugLog("Raw response: \(responseString)")
                } else {
                    debugLog("Raw response could not be converted to UTF-8 string (\(data.count) bytes)")
                }
                
                // Try to decode the response
                do {
                    let response = try jsonDecoder.decode(GeminiImageEditResponse.self, from: data)
                    debugLog("Successfully decoded response with \(response.candidates?.count ?? 0) candidates")
                    return (response, data)
                } catch {
                    debugLog("Decoding failed: \(error)")
                    debugLog("Response data size: \(data.count) bytes")
                    throw GeminiServiceError.decodingFailed
                }
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
    private func decodeImage(from response: GeminiImageEditResponse, rawData: Data) async throws -> UIImage {
        if let promptFeedback = response.promptFeedback, promptFeedback.blockReason != nil {
            throw GeminiServiceError.contentBlocked
        }

        let candidates = response.candidates ?? []
        if candidates.isEmpty {
            debugLog("⚠️ Response contained no candidates. Prompt feedback: \(String(describing: response.promptFeedback))")
        }

        for candidate in candidates {
            if let finishReason = candidate.finishReason {
                debugLog("Candidate finish reason: \(finishReason)")
            }
            guard let parts = candidate.content?.parts else {
                debugLog("⚠️ Candidate content contained no parts")
                continue
            }
            for part in parts {
                if let inlineData = part.inlineData,
                   let base64 = inlineData.data,
                   let imageData = decodeImageData(fromBase64: base64),
                   let image = UIImage(data: imageData) {
                    debugLog("Decoded image from inline data with mimeType: \(inlineData.mimeType ?? "unknown")")
                    return image
                }

                if let fileData = part.fileData,
                   let imageData = try await fetchImageData(from: fileData),
                   let image = UIImage(data: imageData) {
                    debugLog("Decoded image from file data with mimeType: \(fileData.mimeType ?? "unknown")")
                    return image
                }

                if let text = part.text, !text.isEmpty {
                    debugLog("⚠️ Part contained text instead of image data: \(text)")
                }
            }
        }

        if let textPart = candidates
            .compactMap({ $0.content?.parts?.first(where: { ($0.text?.isEmpty == false) })?.text })
            .first {
            debugLog("⚠️ Model returned text instead of image: \(textPart)")
        }

        if let fallbackImage = try await decodeImageFromRawJSON(rawData) {
            debugLog("Decoded image using raw JSON fallback")
            return fallbackImage
        }

        if let rawString = String(data: rawData, encoding: .utf8) {
            debugLog("⚠️ Final raw payload dump: \(rawString)")
        } else {
            debugLog("⚠️ Final raw payload could not be stringified")
        }

        throw GeminiServiceError.decodingFailed
    }

    private func decodeImageFromRawJSON(_ data: Data) async throws -> UIImage? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            debugLog("⚠️ JSONSerialization fallback failed")
            return nil
        }

        if let inlineData = findInlineData(in: jsonObject),
           let imageData = decodeImageData(fromBase64: inlineData.base64),
           let image = UIImage(data: imageData) {
            debugLog("Decoded image from raw JSON inline data with mimeType: \(inlineData.mimeType ?? "unknown")")
            return image
        }

        if let fileData = findFileData(in: jsonObject) {
            let fileStruct = GeminiImageEditResponse.FileData(mimeType: fileData.mimeType, fileUri: fileData.fileUri)
            if let imageData = try await fetchImageData(from: fileStruct),
               let image = UIImage(data: imageData) {
                debugLog("Decoded image from raw JSON file data with mimeType: \(fileData.mimeType ?? "unknown")")
                return image
            }
        }

        return nil
    }

    private func findInlineData(in object: Any) -> (base64: String, mimeType: String?)? {
        if let dict = object as? [String: Any] {
            if let inline = dict["inline_data"] as? [String: Any] ?? dict["inlineData"] as? [String: Any] {
                if let data = inline["data"] as? String, !data.isEmpty {
                    let mime = inline["mime_type"] as? String ?? inline["mimeType"] as? String
                    return (data, mime)
                }
            }

            if let media = dict["media"] as? [[String: Any]] {
                for entry in media {
                    if let inline = findInlineData(in: entry) {
                        return inline
                    }
                }
            }

            if let data = dict["b64_json"] as? String, !data.isEmpty {
                let mime = dict["mime_type"] as? String ?? dict["mimeType"] as? String
                return (data, mime)
            }

            for value in dict.values {
                if let found = findInlineData(in: value) {
                    return found
                }
            }
        } else if let array = object as? [Any] {
            for item in array {
                if let found = findInlineData(in: item) {
                    return found
                }
            }
        }

        return nil
    }

    private func findFileData(in object: Any) -> (fileUri: String, mimeType: String?)? {
        if let dict = object as? [String: Any] {
            if let file = dict["file_data"] as? [String: Any] ?? dict["fileData"] as? [String: Any],
               let uri = file["file_uri"] as? String ?? file["fileUri"] as? String,
               !uri.isEmpty {
                let mime = file["mime_type"] as? String ?? file["mimeType"] as? String
                return (uri, mime)
            }

            for value in dict.values {
                if let found = findFileData(in: value) {
                    return found
                }
            }
        } else if let array = object as? [Any] {
            for item in array {
                if let found = findFileData(in: item) {
                    return found
                }
            }
        }

        return nil
    }

    private func fetchImageData(from fileData: GeminiImageEditResponse.FileData) async throws -> Data? {
        guard let uri = fileData.fileUri, !uri.isEmpty else { return nil }
        guard let apiKey = Secrets.geminiApiKey, !apiKey.isEmpty else {
            debugLog("⚠️ Missing API key when attempting to download file data")
            return nil
        }
        guard var components = URLComponents(string: uri) else {
            debugLog("⚠️ Invalid file URI: \(uri)")
            return nil
        }
        guard let scheme = components.scheme?.lowercased(), scheme == "https" else {
            debugLog("⚠️ Unsupported file URI scheme: \(uri)")
            return nil
        }

        var queryItems = components.queryItems ?? []
        if !queryItems.contains(where: { $0.name == "key" }) {
            queryItems.append(URLQueryItem(name: "key", value: apiKey))
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            debugLog("⚠️ Could not build download URL for: \(uri)")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                if let httpResponse = response as? HTTPURLResponse {
                    debugLog("⚠️ File download failed with status \(httpResponse.statusCode)")
                }
                return nil
            }
            return data
        } catch {
            debugLog("⚠️ File download error: \(error)")
            return nil
        }
    }

    private func decodeImageData(fromBase64 base64String: String) -> Data? {
        var normalized = base64String.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            debugLog("⚠️ Received empty base64 image string")
            return nil
        }

        // Normalize Base64URL (Gemini sometimes returns '-' and '_' characters)
        normalized = normalized.replacingOccurrences(of: "-", with: "+")
        normalized = normalized.replacingOccurrences(of: "_", with: "/")

        let remainder = normalized.count % 4
        if remainder > 0 {
            normalized.append(String(repeating: "=", count: 4 - remainder))
        }

        if let data = Data(base64Encoded: normalized, options: .ignoreUnknownCharacters) {
            return data
        }

        let preview = normalized.prefix(24)
        debugLog("⚠️ Base64 decoding failed. Length: \(normalized.count). Prefix: \(preview)")
        return nil
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
        
        debugLog("Testing connection to: \(endpoint)")
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiServiceError.invalidHTTPResponse(status: -1, message: "No HTTP response")
        }
        
        debugLog("Test HTTP Status: \(httpResponse.statusCode)")
        
        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            debugLog("Test Error response: \(message)")
            throw GeminiServiceError.invalidHTTPResponse(status: httpResponse.statusCode, message: message)
        }
        
        return "Connection successful! Status: \(httpResponse.statusCode)"
    }
    
    private func parseRetryAfter(from data: Data) -> TimeInterval? {
        // Try to parse the retry time from the error message
        guard let errorString = String(data: data, encoding: .utf8) else { return nil }
        
        // Look for patterns like "Please retry in 10.493518232s"
        let regex = try? NSRegularExpression(pattern: "retry in (\\d+(?:\\.\\d+)?)s", options: [])
        let range = NSRange(location: 0, length: errorString.utf16.count)
        
        if let match = regex?.firstMatch(in: errorString, options: [], range: range),
           let retryRange = Range(match.range(at: 1), in: errorString) {
            let retryString = String(errorString[retryRange])
            return TimeInterval(retryString)
        }
        
        return nil
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
        let citationMetadata: CitationMetadata?
    }

    struct Content: Decodable {
        let role: String?
        let parts: [Part]?
    }

    struct Part: Decodable {
        let text: String?
        let inlineData: DataBlob?
        let fileData: FileData?
        let functionCall: FunctionCall?
        let functionResponse: FunctionResponse?

        private enum CodingKeys: String, CodingKey {
            case text
            case inlineData = "inline_data"
            case fileData = "file_data"
            case functionCall = "function_call"
            case functionResponse = "function_response"
        }
    }

    struct DataBlob: Decodable {
        let mimeType: String?
        let data: String?

        private enum CodingKeys: String, CodingKey {
            case mimeType = "mime_type"
            case data
        }
    }

    struct FileData: Decodable {
        let mimeType: String?
        let fileUri: String?

        private enum CodingKeys: String, CodingKey {
            case mimeType = "mime_type"
            case fileUri = "file_uri"
        }
    }

    struct SafetyRating: Decodable {
        let category: String
        let probability: String
        let probabilityScore: Double?
        let severity: String?
        let severityScore: Double?

        private enum CodingKeys: String, CodingKey {
            case category
            case probability
            case probabilityScore = "probability_score"
            case severity
            case severityScore = "severity_score"
        }
    }

    struct PromptFeedback: Decodable {
        let blockReason: String?
        let safetyRatings: [SafetyRating]?
        let blockReasonMessage: String?

        private enum CodingKeys: String, CodingKey {
            case blockReason = "block_reason"
            case safetyRatings = "safety_ratings"
            case blockReasonMessage = "block_reason_message"
        }
    }

    struct CitationMetadata: Decodable {
        let citationSources: [CitationSource]?

        private enum CodingKeys: String, CodingKey {
            case citationSources = "citation_sources"
        }
    }

    struct CitationSource: Decodable {
        let startIndex: Int?
        let endIndex: Int?
        let uri: String?
        let license: String?

        private enum CodingKeys: String, CodingKey {
            case startIndex = "start_index"
            case endIndex = "end_index"
            case uri
            case license
        }
    }

    struct FunctionCall: Decodable {
        let name: String?
        let args: [String: AnyCodable]?

        private enum CodingKeys: String, CodingKey {
            case name
            case args
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            args = try container.decodeIfPresent([String: AnyCodable].self, forKey: .args)
        }
    }

    struct FunctionResponse: Decodable {
        let name: String?
        let response: [String: AnyCodable]?

        private enum CodingKeys: String, CodingKey {
            case name
            case response
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            response = try container.decodeIfPresent([String: AnyCodable].self, forKey: .response)
        }
    }

    let candidates: [Candidate]?
    let promptFeedback: PromptFeedback?
    let usageMetadata: UsageMetadata?

    private enum CodingKeys: String, CodingKey {
        case candidates
        case promptFeedback = "prompt_feedback"
        case usageMetadata = "usage_metadata"
    }
}

struct UsageMetadata: Decodable {
    let promptTokenCount: Int?
    let candidatesTokenCount: Int?
    let totalTokenCount: Int?

    private enum CodingKeys: String, CodingKey {
        case promptTokenCount = "prompt_token_count"
        case candidatesTokenCount = "candidates_token_count"
        case totalTokenCount = "total_token_count"
    }
}
