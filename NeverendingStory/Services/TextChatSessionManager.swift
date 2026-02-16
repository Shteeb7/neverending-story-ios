//
//  TextChatSessionManager.swift
//  NeverendingStory
//
//  Manages text-based chat sessions with Prospero (alternative to voice interviews)
//

import Foundation

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: String  // "user" or "assistant"
    let content: String

    init(id: UUID = UUID(), role: String, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }

    // Custom decoder that generates a fresh UUID on decode
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.role = try container.decode(String.self, forKey: .role)
        self.content = try container.decode(String.self, forKey: .content)
    }

    // Exclude id from encoding
    enum CodingKeys: String, CodingKey {
        case role, content
    }
}

// MARK: - Text Chat Session Manager

@MainActor
class TextChatSessionManager: ObservableObject {
    // Published state
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var sessionComplete = false
    @Published var isSessionActive = false
    @Published var error: String?

    // Session state
    var sessionId: String?
    var interviewType: InterviewType = .onboarding

    // Callback for when preferences/feedback are gathered (same as VoiceSessionManager)
    var onPreferencesGathered: (([String: Any]) -> Void)?

    // MARK: - Start Session

    /// Start a new text chat session with Prospero
    /// - Parameters:
    ///   - type: The interview type (onboarding, returningUser, bookCompletion)
    ///   - context: Optional context (for returning users or book completion)
    func startSession(type: InterviewType, context: [String: Any]? = nil) async {
        NSLog("📝 Starting text chat session: \(type)")

        isLoading = true
        error = nil
        messages = []
        sessionComplete = false
        interviewType = type

        do {
            // Prepare context based on interview type
            var requestContext: [String: Any] = context ?? [:]

            // Map InterviewType to string for API
            let interviewTypeString: String
            switch type {
            case .onboarding:
                interviewTypeString = "onboarding"
            case .returningUser(let ctx):
                interviewTypeString = "returning_user"
                // Build context from ReturningUserContext
                requestContext = [
                    "userName": ctx.userName,
                    "previousStoryTitles": ctx.previousStoryTitles,
                    "preferredGenres": ctx.preferredGenres,
                    "discardedPremises": ctx.discardedPremises.map { premise in
                        return [
                            "title": premise.title,
                            "description": premise.description,
                            "tier": premise.tier
                        ]
                    }
                ]
            case .premiseRejection:
                // Text chat doesn't support premise rejection yet - fall back to onboarding
                interviewTypeString = "onboarding"
                NSLog("⚠️ premiseRejection not supported in text chat, using onboarding")
            case .bookCompletion(let ctx):
                interviewTypeString = "book_completion"
                // Build context from BookCompletionContext
                requestContext = [
                    "userName": ctx.userName,
                    "storyTitle": ctx.storyTitle,
                    "storyGenre": ctx.storyGenre ?? "",
                    "premiseTier": ctx.premiseTier ?? "",
                    "protagonistName": ctx.protagonistName ?? "",
                    "centralConflict": ctx.centralConflict ?? "",
                    "themes": ctx.themes,
                    "lingeredChapters": ctx.lingeredChapters.map { ["chapter": $0.chapter, "minutes": $0.minutes] },
                    "skimmedChapters": ctx.skimmedChapters,
                    "rereadChapters": ctx.rereadChapters.map { ["chapter": $0.chapter, "sessions": $0.sessions] },
                    "checkpointFeedback": ctx.checkpointFeedback.map { ["checkpoint": $0.checkpoint, "response": $0.response] },
                    "bookNumber": ctx.bookNumber
                ]
            }

            // Call API to start session
            let result = try await APIManager.shared.startChatSession(
                interviewType: interviewTypeString,
                context: requestContext.isEmpty ? nil : requestContext
            )

            sessionId = result.sessionId

            // Add Prospero's opening message
            let openingMsg = ChatMessage(role: "assistant", content: result.openingMessage)
            messages.append(openingMsg)

            isSessionActive = true
            NSLog("✅ Text chat session started: \(result.sessionId)")
            NSLog("   Opening message: \"\(result.openingMessage.prefix(100))...\"")

        } catch {
            NSLog("❌ Failed to start text chat session: \(error)")
            self.error = "Failed to start conversation: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Send Message

    /// Send a message to Prospero
    /// - Parameter text: The user's message
    func sendMessage(_ text: String) async {
        guard let sessionId = sessionId, !text.isEmpty else {
            NSLog("⚠️ Cannot send message: no session or empty text")
            return
        }

        NSLog("💬 Sending message: \"\(text.prefix(50))...\"")

        // Add user message immediately to UI
        let userMsg = ChatMessage(role: "user", content: text)
        messages.append(userMsg)

        isLoading = true
        error = nil

        do {
            // Call API
            let result = try await APIManager.shared.sendChatMessage(
                sessionId: sessionId,
                message: text
            )

            // Add Prospero's response
            let assistantMsg = ChatMessage(role: "assistant", content: result.message)
            messages.append(assistantMsg)

            NSLog("✅ Received response: \"\(result.message.prefix(100))...\"")

            // Check if conversation is complete
            if result.sessionComplete {
                NSLog("🎯 Conversation complete!")
                sessionComplete = true
                isSessionActive = false

                // Trigger callback with tool arguments (same pattern as VoiceSessionManager)
                if let toolCall = result.toolCall {
                    NSLog("🔧 Tool called: \(toolCall.name)")
                    NSLog("   Arguments: \(toolCall.arguments)")
                    onPreferencesGathered?(toolCall.arguments)
                }
            }

        } catch {
            NSLog("❌ Failed to send message: \(error)")
            self.error = "Failed to send message: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Resume Session

    /// Resume an existing text chat session
    /// - Parameter id: The session ID to resume
    func resumeSession(id: String) async {
        NSLog("🔄 Resuming text chat session: \(id)")

        isLoading = true
        error = nil

        do {
            let session = try await APIManager.shared.getChatSession(sessionId: id)

            sessionId = id

            // Parse messages from session
            if let messagesArray = session["messages"] as? [[String: Any]] {
                messages = messagesArray.compactMap { msgDict in
                    guard let role = msgDict["role"] as? String,
                          let content = msgDict["content"] as? String else {
                        return nil
                    }
                    return ChatMessage(role: role, content: content)
                }
            }

            // Set session state
            if let status = session["status"] as? String {
                sessionComplete = (status == "completed")
                isSessionActive = (status == "active")
            }

            NSLog("✅ Session resumed: \(messages.count) messages")

        } catch {
            NSLog("❌ Failed to resume session: \(error)")
            self.error = "Failed to resume conversation: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Reset

    /// Reset the chat session (for starting fresh)
    func reset() {
        NSLog("🔄 Resetting text chat session")
        sessionId = nil
        messages = []
        isLoading = false
        sessionComplete = false
        isSessionActive = false
        error = nil
    }
}
