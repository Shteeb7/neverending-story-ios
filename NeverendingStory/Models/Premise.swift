//
//  Premise.swift
//  NeverendingStory
//
//  Premise data model
//

import Foundation

struct Premise: Codable, Identifiable {
    let id: String
    let title: String
    let genre: String
    let description: String
    let hook: String?
    let themes: [String]?
    let ageRange: String?
    let generatedAt: Date?
    let tier: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case genre
        case description
        case hook
        case themes
        case ageRange = "age_range"
        case generatedAt = "generated_at"
        case tier
    }

    // Regular initializer for creating instances directly (for previews/tests)
    init(id: String, title: String, genre: String, description: String, hook: String? = nil, themes: [String]? = nil, ageRange: String? = nil, generatedAt: Date? = nil, tier: String? = nil) {
        self.id = id
        self.title = title
        self.genre = genre
        self.description = description
        self.hook = hook
        self.themes = themes
        self.ageRange = ageRange
        self.generatedAt = generatedAt
        self.tier = tier
    }

    // Custom decoder to generate ID if missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try to decode id, or generate one if missing
        if let decodedId = try? container.decode(String.self, forKey: .id) {
            id = decodedId
        } else {
            // Generate a UUID if id is missing
            id = UUID().uuidString
        }

        title = try container.decode(String.self, forKey: .title)
        genre = try container.decode(String.self, forKey: .genre)
        description = try container.decode(String.self, forKey: .description)
        hook = try? container.decode(String.self, forKey: .hook)
        themes = try? container.decode([String].self, forKey: .themes)
        ageRange = try? container.decode(String.self, forKey: .ageRange)
        generatedAt = try? container.decode(Date.self, forKey: .generatedAt)
        tier = try? container.decode(String.self, forKey: .tier)
    }
}

struct PremisesResponse: Codable {
    let premises: [Premise]
    let allPremisesUsed: Bool?
    let needsNewInterview: Bool?
    let premisesId: String?

    enum CodingKeys: String, CodingKey {
        case premises
        case allPremisesUsed = "allPremisesUsed"
        case needsNewInterview = "needsNewInterview"
        case premisesId
    }
}

// Result structure for getPremises
struct PremisesResult {
    let premises: [Premise]
    let needsNewInterview: Bool
    let premisesId: String?

    init(premises: [Premise], needsNewInterview: Bool, premisesId: String? = nil) {
        self.premises = premises
        self.needsNewInterview = needsNewInterview
        self.premisesId = premisesId
    }
}
