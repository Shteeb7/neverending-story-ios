//
//  ReadingStateManager.swift
//  NeverendingStory
//
//  Manages reading progress and state
//

import Foundation
import Combine

@MainActor
class ReadingStateManager: ObservableObject {
    static let shared = ReadingStateManager()

    @Published var currentStory: Story?
    @Published var chapters: [Chapter] = []
    @Published var currentChapterIndex: Int = 0
    @Published var scrollPosition: Double = 0

    private var saveTask: Task<Void, Never>?

    private init() {
        loadPersistedState()
    }

    // MARK: - Story Management

    func loadStory(_ story: Story) async throws {
        NSLog("📖 ReadingStateManager: loadStory() called for story: %@", story.title)
        NSLog("   Story ID: %@", story.id)

        self.currentStory = story
        self.currentChapterIndex = 0 // Start at beginning
        self.scrollPosition = 0

        // Fetch chapters (may be empty if still generating)
        NSLog("📡 ReadingStateManager: Fetching chapters from API...")
        do {
            self.chapters = try await APIManager.shared.getChapters(storyId: story.id)
            NSLog("✅ ReadingStateManager: Fetched %d chapters", self.chapters.count)
            if self.chapters.isEmpty {
                NSLog("⚠️ ReadingStateManager: Chapters array is EMPTY - story still generating or no chapters exist")
            } else {
                NSLog("📚 ReadingStateManager: Chapter titles:")
                for (index, chapter) in self.chapters.enumerated() {
                    NSLog("   %d: %@", index + 1, chapter.title)
                }
            }
        } catch {
            NSLog("❌ ReadingStateManager: Error fetching chapters: %@", error.localizedDescription)
            NSLog("   Error type: %@", String(describing: type(of: error)))
            NSLog("   Setting chapters to empty array")
            self.chapters = []
        }

        NSLog("📊 ReadingStateManager: Final state after loadStory:")
        NSLog("   currentChapter: %@", currentChapter?.title ?? "NIL")
        NSLog("   chapters.count: %d", chapters.count)
        NSLog("   currentChapterIndex: %d", currentChapterIndex)

        persistState()
    }

    func clearStory() {
        currentStory = nil
        chapters = []
        currentChapterIndex = 0
        scrollPosition = 0
        clearPersistedState()
    }

    // MARK: - Navigation

    var currentChapter: Chapter? {
        guard chapters.indices.contains(currentChapterIndex) else { return nil }
        return chapters[currentChapterIndex]
    }

    var canGoToPreviousChapter: Bool {
        return currentChapterIndex > 0
    }

    var canGoToNextChapter: Bool {
        return currentChapterIndex < chapters.count - 1
    }

    func goToPreviousChapter() {
        guard canGoToPreviousChapter else { return }
        currentChapterIndex -= 1
        scrollPosition = 0
        persistState()
    }

    func goToNextChapter() {
        guard canGoToNextChapter else { return }
        currentChapterIndex += 1
        scrollPosition = 0
        persistState()
    }

    func goToChapter(index: Int) {
        guard chapters.indices.contains(index) else { return }
        currentChapterIndex = index
        scrollPosition = 0
        persistState()
    }

    // MARK: - Progress Tracking

    func updateScrollPosition(_ position: Double) {
        self.scrollPosition = position
        debouncedSave()
    }

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await saveProgress()
        }
    }

    private func saveProgress() async {
        guard let storyId = currentStory?.id else { return }

        do {
            try await APIManager.shared.updateProgress(
                storyId: storyId,
                chapterNumber: currentChapterIndex + 1, // Convert back to 1-based
                scrollPosition: scrollPosition
            )
        } catch {
            print("Failed to save progress: \(error)")
        }
    }

    // MARK: - Persistence

    private func persistState() {
        guard let story = currentStory else { return }

        UserDefaults.standard.set(story.id, forKey: "currentStoryId")
        UserDefaults.standard.set(currentChapterIndex, forKey: "currentChapterIndex")
        UserDefaults.standard.set(scrollPosition, forKey: "scrollPosition")
    }

    private func loadPersistedState() {
        // State will be loaded when story is opened from library
        // This just loads the last known position
        if let _ = UserDefaults.standard.string(forKey: "currentStoryId") {
            currentChapterIndex = UserDefaults.standard.integer(forKey: "currentChapterIndex")
            scrollPosition = UserDefaults.standard.double(forKey: "scrollPosition")
        }
    }

    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: "currentStoryId")
        UserDefaults.standard.removeObject(forKey: "currentChapterIndex")
        UserDefaults.standard.removeObject(forKey: "scrollPosition")
    }
}
