//
//  Models.swift
//  glowup
//
//  Shared lightweight models used across services
//

import Foundation

struct GeneratedTip {
    let id: String
    let title: String
    let body: String
    let source: String
    let type: String
}

enum ActionTipCategory: String, Codable {
    case shortTerm
    case longTerm
}

struct AppearanceActionTip: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let category: ActionTipCategory
    let relatedQueries: [String]
    
    init(id: String = UUID().uuidString, title: String, body: String, category: ActionTipCategory, relatedQueries: [String]) {
        self.id = id
        self.title = title
        self.body = body
        self.category = category
        self.relatedQueries = relatedQueries
    }
}

struct CelebrityMatchSuggestion: Codable, Identifiable {
    let id: String
    let name: String
    let descriptor: String
    let whyItWorks: String
    let pinterestQueries: [String]
    
    init(id: String = UUID().uuidString, name: String, descriptor: String, whyItWorks: String, pinterestQueries: [String]) {
        self.id = id
        self.name = name
        self.descriptor = descriptor
        self.whyItWorks = whyItWorks
        self.pinterestQueries = pinterestQueries
    }
}

struct PinterestSearchIdea: Codable, Identifiable {
    let id: String
    let label: String
    let query: String
    
    var encodedURL: URL? {
        var components = URLComponents(string: "https://www.pinterest.com/search/pins/")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }
    
    init(id: String = UUID().uuidString, label: String, query: String) {
        self.id = id
        self.label = label
        self.query = query
    }
}

struct ImprovementRoadmapStep: Codable, Identifiable {
    let id: String
    let timeframe: String
    let focus: String
    let actions: [String]
    
    init(id: String = UUID().uuidString, timeframe: String, focus: String, actions: [String]) {
        self.id = id
        self.timeframe = timeframe
        self.focus = focus
        self.actions = actions
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timeframe = try container.decodeIfPresent(String.self, forKey: .timeframe) ?? "Weekly"
        focus = try container.decodeIfPresent(String.self, forKey: .focus) ?? "Overall Glow"
        actions = try container.decodeIfPresent([String].self, forKey: .actions) ?? []
        if let existingId = try container.decodeIfPresent(String.self, forKey: .id),
           !existingId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            id = existingId
        } else {
            id = UUID().uuidString
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, timeframe, focus, actions
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timeframe, forKey: .timeframe)
        try container.encode(focus, forKey: .focus)
        try container.encode(actions, forKey: .actions)
    }
}
