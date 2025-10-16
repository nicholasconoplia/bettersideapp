//
//  LookDescription.swift
//  glowup
//
//  Codable structure describing a styled look extracted from GPT-4 vision.
//

import Foundation

struct LookDescription: Codable {
    let styleName: String
    let whatToRequest: String
    let keyDetails: [String]
    let colorNotes: [String]
    let pinterestKeywords: [String]

    init(
        styleName: String,
        whatToRequest: String,
        keyDetails: [String],
        colorNotes: [String],
        pinterestKeywords: [String]
    ) {
        self.styleName = styleName
        self.whatToRequest = whatToRequest
        self.keyDetails = keyDetails
        self.colorNotes = colorNotes
        self.pinterestKeywords = pinterestKeywords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        styleName = (try? container.decode(String.self, forKey: .styleName)) ?? ""
        whatToRequest = (try? container.decode(String.self, forKey: .whatToRequest)) ?? ""
        keyDetails = (try? container.decode([String].self, forKey: .keyDetails)) ?? []
        colorNotes = (try? container.decode([String].self, forKey: .colorNotes)) ?? []
        pinterestKeywords = (try? container.decode([String].self, forKey: .pinterestKeywords)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case styleName
        case whatToRequest
        case keyDetails
        case colorNotes
        case pinterestKeywords
    }

    var combinedNotes: [String] {
        let trimmedDetails = keyDetails.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let trimmedColors = colorNotes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return (trimmedDetails + trimmedColors).filter { !$0.isEmpty }
    }
}
