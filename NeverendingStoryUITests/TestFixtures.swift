import XCTest
import Foundation

class TestFixtures {

    static let supabaseURL = "https://hszuuvkfgdfqgtaycojz.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzenV1dmtmZ2RmcWd0YXljb2p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2NzA2NDUsImV4cCI6MjA4NjI0NjY0NX0.YvjON4hgMTt081xM_ZjqVqNRd9q_LXUdMCbBDeprRUU"

    // MARK: - Account Creation (real Supabase auth)

    /// Creates a real auth account via Supabase signup API.
    /// Returns (userId, accessToken) for subsequent seeding.
    static func createAccount(email: String, password: String) async throws -> (userId: String, accessToken: String) {
        let url = URL(string: "\(supabaseURL)/auth/v1/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")

        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TestFixtures", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "TestFixtures", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Signup failed: \(errorMsg)"])
        }

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let user = json["user"] as! [String: Any]
        let userId = user["id"] as! String
        let accessToken = json["access_token"] as! String

        return (userId, accessToken)
    }

    // MARK: - Cleanup

    /// Calls the existing cleanup_test_user RPC function
    static func cleanupTestUser(email: String) async {
        do {
            let url = URL(string: "\(supabaseURL)/rest/v1/rpc/cleanup_test_user")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")

            let body: [String: Any] = ["email_pattern": email]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("⚠️ Cleanup warning: \(errorMsg)")
            }
        } catch {
            print("⚠️ Cleanup error: \(error.localizedDescription)")
        }
    }

    // MARK: - State Seeding (direct Supabase REST inserts)

    static func seedUserPreferences(userId: String, accessToken: String, name: String = "Test User") async throws {
        let url = URL(string: "\(supabaseURL)/rest/v1/user_preferences")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let now = ISO8601DateFormatter().string(from: Date())
        let body: [String: Any] = [
            "user_id": userId,
            "ai_consent": true,
            "ai_consent_date": now,
            "voice_consent": true,
            "voice_consent_date": now,
            "birth_month": 1,
            "birth_year": 1990,
            "is_minor": false,
            "reading_level": "adult",
            "name_confirmed": true,
            "preferences": [
                "name": name,
                "favorite_genres": ["Fantasy", "Science Fiction"],
                "favorite_books": ["Lord of the Rings", "Harry Potter"]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TestFixtures", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "TestFixtures", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Seed user preferences failed: \(errorMsg)"])
        }
    }

    static func seedStory(userId: String, accessToken: String, title: String = "The Crimson Paradox", genre: String = "Fantasy", chapterCount: Int = 3, status: String = "active", generationStep: String = "awaiting_chapter_2_feedback") async throws -> (storyId: String, arcId: String) {

        // 1. Create story_bible first
        let bibleId = UUID().uuidString
        let bibleUrl = URL(string: "\(supabaseURL)/rest/v1/story_bibles")!
        var bibleRequest = URLRequest(url: bibleUrl)
        bibleRequest.httpMethod = "POST"
        bibleRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        bibleRequest.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        bibleRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        bibleRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let bibleBody: [String: Any] = [
            "id": bibleId,
            "user_id": userId,
            "story_id": UUID().uuidString, // temporary, will be updated
            "title": title,
            "world_rules": [:],
            "characters": [
                ["name": "Protagonist", "role": "Hero", "traits": ["brave", "curious"]]
            ],
            "central_conflict": ["type": "Person vs Nature"],
            "stakes": ["personal": "survival", "global": "world peace"],
            "themes": ["courage", "discovery"],
            "key_locations": ["The Crystal Fortress"],
            "timeline": []
        ]
        bibleRequest.httpBody = try JSONSerialization.data(withJSONObject: bibleBody)

        let (bibleData, bibleResponse) = try await URLSession.shared.data(for: bibleRequest)
        guard let bibleHttpResponse = bibleResponse as? HTTPURLResponse, (200...299).contains(bibleHttpResponse.statusCode) else {
            let errorMsg = String(data: bibleData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "TestFixtures", code: -1, userInfo: [NSLocalizedDescriptionKey: "Seed story bible failed: \(errorMsg)"])
        }

        // 2. Create story
        let storyId = UUID().uuidString
        let storyUrl = URL(string: "\(supabaseURL)/rest/v1/stories")!
        var storyRequest = URLRequest(url: storyUrl)
        storyRequest.httpMethod = "POST"
        storyRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        storyRequest.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        storyRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        storyRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let now = ISO8601DateFormatter().string(from: Date())
        let storyBody: [String: Any] = [
            "id": storyId,
            "user_id": userId,
            "bible_id": bibleId,
            "title": title,
            "genre": genre,
            "premise": "A young hero discovers a mysterious artifact that holds the key to saving their world.",
            "status": status,
            "current_chapter": 1,
            "generation_progress": [
                "current_step": generationStep,
                "chapters_generated": chapterCount,
                "started_at": now
            ]
        ]
        storyRequest.httpBody = try JSONSerialization.data(withJSONObject: storyBody)

        let (storyData, storyResponse) = try await URLSession.shared.data(for: storyRequest)
        guard let storyHttpResponse = storyResponse as? HTTPURLResponse, (200...299).contains(storyHttpResponse.statusCode) else {
            let errorMsg = String(data: storyData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "TestFixtures", code: -1, userInfo: [NSLocalizedDescriptionKey: "Seed story failed: \(errorMsg)"])
        }

        // 3. Update bible with correct story_id
        let updateBibleUrl = URL(string: "\(supabaseURL)/rest/v1/story_bibles?id=eq.\(bibleId)")!
        var updateBibleRequest = URLRequest(url: updateBibleUrl)
        updateBibleRequest.httpMethod = "PATCH"
        updateBibleRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        updateBibleRequest.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        updateBibleRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        updateBibleRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        updateBibleRequest.httpBody = try JSONSerialization.data(withJSONObject: ["story_id": storyId])

        _ = try await URLSession.shared.data(for: updateBibleRequest)

        // 4. Create story_arc
        let arcId = UUID().uuidString
        let arcUrl = URL(string: "\(supabaseURL)/rest/v1/story_arcs")!
        var arcRequest = URLRequest(url: arcUrl)
        arcRequest.httpMethod = "POST"
        arcRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        arcRequest.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        arcRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        arcRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let arcBody: [String: Any] = [
            "id": arcId,
            "story_id": storyId,
            "bible_id": bibleId,
            "arc_number": 1,
            "status": "in_progress",
            "outline": [
                "beginning": "The hero discovers the artifact",
                "middle": "They learn to use its power",
                "end": "They save the world"
            ],
            "chapters": []
        ]
        arcRequest.httpBody = try JSONSerialization.data(withJSONObject: arcBody)

        let (arcData, arcResponse) = try await URLSession.shared.data(for: arcRequest)
        guard let arcHttpResponse = arcResponse as? HTTPURLResponse, (200...299).contains(arcHttpResponse.statusCode) else {
            let errorMsg = String(data: arcData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "TestFixtures", code: -1, userInfo: [NSLocalizedDescriptionKey: "Seed story arc failed: \(errorMsg)"])
        }

        // 5. Update story with current_arc_id
        let updateStoryUrl = URL(string: "\(supabaseURL)/rest/v1/stories?id=eq.\(storyId)")!
        var updateStoryRequest = URLRequest(url: updateStoryUrl)
        updateStoryRequest.httpMethod = "PATCH"
        updateStoryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        updateStoryRequest.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        updateStoryRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        updateStoryRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        updateStoryRequest.httpBody = try JSONSerialization.data(withJSONObject: ["current_arc_id": arcId])

        _ = try await URLSession.shared.data(for: updateStoryRequest)

        // 6. Create chapters
        for chapterNum in 1...chapterCount {
            try await seedChapter(storyId: storyId, arcId: arcId, accessToken: accessToken, chapterNumber: chapterNum)
        }

        return (storyId, arcId)
    }

    private static func seedChapter(storyId: String, arcId: String, accessToken: String, chapterNumber: Int) async throws {
        let url = URL(string: "\(supabaseURL)/rest/v1/chapters")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        // Real-looking placeholder content (4 paragraphs ~50 words each for scrollability)
        let content = """
        The morning sun broke through the crystal spires of the fortress, casting rainbow patterns across the stone floor. Maya stood at the window, her fingers tracing the ancient runes etched into the glass. She had been here for three days now, and still the artifact pulsed with that strange, otherworldly energy. The elders had warned her about touching it, but she couldn't resist its call.

        Down in the courtyard below, soldiers practiced their morning drills. Their synchronized movements reminded her of home, of simpler times before the darkness came. She wondered if her family was safe, if they even knew where she had gone. The letter she'd left seemed so inadequate now, so childish in its brevity. But there had been no time for proper goodbyes.

        A knock at the door startled her from her thoughts. "Come in," she called, turning from the window. The door creaked open and Elder Thorne entered, his weathered face grave. "We need to talk about what happened last night," he said, his voice low and serious. Maya's heart sank. She had hoped no one had noticed the glow emanating from her room at midnight.

        "I know what you're going to say," she began, but he held up a hand. "You don't understand the power you're wielding," he interrupted. "The artifact chose you for a reason, but that doesn't mean you're ready for what comes next." He moved to the table and unrolled a ancient map, its edges yellowed with age. "There are others like you, scattered across the realm. You must find them before the shadow does."
        """

        let body: [String: Any] = [
            "story_id": storyId,
            "arc_id": arcId,
            "chapter_number": chapterNumber,
            "title": "Chapter \(chapterNumber)",
            "content": content,
            "word_count": 300
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "TestFixtures", code: -1, userInfo: [NSLocalizedDescriptionKey: "Seed chapter \(chapterNumber) failed: \(errorMsg)"])
        }
    }

    static func seedCheckpointFeedback(userId: String, storyId: String, accessToken: String, checkpointNumber: Int) async throws {
        let url = URL(string: "\(supabaseURL)/rest/v1/story_feedback")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let body: [String: Any] = [
            "user_id": userId,
            "story_id": storyId,
            "checkpoint": "chapter_\(checkpointNumber)",
            "pacing_feedback": "hooked",
            "tone_feedback": "right",
            "character_feedback": "love"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "TestFixtures", code: -1, userInfo: [NSLocalizedDescriptionKey: "Seed checkpoint feedback failed: \(errorMsg)"])
        }
    }

    static func seedReadingSessions(userId: String, storyId: String, accessToken: String, throughChapter: Int) async throws {
        for chapter in 1...throughChapter {
            let url = URL(string: "\(supabaseURL)/rest/v1/reading_sessions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

            let now = ISO8601DateFormatter().string(from: Date())
            let sessionEnd = ISO8601DateFormatter().string(from: Date().addingTimeInterval(600)) // 10 min later

            let body: [String: Any] = [
                "user_id": userId,
                "story_id": storyId,
                "chapter_number": chapter,
                "session_start": now,
                "session_end": sessionEnd,
                "reading_duration_seconds": 600,
                "max_scroll_progress": 100,
                "completed": true
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            _ = try await URLSession.shared.data(for: request)
        }
    }

    // MARK: - Mid-Test Seeding (called during a running test, not just setUp)

    /// Seeds additional chapters into an EXISTING story mid-test.
    static func seedAdditionalChapters(storyId: String, arcId: String, accessToken: String, fromChapter: Int, toChapter: Int) async throws {
        for chapterNum in fromChapter...toChapter {
            try await seedChapter(storyId: storyId, arcId: arcId, accessToken: accessToken, chapterNumber: chapterNum)
        }
    }

    /// Looks up the most recently created story for a user.
    static func fetchLatestStory(userId: String, accessToken: String) async throws -> (storyId: String, arcId: String?) {
        let url = URL(string: "\(supabaseURL)/rest/v1/stories?user_id=eq.\(userId)&order=created_at.desc&limit=1")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "TestFixtures", code: -1, userInfo: [NSLocalizedDescriptionKey: "Fetch latest story failed: \(errorMsg)"])
        }

        let json = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        guard let story = json.first else {
            throw NSError(domain: "TestFixtures", code: -1, userInfo: [NSLocalizedDescriptionKey: "No story found"])
        }

        let storyId = story["id"] as! String
        let arcId = story["current_arc_id"] as? String

        return (storyId, arcId)
    }

    /// Updates generation_progress on an existing story.
    static func updateGenerationProgress(storyId: String, accessToken: String, step: String, chaptersGenerated: Int) async throws {
        let url = URL(string: "\(supabaseURL)/rest/v1/stories?id=eq.\(storyId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let now = ISO8601DateFormatter().string(from: Date())
        let body: [String: Any] = [
            "generation_progress": [
                "current_step": step,
                "chapters_generated": chaptersGenerated,
                "started_at": now
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "TestFixtures", code: -1, userInfo: [NSLocalizedDescriptionKey: "Update generation progress failed: \(errorMsg)"])
        }
    }
}

// MARK: - Named State Presets

extension TestFixtures {

    /// PRESET: fresh-user — Account only. Login screen.
    static func seedFreshUser(email: String, password: String) async throws -> (userId: String, accessToken: String) {
        return try await createAccount(email: email, password: password)
    }

    /// PRESET: post-onboarding — Preferences set, no stories.
    static func seedPostOnboarding(email: String, password: String) async throws -> (userId: String, accessToken: String) {
        let (userId, accessToken) = try await createAccount(email: email, password: password)
        try await seedUserPreferences(userId: userId, accessToken: accessToken, name: "Test User")
        return (userId, accessToken)
    }

    /// PRESET: mid-story — 1 story, 6 chapters, read through ch4.
    static func seedMidStory(email: String, password: String) async throws -> (userId: String, accessToken: String, storyId: String) {
        let (userId, accessToken) = try await createAccount(email: email, password: password)
        try await seedUserPreferences(userId: userId, accessToken: accessToken)
        let (storyId, _) = try await seedStory(userId: userId, accessToken: accessToken, chapterCount: 6, generationStep: "awaiting_chapter_5_feedback")
        try await seedReadingSessions(userId: userId, storyId: storyId, accessToken: accessToken, throughChapter: 4)
        try await seedCheckpointFeedback(userId: userId, storyId: storyId, accessToken: accessToken, checkpointNumber: 2)
        return (userId, accessToken, storyId)
    }

    /// PRESET: end-of-book — 1 story, 12 chapters, read through ch11.
    static func seedEndOfBook(email: String, password: String) async throws -> (userId: String, accessToken: String, storyId: String) {
        let (userId, accessToken) = try await createAccount(email: email, password: password)
        try await seedUserPreferences(userId: userId, accessToken: accessToken)
        let (storyId, _) = try await seedStory(userId: userId, accessToken: accessToken, chapterCount: 12, status: "active", generationStep: "complete")
        try await seedReadingSessions(userId: userId, storyId: storyId, accessToken: accessToken, throughChapter: 11)
        try await seedCheckpointFeedback(userId: userId, storyId: storyId, accessToken: accessToken, checkpointNumber: 2)
        try await seedCheckpointFeedback(userId: userId, storyId: storyId, accessToken: accessToken, checkpointNumber: 5)
        try await seedCheckpointFeedback(userId: userId, storyId: storyId, accessToken: accessToken, checkpointNumber: 8)
        return (userId, accessToken, storyId)
    }

    /// PRESET: multi-book — 2 completed + 1 in-progress stories.
    static func seedMultiBook(email: String, password: String) async throws -> (userId: String, accessToken: String) {
        let (userId, accessToken) = try await createAccount(email: email, password: password)
        try await seedUserPreferences(userId: userId, accessToken: accessToken)

        // Story 1: completed
        let (story1, _) = try await seedStory(userId: userId, accessToken: accessToken, title: "The First Adventure", chapterCount: 12, status: "completed", generationStep: "complete")
        try await seedReadingSessions(userId: userId, storyId: story1, accessToken: accessToken, throughChapter: 12)

        // Story 2: completed
        let (story2, _) = try await seedStory(userId: userId, accessToken: accessToken, title: "The Second Quest", chapterCount: 12, status: "completed", generationStep: "complete")
        try await seedReadingSessions(userId: userId, storyId: story2, accessToken: accessToken, throughChapter: 12)

        // Story 3: in progress
        let (story3, _) = try await seedStory(userId: userId, accessToken: accessToken, title: "The Third Journey", chapterCount: 6, status: "active", generationStep: "awaiting_chapter_5_feedback")
        try await seedReadingSessions(userId: userId, storyId: story3, accessToken: accessToken, throughChapter: 4)

        return (userId, accessToken)
    }

    /// PRESET: minor-user — Age 15, teen privacy defaults.
    static func seedMinorUser(email: String, password: String) async throws -> (userId: String, accessToken: String) {
        let (userId, accessToken) = try await createAccount(email: email, password: password)

        // Seed preferences with minor settings
        let url = URL(string: "\(supabaseURL)/rest/v1/user_preferences")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let now = ISO8601DateFormatter().string(from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())

        let body: [String: Any] = [
            "user_id": userId,
            "ai_consent": true,
            "ai_consent_date": now,
            "voice_consent": true,
            "voice_consent_date": now,
            "birth_month": 6,
            "birth_year": currentYear - 15, // Age 15
            "is_minor": true,
            "reading_level": "young_adult",
            "name_confirmed": true,
            "preferences": [
                "name": "Teen Test User"
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        _ = try await URLSession.shared.data(for: request)

        return (userId, accessToken)
    }

    /// PRESET: clone-user — Mirrors a real user's exact data state.
    static func seedCloneUser(email: String, password: String, sourceEmail: String) async throws -> (userId: String, accessToken: String) {
        // Create new account
        let (userId, accessToken) = try await createAccount(email: email, password: password)

        // Fetch source user data via RPC
        let url = URL(string: "\(supabaseURL)/rest/v1/rpc/clone_user_data")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = ["source_email": sourceEmail]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "TestFixtures", code: -1, userInfo: [NSLocalizedDescriptionKey: "Clone user data failed: \(errorMsg)"])
        }

        // TODO: Parse the returned JSON and insert it into the test account
        // For now, this is a placeholder that just creates the account
        print("⚠️ clone-user preset needs full implementation - currently just creates account")

        return (userId, accessToken)
    }
}
