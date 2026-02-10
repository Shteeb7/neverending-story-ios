//
//  Chapter.swift
//  NeverendingStory
//
//  Chapter data model
//

import Foundation

struct Chapter: Codable, Identifiable {
    let id: String
    let storyId: String
    let chapterNumber: Int
    let title: String
    let content: String
    let wordCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case storyId = "story_id"
        case chapterNumber = "chapter_number"
        case title
        case content
        case wordCount = "word_count"
        case createdAt = "created_at"
    }
}
