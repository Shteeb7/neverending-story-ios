//
//  APIManager.swift
//  NeverendingStory
//
//  Railway backend API client
//

import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .unauthorized:
            return "Authentication required. Please log in again."
        }
    }
}

@MainActor
class APIManager: ObservableObject {
    static let shared = APIManager()

    private let baseURL = AppConfig.apiBaseURL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let urlSession: URLSession

    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // Create custom URLSession with 5-minute timeout for AI generation
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300 // 5 minutes
        configuration.timeoutIntervalForResource = 300
        urlSession = URLSession(configuration: configuration)
    }

    // MARK: - Helper Methods

    private func makeRequest<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        requiresAuth: Bool = true,
        userId: String? = nil  // NEW: Allow passing userId directly
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            // Get the Supabase access token for authorization
            guard let accessToken = AuthManager.shared.accessToken else {
                NSLog("❌ APIManager: NO ACCESS TOKEN FOUND")
                throw APIError.unauthorized
            }

            // Use provided userId if available, otherwise check AuthManager
            let userIdToUse: String
            if let providedUserId = userId {
                userIdToUse = providedUserId
                NSLog("✅ Using provided userId: %@", providedUserId)
            } else {
                NSLog("🔍 No userId provided, checking AuthManager...")
                guard let authUserId = AuthManager.shared.user?.id else {
                    NSLog("❌ APIManager: NO USER ID FOUND")
                    throw APIError.unauthorized
                }
                userIdToUse = authUserId
            }

            // Backend expects Authorization header with Supabase access token
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(userIdToUse, forHTTPHeaderField: "X-User-ID")
            NSLog("✅ Added Authorization header with Supabase access token")
            NSLog("🔑 DEBUG - Auth Token: %@", accessToken)  // DEBUG: Print token for testing
        }

        if let body = body {
            request.httpBody = body
        }

        NSLog("🌐 Making request to: %@", url.absoluteString)
        NSLog("   Method: %@", method)
        NSLog("   Headers: %@", request.allHTTPHeaderFields ?? [:])

        do {
            let (data, response) = try await urlSession.data(for: request)
            NSLog("📥 Received response, status: %d", (response as? HTTPURLResponse)?.statusCode ?? 0)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(errorMessage)
            }

            let decoded = try decoder.decode(T.self, from: data)
            return decoded
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Authentication Endpoints

    func authenticateWithGoogle(token: String) async throws -> User {
        struct GoogleAuthRequest: Encodable {
            let token: String
        }

        let body = try encoder.encode(GoogleAuthRequest(token: token))
        return try await makeRequest(endpoint: "/auth/google", method: "POST", body: body, requiresAuth: false)
    }

    func authenticateWithApple(identityToken: String, authorizationCode: String) async throws -> User {
        struct AppleAuthRequest: Encodable {
            let identityToken: String
            let authorizationCode: String
        }

        let body = try encoder.encode(AppleAuthRequest(
            identityToken: identityToken,
            authorizationCode: authorizationCode
        ))
        return try await makeRequest(endpoint: "/auth/apple", method: "POST", body: body, requiresAuth: false)
    }

    // MARK: - Onboarding Endpoints

    func createVoiceSession() async throws -> String {
        struct SessionResponse: Decodable {
            let success: Bool
            let sessionId: String
            let clientSecret: String
            let expiresAt: Int?
        }

        let response: SessionResponse = try await makeRequest(
            endpoint: "/onboarding/start",
            method: "POST",
            requiresAuth: true
        )

        return response.clientSecret
    }

    func submitVoiceConversation(userId: String, conversation: String, preferences: [String: Any]? = nil) async throws {
        struct ConversationRequest: Encodable {
            let transcript: String
            let sessionId: String
            let preferences: [String: Any]?

            enum CodingKeys: String, CodingKey {
                case transcript, sessionId, preferences
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(transcript, forKey: .transcript)
                try container.encode(sessionId, forKey: .sessionId)
                if let preferences = preferences {
                    try container.encode(AnyCodable(preferences), forKey: .preferences)
                }
            }
        }

        // Helper to encode [String: Any]
        struct AnyCodable: Encodable {
            let value: Any
            init(_ value: Any) { self.value = value }
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                if let dict = value as? [String: Any] {
                    try container.encode(dict.mapValues { AnyCodable($0) })
                } else if let array = value as? [Any] {
                    try container.encode(array.map { AnyCodable($0) })
                } else if let string = value as? String {
                    try container.encode(string)
                } else {
                    try container.encode("\(value)")
                }
            }
        }

        NSLog("📤 Submitting conversation with preferences: \(String(describing: preferences))")

        // Submit to correct endpoint: /process-transcript
        let body = try encoder.encode(ConversationRequest(
            transcript: conversation,
            sessionId: "direct_websocket",
            preferences: preferences
        ))
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/onboarding/process-transcript",
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }

    func generatePremises() async throws {
        NSLog("🔄 generatePremises() called - starting request")

        struct GenerateResponse: Decodable {
            let success: Bool
            let premises: [Premise]
            let premisesId: String
        }

        do {
            NSLog("📡 Calling makeRequest for /onboarding/generate-premises")
            let response: GenerateResponse = try await makeRequest(
                endpoint: "/onboarding/generate-premises",
                method: "POST",
                requiresAuth: true
            )
            NSLog("✅ Generated \(response.premises.count) premises successfully")
        } catch {
            NSLog("❌ generatePremises() FAILED with error: \(error)")
            NSLog("   Error type: \(type(of: error))")
            NSLog("   Error description: \(error.localizedDescription)")
            throw error
        }
    }

    struct PremisesResult {
        let premises: [Premise]
        let needsNewInterview: Bool
    }

    func getPremises(userId: String) async throws -> PremisesResult {
        let response: PremisesResponse = try await makeRequest(
            endpoint: "/onboarding/premises/\(userId)",
            requiresAuth: true
        )
        return PremisesResult(
            premises: response.premises,
            needsNewInterview: response.needsNewInterview ?? false
        )
    }

    func selectPremise(premiseId: String, userId: String) async throws -> Story {
        struct SelectPremiseRequest: Encodable {
            let premiseId: String
            let userId: String
        }

        let body = try encoder.encode(SelectPremiseRequest(premiseId: premiseId, userId: userId))
        return try await makeRequest(endpoint: "/story/select-premise", method: "POST", body: body)
    }

    func markOnboardingComplete(userId: String) async throws {
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/onboarding/complete",
            method: "POST",
            requiresAuth: true
        )
    }

    // MARK: - Story Endpoints

    func checkGenerationStatus(storyId: String) async throws -> GenerationStatus {
        struct StatusResponse: Decodable {
            let success: Bool
            let storyId: String
            let title: String
            let status: String
            let progress: GenerationProgress?
            let chaptersAvailable: Int
        }

        let response: StatusResponse = try await makeRequest(endpoint: "/story/generation-status/\(storyId)")
        return GenerationStatus(
            storyId: response.storyId,
            title: response.title,
            status: response.status,
            progress: response.progress,
            chaptersAvailable: response.chaptersAvailable
        )
    }

    func getChapters(storyId: String) async throws -> [Chapter] {
        struct ChaptersResponse: Decodable {
            let chapters: [Chapter]
        }

        let response: ChaptersResponse = try await makeRequest(endpoint: "/story/\(storyId)/chapters")
        return response.chapters
    }

    func updateProgress(storyId: String, chapterNumber: Int, scrollPosition: Double) async throws {
        struct ProgressUpdate: Encodable {
            let chapterNumber: Int
            let scrollPosition: Double
        }

        let body = try encoder.encode(ProgressUpdate(
            chapterNumber: chapterNumber,
            scrollPosition: scrollPosition
        ))
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/story/\(storyId)/progress",
            method: "POST",
            body: body
        )
    }

    // MARK: - Library Endpoints

    func getLibrary(userId: String) async throws -> [Story] {
        struct LibraryResponse: Decodable {
            let stories: [Story]
        }

        let response: LibraryResponse = try await makeRequest(
            endpoint: "/library/\(userId)",
            userId: userId  // Pass userId through so makeRequest doesn't re-check
        )
        return response.stories
    }

    // MARK: - Feedback

    func submitFeedback(storyId: String, feedback: String) async throws {
        struct FeedbackRequest: Encodable {
            let storyId: String
            let feedback: String
        }

        let body = try encoder.encode(FeedbackRequest(storyId: storyId, feedback: feedback))
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/feedback",
            method: "POST",
            body: body
        )
    }

    // MARK: - Checkpoint Feedback

    func submitCheckpointFeedback(
        storyId: String,
        checkpoint: String,
        response: String,
        followUpAction: String? = nil,
        voiceTranscript: String? = nil,
        voiceSessionId: String? = nil
    ) async throws -> CheckpointFeedbackResponse {
        struct CheckpointFeedbackRequest: Encodable {
            let storyId: String
            let checkpoint: String
            let response: String
            let followUpAction: String?
            let voiceTranscript: String?
            let voiceSessionId: String?
        }

        let body = try encoder.encode(CheckpointFeedbackRequest(
            storyId: storyId,
            checkpoint: checkpoint,
            response: response,
            followUpAction: followUpAction,
            voiceTranscript: voiceTranscript,
            voiceSessionId: voiceSessionId
        ))

        return try await makeRequest(
            endpoint: "/feedback/checkpoint",
            method: "POST",
            body: body
        )
    }

    func getFeedbackStatus(storyId: String, checkpoint: String) async throws -> FeedbackStatusResponse {
        return try await makeRequest(
            endpoint: "/feedback/status/\(storyId)/\(checkpoint)"
        )
    }

    // MARK: - Completion Interview

    func submitCompletionInterview(
        storyId: String,
        transcript: String,
        sessionId: String? = nil,
        preferences: [String: Any]? = nil
    ) async throws -> CompletionInterviewResponse {
        struct CompletionInterviewRequest: Encodable {
            let storyId: String
            let transcript: String
            let sessionId: String?
            let preferences: [String: Any]?

            enum CodingKeys: String, CodingKey {
                case storyId, transcript, sessionId, preferences
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(storyId, forKey: .storyId)
                try container.encode(transcript, forKey: .transcript)
                try container.encodeIfPresent(sessionId, forKey: .sessionId)
                if let preferences = preferences {
                    try container.encode(AnyCodable(preferences), forKey: .preferences)
                }
            }
        }

        // Helper to encode [String: Any]
        struct AnyCodable: Encodable {
            let value: Any
            init(_ value: Any) { self.value = value }
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                if let dict = value as? [String: Any] {
                    try container.encode(dict.mapValues { AnyCodable($0) })
                } else if let array = value as? [Any] {
                    try container.encode(array.map { AnyCodable($0) })
                } else if let string = value as? String {
                    try container.encode(string)
                } else {
                    try container.encode("\(value)")
                }
            }
        }

        let body = try encoder.encode(CompletionInterviewRequest(
            storyId: storyId,
            transcript: transcript,
            sessionId: sessionId,
            preferences: preferences
        ))

        return try await makeRequest(
            endpoint: "/feedback/completion-interview",
            method: "POST",
            body: body
        )
    }

    // MARK: - Sequel Generation

    func generateSequel(
        storyId: String,
        userPreferences: [String: Any]? = nil
    ) async throws -> SequelGenerationResponse {
        struct SequelRequest: Encodable {
            let userPreferences: [String: Any]?

            enum CodingKeys: String, CodingKey {
                case userPreferences
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                if let preferences = userPreferences {
                    try container.encode(AnyCodable(preferences), forKey: .userPreferences)
                }
            }
        }

        // Helper to encode [String: Any]
        struct AnyCodable: Encodable {
            let value: Any
            init(_ value: Any) { self.value = value }
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                if let dict = value as? [String: Any] {
                    try container.encode(dict.mapValues { AnyCodable($0) })
                } else if let array = value as? [Any] {
                    try container.encode(array.map { AnyCodable($0) })
                } else if let string = value as? String {
                    try container.encode(string)
                } else {
                    try container.encode("\(value)")
                }
            }
        }

        let body = try encoder.encode(SequelRequest(userPreferences: userPreferences))

        return try await makeRequest(
            endpoint: "/story/\(storyId)/generate-sequel",
            method: "POST",
            body: body
        )
    }
}

// Generation status response
struct GenerationStatus {
    let storyId: String
    let title: String
    let status: String
    let progress: GenerationProgress?
    let chaptersAvailable: Int
}

// Empty response for endpoints that don't return data
struct EmptyResponse: Decodable {}

// MARK: - Feedback Response Types

struct CheckpointFeedbackResponse: Decodable {
    let success: Bool
    let feedback: FeedbackData
    let generatingChapters: [Int]

    struct FeedbackData: Decodable {
        let id: String
        let userId: String
        let storyId: String
        let checkpoint: String
        let response: String
        let followUpAction: String?
        let voiceTranscript: String?
        let voiceSessionId: String?
        let createdAt: String

        enum CodingKeys: String, CodingKey {
            case id, checkpoint, response
            case userId = "user_id"
            case storyId = "story_id"
            case followUpAction = "follow_up_action"
            case voiceTranscript = "voice_transcript"
            case voiceSessionId = "voice_session_id"
            case createdAt = "created_at"
        }
    }
}

struct FeedbackStatusResponse: Decodable {
    let success: Bool
    let hasFeedback: Bool
    let feedback: CheckpointFeedbackResponse.FeedbackData?
}

struct CompletionInterviewResponse: Decodable {
    let success: Bool
    let interview: InterviewData

    struct InterviewData: Decodable {
        let id: String
        let userId: String
        let storyId: String
        let seriesId: String?
        let bookNumber: Int
        let transcript: String
        let sessionId: String?
        let preferencesExtracted: [String: AnyCodableValue]?
        let createdAt: String

        enum CodingKeys: String, CodingKey {
            case id, transcript
            case userId = "user_id"
            case storyId = "story_id"
            case seriesId = "series_id"
            case bookNumber = "book_number"
            case sessionId = "session_id"
            case preferencesExtracted = "preferences_extracted"
            case createdAt = "created_at"
        }
    }
}

struct SequelGenerationResponse: Decodable {
    let success: Bool
    let book1: BookInfo
    let book2: BookInfo

    struct BookInfo: Decodable {
        let id: String
        let title: String
        let seriesId: String?
        let bookNumber: Int

        enum CodingKeys: String, CodingKey {
            case id, title
            case seriesId = "series_id"
            case bookNumber = "book_number"
        }
    }
}

// Helper for decoding any JSON value
enum AnyCodableValue: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let array = try? container.decode([AnyCodableValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(dict)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
}
