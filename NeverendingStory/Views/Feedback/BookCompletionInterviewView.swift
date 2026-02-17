//
//  BookCompletionInterviewView.swift
//  NeverendingStory
//
//  Voice interview with Prospero after finishing chapter 12
//

import SwiftUI

struct BookCompletionInterviewView: View {
    let story: Story
    let bookNumber: Int
    let onComplete: ([String: Any]) -> Void

    @StateObject private var voiceSession = VoiceSessionManager()
    @StateObject private var textChatManager = TextChatSessionManager()
    @Environment(\.dismiss) private var dismiss

    @State private var hasStarted = false
    @State private var hasPermission = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    @State private var showBookComplete = false
    @State private var interviewPreferences: [String: Any] = [:]
    @State private var showTextChat = false

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                if !hasStarted {
                    // Welcome screen
                    welcomeView
                } else {
                    // Interview in progress
                    interviewView
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            configureVoiceSession()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showTextChat) {
            // Build book completion context for text chat
            TextChatView(
                interviewType: .bookCompletion(context: buildBookCompletionContext()),
                context: nil,
                onComplete: {
                    showTextChat = false
                    // Text chat callback already handled preferences
                }
            )
        }
        .fullScreenCover(isPresented: $showBookComplete) {
            BookCompleteView(
                story: story,
                bookNumber: bookNumber,
                onStartSequel: {
                    // Navigate to sequel generation
                    showBookComplete = false
                    // Callback will handle navigation to SequelGenerationView
                    onComplete(interviewPreferences)
                },
                onReturnToLibrary: {
                    showBookComplete = false
                    dismiss()
                }
            )
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Prospero avatar
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.4),
                                Color.blue.opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)

                Image(systemName: "sparkles")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: .purple.opacity(0.4), radius: 30)

            // Title
            VStack(spacing: 16) {
                Text("You finished!")
                    .font(.system(size: 32, weight: .bold))

                Text(story.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Description
            Text("Prospero wants to hear what you thought about the story! Share your experience through voice or text to help conjure the perfect Book 2.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)

            Spacer()

            // Side-by-side Speak / Write buttons
            HStack(spacing: 12) {
                // Speak with Prospero button
                Button(action: { startInterview() }) {
                    VStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 28))
                        Text("Speak with\nProspero")
                            .font(.system(size: 14, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: .purple.opacity(0.3), radius: 10, y: 5)
                }

                // Write to Prospero button
                Button(action: { startTextChat() }) {
                    VStack(spacing: 8) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 28))
                        Text("Write to\nProspero")
                            .font(.system(size: 14, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: .purple.opacity(0.3), radius: 10, y: 5)
                }
            }
            .padding(.horizontal, 8)

            // Skip button
            Button(action: { dismiss() }) {
                Text("Skip for now")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
        }
    }

    private var interviewView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Status indicator
            statusView

            // Audio visualization
            if case .listening = voiceSession.state {
                audioVisualization
            }

            // Conversation text
            if !voiceSession.conversationText.isEmpty {
                ScrollView {
                    Text(voiceSession.conversationText)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(12)
                }
                .frame(maxHeight: 300)
            }

            Spacer()

            // End button
            if case .listening = voiceSession.state {
                Button(action: { endInterview() }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("End Interview")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            } else if case .processing = voiceSession.state {
                Button(action: { endInterview() }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("End Interview")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }

            // Error state with retry button
            if case .error = voiceSession.state {
                VStack(spacing: 12) {
                    Button(action: {
                        startInterview()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    Button(action: { dismiss() }) {
                        Text("Return to Library")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Fallback buttons for completed state (prevents dead end)
            if case .conversationComplete = voiceSession.state, !isProcessing {
                VStack(spacing: 12) {
                    Button(action: {
                        // Show book complete even if submission failed
                        showBookComplete = true
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Continue")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    Button(action: { dismiss() }) {
                        Text("Return to Library")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Processing indicator
            if isProcessing {
                HStack {
                    ProgressView()
                    Text("Processing interview...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        VStack(spacing: 12) {
            // Prospero avatar (smaller)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.3),
                                Color.blue.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(statusText)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
    }

    private var statusText: String {
        switch voiceSession.state {
        case .connecting:
            return "Connecting to Prospero..."
        case .connected:
            return "Connected! Prospero is ready to listen."
        case .listening:
            return "Prospero is listening..."
        case .processing:
            return "Prospero is thinking..."
        case .conversationComplete:
            return "Interview complete!"
        case .error(let message):
            return "Error: \(message)"
        default:
            return "Preparing..."
        }
    }

    private var audioVisualization: some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.purple)
                    .frame(width: 3)
                    .frame(height: CGFloat.random(in: 20...60) * CGFloat(voiceSession.audioLevel + 0.2))
                    .animation(.easeInOut(duration: 0.1).repeatForever(), value: voiceSession.audioLevel)
            }
        }
        .frame(height: 80)
    }

    // MARK: - Functions

    private func configureVoiceSession() {
        // Set up callback for when interview is complete
        voiceSession.onPreferencesGathered = { preferences in
            NSLog("📝 Book completion preferences gathered: \(preferences)")
            handleInterviewComplete(preferences)
        }
    }

    private func startTextChat() {
        NSLog("📝 Starting text chat for book completion")

        // Set up callback for text chat
        textChatManager.onPreferencesGathered = { preferences in
            DispatchQueue.main.async {
                NSLog("✅ Text chat preferences received: \(preferences)")
                self.handleInterviewComplete(preferences)
            }
        }

        showTextChat = true
    }

    private func startInterview() {
        Task {
            // Request microphone permission
            let hasPermission = await voiceSession.requestMicrophonePermission()

            guard hasPermission else {
                errorMessage = "Microphone permission is required for voice interviews"
                showError = true
                return
            }

            // Configure book completion interview type
            await configureBookCompletionSession()

            hasStarted = true

            do {
                try await voiceSession.startSession()
            } catch {
                errorMessage = "Failed to start voice session: \(error.localizedDescription)"
                showError = true
                hasStarted = false
            }
        }
    }

    private func configureBookCompletionSession() async {
        // Fetch rich completion context from backend
        guard let userId = AuthManager.shared.user?.id else {
            NSLog("⚠️ No user ID for book completion session")
            return
        }

        let userName = await fetchUserName(userId: userId) ?? "friend"

        // Fetch completion context (story + bible + reading behavior + checkpoint feedback)
        guard let contextData = try? await APIManager.shared.getCompletionContext(storyId: story.id) else {
            NSLog("⚠️ Failed to fetch completion context, using minimal context")
            let minimalContext = BookCompletionContext(
                userName: userName,
                storyTitle: story.title,
                storyGenre: story.genre,
                premiseTier: nil,
                protagonistName: nil,
                centralConflict: nil,
                themes: [],
                lingeredChapters: [],
                skimmedChapters: [],
                rereadChapters: [],
                checkpointFeedback: [],
                bookNumber: bookNumber
            )
            voiceSession.interviewType = .bookCompletion(context: minimalContext)
            return
        }

        // Extract data from API response
        let storyInfo = contextData["story"] as? [String: Any]
        let bibleInfo = contextData["bible"] as? [String: Any]
        let readingBehavior = contextData["readingBehavior"] as? [String: Any]
        let checkpointFeedback = contextData["checkpointFeedback"] as? [[String: Any]]

        // Build lingered chapters array
        let lingered: [(chapter: Int, minutes: Int)] = (readingBehavior?["lingeredChapters"] as? [[String: Any]])?.compactMap {
            guard let chapter = $0["chapter"] as? Int, let minutes = $0["minutes"] as? Int else { return nil }
            return (chapter, minutes)
        } ?? []

        // Build skimmed chapters array
        let skimmed = readingBehavior?["skimmedChapters"] as? [Int] ?? []

        // Build reread chapters array
        let reread: [(chapter: Int, sessions: Int)] = (readingBehavior?["rereadChapters"] as? [[String: Any]])?.compactMap {
            guard let chapter = $0["chapter"] as? Int, let sessions = $0["sessions"] as? Int else { return nil }
            return (chapter, sessions)
        } ?? []

        // Build checkpoint feedback array
        let feedback: [(checkpoint: String, response: String)] = checkpointFeedback?.compactMap {
            guard let checkpoint = $0["checkpoint"] as? String,
                  let response = $0["response"] as? String else { return nil }
            return (checkpoint, response)
        } ?? []

        let context = BookCompletionContext(
            userName: userName,
            storyTitle: storyInfo?["title"] as? String ?? story.title,
            storyGenre: storyInfo?["genre"] as? String,
            premiseTier: storyInfo?["premiseTier"] as? String,
            protagonistName: bibleInfo?["protagonistName"] as? String,
            centralConflict: bibleInfo?["centralConflict"] as? String,
            themes: bibleInfo?["themes"] as? [String] ?? [],
            lingeredChapters: lingered,
            skimmedChapters: skimmed,
            rereadChapters: reread,
            checkpointFeedback: feedback,
            bookNumber: bookNumber
        )

        voiceSession.interviewType = .bookCompletion(context: context)
        NSLog("✅ Configured book completion session for \(userName) - \"\(story.title)\"")
        NSLog("   Reading behavior: \(lingered.count) lingered, \(skimmed.count) skimmed, \(reread.count) reread")
    }

    private func buildBookCompletionContext() -> BookCompletionContext {
        // Build a minimal context synchronously for text chat
        // We can't use async fetching in the view builder, so use placeholder values
        // Text chat backend will fetch full context from API
        BookCompletionContext(
            userName: "friend",  // Placeholder - backend will get real name
            storyTitle: story.title,
            storyGenre: story.genre,
            premiseTier: nil,
            protagonistName: nil,
            centralConflict: nil,
            themes: [],
            lingeredChapters: [],
            skimmedChapters: [],
            rereadChapters: [],
            checkpointFeedback: [],
            bookNumber: bookNumber
        )
    }

    private func fetchUserName(userId: String) async -> String? {
        do {
            // Try to get name from user_preferences table
            let result = try await APIManager.shared.getUserPreferences(userId: userId)
            if let name = result?["name"] as? String {
                return name
            }
        } catch {
            NSLog("⚠️ Could not fetch user name: \(error)")
        }
        return nil
    }

    private func endInterview() {
        voiceSession.endSession()

        // If they end early without completing, just dismiss
        if !voiceSession.isConversationComplete {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        }
    }

    private func handleInterviewComplete(_ preferences: [String: Any]) {
        isProcessing = true

        Task {
            do {
                // Submit interview to backend
                let _ = try await APIManager.shared.submitCompletionInterview(
                    storyId: story.id,
                    transcript: voiceSession.conversationText,
                    sessionId: nil,
                    preferences: preferences
                )

                NSLog("✅ Completion interview submitted successfully")

                // Store preferences and show book complete screen
                await MainActor.run {
                    interviewPreferences = preferences
                    isProcessing = false
                    showBookComplete = true
                }

            } catch {
                NSLog("❌ Failed to submit completion interview: \(error)")
                // Still allow the user to proceed even if backend submission failed
                // The interview data is in the transcript and can be recovered
                await MainActor.run {
                    interviewPreferences = preferences
                    isProcessing = false
                    showBookComplete = true  // Show completion screen anyway
                }
            }
        }
    }
}

#Preview {
    BookCompletionInterviewView(
        story: Story(
            id: "preview-story",
            userId: "preview-user",
            title: "The Dragon's Quest",
            status: "active",
            premiseId: nil,
            bibleId: nil,
            generationProgress: nil,
            createdAt: Date(),
            chaptersGenerated: 12,
            seriesId: nil,
            bookNumber: 1,
            coverImageUrl: nil,
            genre: "Fantasy",
            description: "An epic dragon adventure"
        ),
        bookNumber: 1,
        onComplete: { preferences in
            print("Interview complete: \(preferences)")
        }
    )
}
