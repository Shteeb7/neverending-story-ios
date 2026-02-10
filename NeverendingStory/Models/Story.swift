//
//  Story.swift
//  NeverendingStory
//
//  Story data model
//

import Foundation

struct Story: Codable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let genre: String
    let premise: String
    let currentChapter: Int
    let totalChapters: Int
    let createdAt: Date
    let updatedAt: Date
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case genre
        case premise
        case currentChapter = "current_chapter"
        case totalChapters = "total_chapters"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isActive = "is_active"
    }

    var progress: Double {
        guard totalChapters > 0 else { return 0 }
        return Double(currentChapter) / Double(totalChapters)
    }

    var progressText: String {
        return "Chapter \(currentChapter) of \(totalChapters)"
    }
}
