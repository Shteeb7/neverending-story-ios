//
//  StoryRealtimeManager.swift
//  NeverendingStory
//
//  Manages Supabase Realtime subscriptions for story and chapter updates
//

import Foundation
import Supabase
import Realtime

@MainActor
class StoryRealtimeManager: ObservableObject {
    static let shared = StoryRealtimeManager()

    // Published events that views observe
    @Published var lastChapterInsert: ChapterInsertEvent?
    @Published var lastStoryUpdate: StoryUpdateEvent?

    private var channel: RealtimeChannelV2?
    private var isSubscribed = false

    struct ChapterInsertEvent: Identifiable {
        let id = UUID()
        let storyId: String
        let chapterNumber: Int
        let timestamp: Date
    }

    struct StoryUpdateEvent: Identifiable {
        let id = UUID()
        let storyId: String
        let currentStep: String?
        let chaptersGenerated: Int?
        let timestamp: Date
    }

    private init() {}

    /// Call when user logs in or app becomes active
    func subscribe(userId: String) async {
        guard !isSubscribed else { return }

        let supabase = AuthManager.shared.supabase
        let myChannel = await supabase.channel("story-updates")

        // Listen for new chapter inserts
        let chapterInserts = await myChannel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "chapters"
        )

        // Listen for story progress updates
        let storyUpdates = await myChannel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "stories"
        )

        await myChannel.subscribe()
        self.channel = myChannel
        self.isSubscribed = true

        NSLog("📡 Realtime subscribed for user \(userId)")

        // Process chapter inserts
        Task {
            for await insert in chapterInserts {
                let record = insert.record
                // Extract story_id and chapter_number from the insert payload
                if let storyId = record["story_id"]?.stringValue,
                   let chapterNum = record["chapter_number"]?.intValue {
                    NSLog("📡 Realtime: New chapter \(chapterNum) for story \(storyId)")
                    self.lastChapterInsert = ChapterInsertEvent(
                        storyId: storyId,
                        chapterNumber: chapterNum,
                        timestamp: Date()
                    )
                }
            }
        }

        // Process story updates
        Task {
            for await update in storyUpdates {
                let record = update.record
                if let storyId = record["id"]?.stringValue {
                    // Extract generation_progress fields
                    let currentStep = record["generation_progress"]?
                        .objectValue?["current_step"]?.stringValue
                    let chaptersGenerated = record["generation_progress"]?
                        .objectValue?["chapters_generated"]?.intValue

                    NSLog("📡 Realtime: Story \(storyId) updated → step: \(currentStep ?? "nil")")
                    self.lastStoryUpdate = StoryUpdateEvent(
                        storyId: storyId,
                        currentStep: currentStep,
                        chaptersGenerated: chaptersGenerated,
                        timestamp: Date()
                    )
                }
            }
        }
    }

    /// Call when user logs out
    func unsubscribe() async {
        if let channel = channel {
            await AuthManager.shared.supabase.removeChannel(channel)
        }
        channel = nil
        isSubscribed = false
        NSLog("📡 Realtime unsubscribed")
    }
}
