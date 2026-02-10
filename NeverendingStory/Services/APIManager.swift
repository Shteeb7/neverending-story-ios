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

    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
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
        }

        if let body = body {
            request.httpBody = body
        }

        NSLog("🌐 Making request to: %@", url.absoluteString)
        NSLog("   Method: %@", method)
        NSLog("   Headers: %@", request.allHTTPHeaderFields ?? [:])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
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

    func submitVoiceConversation(userId: String, conversation: String) async throws {
        struct ConversationRequest: Encodable {
            let userId: String
            let conversation: String
        }

        let body = try encoder.encode(ConversationRequest(userId: userId, conversation: conversation))
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/onboarding/voice-conversation",
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }

    func getPremises(userId: String) async throws -> [Premise] {
        let response: PremisesResponse = try await makeRequest(
            endpoint: "/onboarding/premises/\(userId)",
            requiresAuth: true
        )
        return response.premises
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
}

// Empty response for endpoints that don't return data
struct EmptyResponse: Decodable {}
