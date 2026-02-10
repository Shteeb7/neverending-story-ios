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
    let generatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case genre
        case description
        case generatedAt = "generated_at"
    }
}

struct PremisesResponse: Codable {
    let premises: [Premise]
}
