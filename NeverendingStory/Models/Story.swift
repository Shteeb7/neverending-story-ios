//
//  Story.swift
//  NeverendingStory
//
//  Story data model
//

import Foundation

struct Story: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let title: String
    let status: String
    let premiseId: String?
    let bibleId: String?
    let generationProgress: GenerationProgress?
    let createdAt: Date
    let chaptersGenerated: Int?
    let seriesId: String?
    let bookNumber: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case status
        case premiseId = "premise_id"
        case bibleId = "bible_id"
        case generationProgress = "generation_progress"
        case createdAt = "created_at"
        case chaptersGenerated = "chapters_generated"
        case seriesId = "series_id"
        case bookNumber = "book_number"
    }

    var isGenerating: Bool {
        if let progress = generationProgress {
            return status == "active" && progress.chaptersGenerated < 6
        }
        return status == "active"
    }

    var progressText: String {
        if let progress = generationProgress {
            if progress.chaptersGenerated >= 6 {
                return "\(progress.chaptersGenerated) chapters ready"
            } else if progress.chaptersGenerated > 0 {
                return "Writing chapter \(progress.chaptersGenerated + 1) of 6..."
            }
        }
        return "Starting your story..."
    }
}

struct GenerationProgress: Codable, Hashable {
    let bibleComplete: Bool
    let arcComplete: Bool
    let chaptersGenerated: Int
    let currentStep: String
    let lastUpdated: String

    enum CodingKeys: String, CodingKey {
        case bibleComplete = "bible_complete"
        case arcComplete = "arc_complete"
        case chaptersGenerated = "chapters_generated"
        case currentStep = "current_step"
        case lastUpdated = "last_updated"
    }
}
