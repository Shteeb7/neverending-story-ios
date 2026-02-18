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
    let coverImageUrl: String?
    let genre: String?
    let description: String?
    let seriesName: String?

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
        case coverImageUrl = "cover_image_url"
        case genre
        case description
        case seriesName = "series_name"
    }

    /// A book is only "generating" (not yet readable) if it has ZERO chapters.
    /// Once chapter 1 exists, the book is readable even if more chapters are being written.
    var isGenerating: Bool {
        if let progress = generationProgress {
            return status == "active" && progress.chaptersGenerated == 0
        }
        return false
    }

    /// True when the book has chapters but more are still being generated.
    /// Use this for showing a subtle "more chapters coming" indicator.
    var isGeneratingMoreChapters: Bool {
        if let progress = generationProgress {
            let step = progress.currentStep
            return status == "active" && progress.chaptersGenerated > 0 && step.hasPrefix("generating_")
        }
        return false
    }

    var progressText: String {
        if let progress = generationProgress {
            let step = progress.currentStep

            if progress.chaptersGenerated == 0 {
                // No chapters yet - show what's being worked on
                if step == "generating_arc" {
                    return "Plotting your story..."
                } else if step == "generating_bible" {
                    return "Building your world..."
                } else if step.hasPrefix("generating_chapter_") {
                    let chapterNum = step.replacingOccurrences(of: "generating_chapter_", with: "")
                    return "Conjuring chapter \(chapterNum)..."
                }
                return "Prospero is preparing your tale..."
            } else {
                // Has chapters — book is readable
                if step.hasPrefix("generating_") {
                    return "\(progress.chaptersGenerated) chapters ready, more on the way..."
                } else {
                    return "\(progress.chaptersGenerated) chapters ready"
                }
            }
        }
        return "Prospero is preparing your tale..."
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
