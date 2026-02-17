//
//  APIManager.swift
//  NeverendingStory
//
//  Railway backend API client
//

import Foundation
import UIKit

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    case ageRequirementNotMet
    case requestFailed(statusCode: Int)
    case queueFull

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
        case .ageRequirementNotMet:
            return "Age requirement not met"
        case .requestFailed(let statusCode):
            return "Request failed with status code \(statusCode)"
        case .unauthorized:
            return "Authentication required. Please log in again."
        case .queueFull:
            return "Report queue is full. Please connect to the internet to submit pending reports."
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

    // MARK: - Bug Reporting - Queue Status

    @Published var isQueueFull: Bool = false

    // MARK: - Bug Reporting - API Call Ring Buffer

    // Ring buffer for last 3 API calls (in-memory only, for bug report context)
    // Using nonisolated(unsafe) because apiCallHistory has its own DispatchQueue for thread safety
    nonisolated(unsafe) private static var apiCallHistory: [(endpoint: String, method: String, statusCode: Int, timestamp: String)] = []
    nonisolated private static let maxHistorySize = 3  // Constant used in async closure
    private static let historyQueue = DispatchQueue(label: "com.neverendingstory.apihistory")

    // Offline queue for failed bug report submissions
    private static var offlineQueue: [PendingBugReport] = []
    private static let maxQueueSize = 10
    private static let maxRetries = 3

    struct PendingBugReport: Codable {
        let id: String
        let reportType: String
        let interviewMode: String
        let transcript: String
        let peggySummary: String
        let category: String
        let severityHint: String?
        let userDescription: String?
        let stepsToReproduce: String?
        let expectedBehavior: String?
        let screenshotBase64: String?
        let metadataJSON: Data  // Store as JSON Data to preserve nested structures
        let retryCount: Int
        let createdAt: Date
    }

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

        // Load offline queue from disk
        Self.loadOfflineQueue()

        // Attempt to drain queue on launch
        Task {
            await Self.drainOfflineQueue()
        }
    }

    // MARK: - Helper Methods

    private func makeRequest<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        requiresAuth: Bool = true,
        userId: String? = nil,  // NEW: Allow passing userId directly
        isRetry: Bool = false   // NEW: Track if this is a retry after token refresh
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

            // Log to ring buffer for bug reports
            Self.logAPICall(endpoint: endpoint, method: method, statusCode: httpResponse.statusCode)

            if httpResponse.statusCode == 401 {
                // If we get 401 and haven't already retried, try refreshing the session
                if !isRetry {
                    NSLog("🔄 Got 401, attempting to refresh session...")
                    await AuthManager.shared.checkSession()

                    // Retry the request with the new token
                    NSLog("🔄 Retrying request with refreshed token...")
                    return try await makeRequest(
                        endpoint: endpoint,
                        method: method,
                        body: body,
                        requiresAuth: requiresAuth,
                        userId: userId,
                        isRetry: true  // Mark as retry to prevent infinite loop
                    )
                }
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

    // MARK: - Bug Reporting Helpers

    /// Log an API call to the ring buffer (for bug report context)
    private static func logAPICall(endpoint: String, method: String, statusCode: Int) {
        historyQueue.async {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let entry = (endpoint: endpoint, method: method, statusCode: statusCode, timestamp: timestamp)

            apiCallHistory.append(entry)

            // Keep only last 3 entries (circular buffer)
            if apiCallHistory.count > maxHistorySize {
                apiCallHistory.removeFirst()
            }
        }
    }

    /// Get recent API calls for bug report metadata
    func getRecentAPICalls() -> [[String: Any]] {
        Self.historyQueue.sync {
            return Self.apiCallHistory.map { entry in
                [
                    "endpoint": entry.endpoint,
                    "method": entry.method,
                    "status_code": entry.statusCode,
                    "timestamp": entry.timestamp
                ]
            }
        }
    }

    /// Load offline queue from UserDefaults
    private static func loadOfflineQueue() {
        guard let data = UserDefaults.standard.data(forKey: "bug_report_offline_queue"),
              let queue = try? JSONDecoder().decode([PendingBugReport].self, from: data) else {
            return
        }
        offlineQueue = queue
        NSLog("🐞 Loaded \(queue.count) pending bug reports from offline queue")
    }

    /// Save offline queue to UserDefaults
    private static func saveOfflineQueue() {
        guard let data = try? JSONEncoder().encode(offlineQueue) else {
            NSLog("⚠️ Failed to encode offline queue")
            return
        }
        UserDefaults.standard.set(data, forKey: "bug_report_offline_queue")
    }

    /// Attempt to drain offline queue (retry failed submissions)
    private static func drainOfflineQueue() async {
        guard !offlineQueue.isEmpty else { return }

        NSLog("🔄 Draining bug report offline queue (\(offlineQueue.count) reports)")

        var remainingReports: [PendingBugReport] = []

        for report in offlineQueue {
            // Skip reports that have exceeded max retries
            if report.retryCount >= maxRetries {
                NSLog("🛑 Bug report \(report.id) exceeded max retries, dropping")
                continue
            }

            // Exponential backoff: wait 2^retryCount seconds since creation
            let backoffSeconds = pow(2.0, Double(report.retryCount))
            let timeSinceCreation = Date().timeIntervalSince(report.createdAt)
            if timeSinceCreation < backoffSeconds {
                // Not ready to retry yet
                remainingReports.append(report)
                continue
            }

            NSLog("🔄 Retrying bug report \(report.id) (attempt \(report.retryCount + 1)/\(maxRetries))")

            do {
                // Deserialize metadata from JSON Data
                let metadata = try JSONSerialization.jsonObject(with: report.metadataJSON, options: []) as? [String: Any] ?? [:]

                // Attempt to submit
                _ = try await APIManager.shared.submitBugReportInternal(
                    reportType: report.reportType,
                    interviewMode: report.interviewMode,
                    transcript: report.transcript,
                    peggySummary: report.peggySummary,
                    category: report.category,
                    severityHint: report.severityHint,
                    userDescription: report.userDescription,
                    stepsToReproduce: report.stepsToReproduce,
                    expectedBehavior: report.expectedBehavior,
                    screenshotBase64: report.screenshotBase64,
                    metadata: metadata
                )

                NSLog("✅ Bug report \(report.id) submitted successfully")
                // Successfully sent, don't add back to queue

            } catch {
                NSLog("⚠️ Retry failed for bug report \(report.id): \(error.localizedDescription)")
                // Increment retry count and keep in queue
                var updatedReport = report
                updatedReport = PendingBugReport(
                    id: report.id,
                    reportType: report.reportType,
                    interviewMode: report.interviewMode,
                    transcript: report.transcript,
                    peggySummary: report.peggySummary,
                    category: report.category,
                    severityHint: report.severityHint,
                    userDescription: report.userDescription,
                    stepsToReproduce: report.stepsToReproduce,
                    expectedBehavior: report.expectedBehavior,
                    screenshotBase64: report.screenshotBase64,
                    metadataJSON: report.metadataJSON,
                    retryCount: report.retryCount + 1,
                    createdAt: report.createdAt
                )
                remainingReports.append(updatedReport)
            }
        }

        offlineQueue = remainingReports
        saveOfflineQueue()
        NSLog("✅ Offline queue drained (\(remainingReports.count) remaining)")

        // Update isQueueFull status on main thread
        DispatchQueue.main.async {
            APIManager.shared.isQueueFull = remainingReports.count >= maxQueueSize
        }
    }

    // MARK: - Bug Reporting

    /// Submit a bug report to the backend
    /// - Parameters:
    ///   - screenshot: Optional screenshot UIImage (will be converted to base64 PNG)
    ///   - metadata: App state metadata captured by BugReportCaptureManager
    /// - Returns: Report ID on success
    func submitBugReport(
        reportType: String,
        interviewMode: String,
        transcript: String,
        peggySummary: String,
        category: String,
        severityHint: String? = nil,
        userDescription: String? = nil,
        stepsToReproduce: String? = nil,
        expectedBehavior: String? = nil,
        screenshot: UIImage? = nil,
        metadata: [String: Any]? = nil
    ) async throws -> String {
        NSLog("🐞 Submitting bug report (type: \(reportType), mode: \(interviewMode))")

        // Convert screenshot to base64 PNG if provided
        var screenshotBase64: String? = nil
        if let screenshot = screenshot,
           let pngData = screenshot.pngData() {
            screenshotBase64 = "data:image/png;base64," + pngData.base64EncodedString()
        }

        do {
            let reportId = try await submitBugReportInternal(
                reportType: reportType,
                interviewMode: interviewMode,
                transcript: transcript,
                peggySummary: peggySummary,
                category: category,
                severityHint: severityHint,
                userDescription: userDescription,
                stepsToReproduce: stepsToReproduce,
                expectedBehavior: expectedBehavior,
                screenshotBase64: screenshotBase64,
                metadata: metadata ?? [:]
            )
            NSLog("✅ Bug report submitted successfully: \(reportId)")
            return reportId

        } catch {
            NSLog("⚠️ Bug report submission failed, adding to offline queue: \(error.localizedDescription)")

            // Serialize metadata to JSON Data for storage
            let metadataJSON: Data
            if let metadata = metadata {
                metadataJSON = try JSONSerialization.data(withJSONObject: metadata, options: [])
            } else {
                metadataJSON = try JSONSerialization.data(withJSONObject: [:], options: [])
            }

            // Check if queue is full
            let queueFull = Self.historyQueue.sync {
                return Self.offlineQueue.count >= Self.maxQueueSize
            }

            if queueFull {
                // Queue is at capacity - throw error instead of dropping old reports
                NSLog("🛑 Offline queue is full (\(Self.maxQueueSize) reports)")
                DispatchQueue.main.async {
                    self.isQueueFull = true
                }
                throw APIError.queueFull
            }

            // Add to offline queue for retry
            let pendingReport = PendingBugReport(
                id: UUID().uuidString,
                reportType: reportType,
                interviewMode: interviewMode,
                transcript: transcript,
                peggySummary: peggySummary,
                category: category,
                severityHint: severityHint,
                userDescription: userDescription,
                stepsToReproduce: stepsToReproduce,
                expectedBehavior: expectedBehavior,
                screenshotBase64: screenshotBase64,
                metadataJSON: metadataJSON,
                retryCount: 0,
                createdAt: Date()
            )

            Self.historyQueue.sync {
                Self.offlineQueue.append(pendingReport)
                Self.saveOfflineQueue()
                DispatchQueue.main.async {
                    self.isQueueFull = Self.offlineQueue.count >= Self.maxQueueSize
                }
            }

            throw error
        }
    }

    /// Internal method to actually submit the bug report to the API
    private func submitBugReportInternal(
        reportType: String,
        interviewMode: String,
        transcript: String,
        peggySummary: String,
        category: String,
        severityHint: String?,
        userDescription: String?,
        stepsToReproduce: String?,
        expectedBehavior: String?,
        screenshotBase64: String?,
        metadata: [String: Any]
    ) async throws -> String {
        struct BugReportRequest: Encodable {
            let report_type: String
            let interview_mode: String
            let transcript: String
            let peggy_summary: String
            let category: String
            let severity_hint: String?
            let user_description: String?
            let steps_to_reproduce: String?
            let expected_behavior: String?
            let screenshot: String?
            let metadata: [String: AnyCodableValue]

            enum CodingKeys: String, CodingKey {
                case report_type, interview_mode, transcript, peggy_summary, category
                case severity_hint, user_description, steps_to_reproduce, expected_behavior
                case screenshot, metadata
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(report_type, forKey: .report_type)
                try container.encode(interview_mode, forKey: .interview_mode)
                try container.encode(transcript, forKey: .transcript)
                try container.encode(peggy_summary, forKey: .peggy_summary)
                try container.encode(category, forKey: .category)
                try container.encodeIfPresent(severity_hint, forKey: .severity_hint)
                try container.encodeIfPresent(user_description, forKey: .user_description)
                try container.encodeIfPresent(steps_to_reproduce, forKey: .steps_to_reproduce)
                try container.encodeIfPresent(expected_behavior, forKey: .expected_behavior)
                try container.encodeIfPresent(screenshot, forKey: .screenshot)
                try container.encode(metadata, forKey: .metadata)
            }
        }

        struct BugReportResponse: Decodable {
            let success: Bool
            let reportId: String
        }

        // Convert [String: Any] to [String: AnyCodableValue] for encoding
        let encodableMetadata = metadata.mapValues { AnyCodableValue(value: $0) }

        let body = try encoder.encode(BugReportRequest(
            report_type: reportType,
            interview_mode: interviewMode,
            transcript: transcript,
            peggy_summary: peggySummary,
            category: category,
            severity_hint: severityHint,
            user_description: userDescription,
            steps_to_reproduce: stepsToReproduce,
            expected_behavior: expectedBehavior,
            screenshot: screenshotBase64,
            metadata: encodableMetadata
        ))

        let response: BugReportResponse = try await makeRequest(
            endpoint: "/bug-reports",
            method: "POST",
            body: body,
            requiresAuth: true
        )

        return response.reportId
    }

    /// Get recent bug report status updates for the authenticated user
    /// - Parameter since: ISO8601 timestamp to fetch updates after
    /// - Returns: Array of bug report updates with status changes
    func getBugReportUpdates(since: String) async throws -> [BugReportNotificationManager.BugReportUpdate] {
        struct UpdatesResponse: Decodable {
            let updates: [BugReportNotificationManager.BugReportUpdate]
        }

        // URL encode the since parameter
        guard let encodedSince = since.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw APIError.invalidURL
        }

        let response: UpdatesResponse = try await makeRequest(
            endpoint: "/bug-reports/updates?since=\(encodedSince)",
            method: "GET",
            requiresAuth: true
        )

        return response.updates
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

    func getSystemPrompt(interviewType: String, medium: String, context: [String: Any]?) async throws -> (prompt: String, greeting: String) {
        struct SystemPromptRequest: Encodable {
            let interviewType: String
            let medium: String
            let context: [String: Any]?

            enum CodingKeys: String, CodingKey {
                case interviewType, medium, context
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(interviewType, forKey: .interviewType)
                try container.encode(medium, forKey: .medium)
                if let context = context {
                    try container.encode(AnyCodable(context), forKey: .context)
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

        struct SystemPromptResponse: Decodable {
            let success: Bool
            let prompt: String
            let greeting: String
        }

        NSLog("📤 Fetching system prompt for \(interviewType) (\(medium))")

        let body = try encoder.encode(SystemPromptRequest(
            interviewType: interviewType,
            medium: medium,
            context: context
        ))

        let response: SystemPromptResponse = try await makeRequest(
            endpoint: "/chat/system-prompt",
            method: "POST",
            body: body,
            requiresAuth: true
        )

        NSLog("✅ System prompt fetched successfully")
        return (prompt: response.prompt, greeting: response.greeting)
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

    func submitNewStoryRequest(userId: String, transcript: String, storyRequest: [String: Any]?) async throws {
        NSLog("📤 Submitting new story request for returning user")

        struct NewStoryRequest: Encodable {
            let transcript: String
            let sessionId: String
            let storyRequest: [String: Any]?

            enum CodingKeys: String, CodingKey {
                case transcript, sessionId, storyRequest
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(transcript, forKey: .transcript)
                try container.encode(sessionId, forKey: .sessionId)
                if let storyRequest = storyRequest {
                    try container.encode(AnyCodable(storyRequest), forKey: .storyRequest)
                }
            }

            // Use the same AnyCodable from submitVoiceConversation
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
        }

        let body = try encoder.encode(NewStoryRequest(
            transcript: transcript,
            sessionId: "direct_websocket",
            storyRequest: storyRequest
        ))

        let _: EmptyResponse = try await makeRequest(
            endpoint: "/onboarding/new-story-request",
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }

    func getUserPreferences(userId: String) async throws -> [String: Any]? {
        struct PreferencesResponse: Decodable {
            let success: Bool
            let preferences: [String: AnyCodableValue]?

            struct AnyCodableValue: Decodable {
                let value: Any

                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if let string = try? container.decode(String.self) {
                        value = string
                    } else if let int = try? container.decode(Int.self) {
                        value = int
                    } else if let double = try? container.decode(Double.self) {
                        value = double
                    } else if let bool = try? container.decode(Bool.self) {
                        value = bool
                    } else if let array = try? container.decode([AnyCodableValue].self) {
                        value = array.map { $0.value }
                    } else {
                        value = ""
                    }
                }
            }
        }

        do {
            let response: PreferencesResponse = try await makeRequest(
                endpoint: "/onboarding/user-preferences/\(userId)",
                method: "GET",
                requiresAuth: true
            )

            // Convert AnyCodableValue back to [String: Any]
            if let prefs = response.preferences {
                var result: [String: Any] = [:]
                for (key, wrapper) in prefs {
                    result[key] = wrapper.value
                }
                return result
            }
            return nil
        } catch {
            NSLog("⚠️ Failed to fetch user preferences: \(error)")
            return nil
        }
    }

    func saveDOB(birthMonth: Int, birthYear: Int) async throws {
        struct SaveDOBRequest: Encodable {
            let birthMonth: Int
            let birthYear: Int
        }

        struct SaveDOBResponse: Decodable {
            let success: Bool
            let age: Int?
            let is_minor: Bool?
        }

        let body = try encoder.encode(SaveDOBRequest(birthMonth: birthMonth, birthYear: birthYear))
        let _: SaveDOBResponse = try await makeRequest(
            endpoint: "/onboarding/save-dob",
            method: "POST",
            body: body
        )
    }

    func updateIsMinor(userId: String, isMinor: Bool) async throws {
        struct UpdateIsMinorRequest: Encodable {
            let isMinor: Bool
        }

        let body = try encoder.encode(UpdateIsMinorRequest(isMinor: isMinor))
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/settings/update-is-minor",
            method: "POST",
            body: body
        )
    }

    func getCompletionContext(storyId: String) async throws -> [String: Any]? {
        struct CompletionContextResponse: Decodable {
            let success: Bool
            let story: StoryInfo
            let bible: BibleInfo
            let readingBehavior: ReadingBehavior
            let checkpointFeedback: [CheckpointFeedback]

            struct StoryInfo: Decodable {
                let title: String
                let genre: String?
                let premiseTier: String?
            }

            struct BibleInfo: Decodable {
                let protagonistName: String?
                let supportingCast: [String]
                let centralConflict: String
                let themes: [String]
                let keyLocations: [String]
            }

            struct ReadingBehavior: Decodable {
                let totalReadingMinutes: Int
                let lingeredChapters: [LingeredChapter]
                let skimmedChapters: [Int]
                let rereadChapters: [RereadChapter]

                struct LingeredChapter: Decodable {
                    let chapter: Int
                    let minutes: Int
                }

                struct RereadChapter: Decodable {
                    let chapter: Int
                    let sessions: Int
                }
            }

            struct CheckpointFeedback: Decodable {
                let checkpoint: String
                let response: String
                let action: String?
            }
        }

        do {
            let response: CompletionContextResponse = try await makeRequest(
                endpoint: "/feedback/completion-context/\(storyId)",
                method: "GET",
                requiresAuth: true
            )

            // Convert to dictionary for easier consumption
            return [
                "story": [
                    "title": response.story.title,
                    "genre": response.story.genre ?? "",
                    "premiseTier": response.story.premiseTier ?? ""
                ],
                "bible": [
                    "protagonistName": response.bible.protagonistName ?? "",
                    "supportingCast": response.bible.supportingCast,
                    "centralConflict": response.bible.centralConflict,
                    "themes": response.bible.themes,
                    "keyLocations": response.bible.keyLocations
                ],
                "readingBehavior": [
                    "totalReadingMinutes": response.readingBehavior.totalReadingMinutes,
                    "lingeredChapters": response.readingBehavior.lingeredChapters.map { ["chapter": $0.chapter, "minutes": $0.minutes] },
                    "skimmedChapters": response.readingBehavior.skimmedChapters,
                    "rereadChapters": response.readingBehavior.rereadChapters.map { ["chapter": $0.chapter, "sessions": $0.sessions] }
                ],
                "checkpointFeedback": response.checkpointFeedback.map {
                    ["checkpoint": $0.checkpoint, "response": $0.response, "action": $0.action ?? ""]
                }
            ]
        } catch {
            NSLog("⚠️ Failed to fetch completion context: \(error)")
            return nil
        }
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

    func getPremises(userId: String) async throws -> PremisesResult {
        let response: PremisesResponse = try await makeRequest(
            endpoint: "/onboarding/premises/\(userId)",
            requiresAuth: true
        )
        return PremisesResult(
            premises: response.premises,
            needsNewInterview: response.needsNewInterview ?? false,
            premisesId: response.premisesId
        )
    }

    func discardPremises(premisesId: String) async throws {
        struct DiscardPremisesRequest: Encodable {
            let premisesId: String
        }

        let body = try encoder.encode(DiscardPremisesRequest(premisesId: premisesId))
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/onboarding/discard-premises",
            method: "POST",
            body: body,
            requiresAuth: true
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

    func confirmName(_ name: String) async throws -> Bool {
        struct ConfirmNameRequest: Encodable {
            let name: String
        }

        struct ConfirmNameResponse: Decodable {
            let success: Bool
            let name: String
        }

        let body = try encoder.encode(ConfirmNameRequest(name: name))
        let response: ConfirmNameResponse = try await makeRequest(
            endpoint: "/onboarding/confirm-name",
            method: "POST",
            body: body,
            requiresAuth: true
        )

        return response.success
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

    func getCurrentState(storyId: String) async throws -> CurrentStateResponse {
        struct ReadingProgress: Decodable {
            let chapterNumber: Int
            let scrollPosition: Double
            let updatedAt: String

            enum CodingKeys: String, CodingKey {
                case chapterNumber = "chapter_number"
                case scrollPosition = "scroll_position"
                case updatedAt = "updated_at"
            }
        }

        struct StateResponse: Decodable {
            let success: Bool
            let story: Story
            let progress: ReadingProgress?
            let chaptersAvailable: Int
        }

        let response: StateResponse = try await makeRequest(endpoint: "/story/\(storyId)/current-state")

        return CurrentStateResponse(
            story: response.story,
            chapterNumber: response.progress?.chapterNumber,
            scrollPosition: response.progress?.scrollPosition,
            chaptersAvailable: response.chaptersAvailable
        )
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

    // MARK: - Reading Analytics

    func startReadingSession(storyId: String, chapterNumber: Int) async throws -> String {
        struct SessionStartRequest: Encodable {
            let storyId: String
            let chapterNumber: Int
        }

        struct SessionStartResponse: Decodable {
            let sessionId: String
        }

        let body = try encoder.encode(SessionStartRequest(
            storyId: storyId,
            chapterNumber: chapterNumber
        ))
        let response: SessionStartResponse = try await makeRequest(
            endpoint: "/analytics/session/start",
            method: "POST",
            body: body
        )
        return response.sessionId
    }

    func sendReadingHeartbeat(sessionId: String, scrollProgress: Double) async throws {
        struct HeartbeatRequest: Encodable {
            let sessionId: String
            let scrollProgress: Double
        }

        let body = try encoder.encode(HeartbeatRequest(
            sessionId: sessionId,
            scrollProgress: scrollProgress
        ))
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/analytics/session/heartbeat",
            method: "POST",
            body: body
        )
    }

    func endReadingSession(sessionId: String, scrollProgress: Double) async throws {
        struct SessionEndRequest: Encodable {
            let sessionId: String
            let scrollProgress: Double
        }

        let body = try encoder.encode(SessionEndRequest(
            sessionId: sessionId,
            scrollProgress: scrollProgress
        ))
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/analytics/session/end",
            method: "POST",
            body: body
        )
    }

    // MARK: - Consent Management

    func grantAIConsent() async throws {
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/settings/ai-consent",
            method: "POST"
        )
    }

    func grantVoiceConsent() async throws {
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/settings/voice-consent",
            method: "POST"
        )
    }

    func revokeVoiceConsent() async throws {
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/settings/revoke-voice-consent",
            method: "POST"
        )
    }

    func getConsentStatus() async throws -> ConsentStatus {
        struct ConsentStatusResponse: Decodable {
            let success: Bool
            let aiConsent: Bool
            let voiceConsent: Bool

            enum CodingKeys: String, CodingKey {
                case success
                case aiConsent = "ai_consent"
                case voiceConsent = "voice_consent"
            }
        }

        let response: ConsentStatusResponse = try await makeRequest(
            endpoint: "/settings/consent-status",
            method: "GET"
        )

        return ConsentStatus(aiConsent: response.aiConsent, voiceConsent: response.voiceConsent)
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

    // Adaptive Reading Engine: Submit dimension-based checkpoint feedback
    func submitCheckpointFeedbackWithDimensions(
        storyId: String,
        checkpoint: String,
        pacing: String,
        tone: String,
        character: String,
        protagonistName: String
    ) async throws -> CheckpointFeedbackResponse {
        struct DimensionFeedbackRequest: Encodable {
            let storyId: String
            let checkpoint: String
            let pacing: String
            let tone: String
            let character: String
            let protagonistName: String
        }

        let body = try encoder.encode(DimensionFeedbackRequest(
            storyId: storyId,
            checkpoint: checkpoint,
            pacing: pacing,
            tone: tone,
            character: character,
            protagonistName: protagonistName
        ))

        return try await makeRequest(
            endpoint: "/feedback/checkpoint",
            method: "POST",
            body: body
        )
    }

    // Check if a specific chapter is available for reading
    func checkChapterAvailability(storyId: String, chapterNumber: Int) async throws -> Bool {
        do {
            let chapters = try await getChapters(storyId: storyId)
            return chapters.contains(where: { $0.chapterNumber == chapterNumber })
        } catch {
            // If we can't fetch chapters, assume not available
            return false
        }
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

    // MARK: - Text Chat with Prospero

    /// Start a new text chat session with Prospero
    /// - Parameters:
    ///   - interviewType: Type of interview ('onboarding', 'returning_user', 'book_completion')
    ///   - context: Optional context for returning_user or book_completion
    /// - Returns: Session ID and Prospero's opening message
    func startChatSession(interviewType: String, context: [String: Any]?) async throws -> (sessionId: String, openingMessage: String) {
        NSLog("📝 APIManager: Starting text chat session (\(interviewType))")

        struct StartChatRequest: Encodable {
            let interviewType: String
            let context: [String: Any]?

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(interviewType, forKey: .interviewType)
                if let ctx = context {
                    try container.encode(AnyCodable(ctx), forKey: .context)
                }
            }

            enum CodingKeys: String, CodingKey {
                case interviewType, context
            }
        }

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
                } else if let int = value as? Int {
                    try container.encode(int)
                } else if let bool = value as? Bool {
                    try container.encode(bool)
                } else {
                    try container.encode("\(value)")
                }
            }
        }

        struct StartChatResponse: Decodable {
            let success: Bool
            let sessionId: String
            let openingMessage: String
        }

        let body = try encoder.encode(StartChatRequest(interviewType: interviewType, context: context))

        let response: StartChatResponse = try await makeRequest(
            endpoint: "/chat/start",
            method: "POST",
            body: body
        )

        NSLog("✅ APIManager: Text chat session started (\(response.sessionId))")
        return (sessionId: response.sessionId, openingMessage: response.openingMessage)
    }

    /// Send a message in an existing text chat session
    /// - Parameters:
    ///   - sessionId: The session ID
    ///   - message: The user's message
    /// - Returns: Prospero's response, tool call (if any), and completion status
    func sendChatMessage(sessionId: String, message: String) async throws -> (message: String, toolCall: ChatToolCall?, sessionComplete: Bool) {
        NSLog("💬 APIManager: Sending chat message to session \(sessionId)")

        struct SendMessageRequest: Encodable {
            let sessionId: String
            let message: String
        }

        struct SendMessageResponse: Decodable {
            let success: Bool
            let message: String
            let toolCall: ChatToolCall?
            let sessionComplete: Bool
        }

        let body = try encoder.encode(SendMessageRequest(sessionId: sessionId, message: message))

        let response: SendMessageResponse = try await makeRequest(
            endpoint: "/chat/send",
            method: "POST",
            body: body
        )

        NSLog("✅ APIManager: Received response (complete: \(response.sessionComplete))")
        return (message: response.message, toolCall: response.toolCall, sessionComplete: response.sessionComplete)
    }

    /// Get an existing chat session (for resuming)
    /// - Parameter sessionId: The session ID
    /// - Returns: Full session data
    func getChatSession(sessionId: String) async throws -> [String: Any] {
        NSLog("📖 APIManager: Fetching chat session \(sessionId)")

        struct GetSessionResponse: Decodable {
            let success: Bool
            let session: [String: AnyCodableValue]
        }

        let response: GetSessionResponse = try await makeRequest(
            endpoint: "/chat/session/\(sessionId)",
            method: "GET"
        )

        let session = response.session.mapValues { $0.toAny() }
        NSLog("✅ APIManager: Session fetched")
        return session
    }
}

// Chat tool call response type
struct ChatToolCall: Decodable {
    let name: String
    let arguments: [String: Any]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)

        // Decode arguments as [String: Any]
        let argsContainer = try container.decode([String: AnyCodableValue].self, forKey: .arguments)
        arguments = argsContainer.mapValues { $0.toAny() }
    }

    enum CodingKeys: String, CodingKey {
        case name, arguments
    }
}

// Extension to convert AnyCodableValue to Any
extension AnyCodableValue {
    func toAny() -> Any {
        switch self {
        case .string(let str): return str
        case .int(let int): return int
        case .double(let double): return double
        case .bool(let bool): return bool
        case .array(let array): return array.map { $0.toAny() }
        case .dictionary(let dict): return dict.mapValues { $0.toAny() }
        case .null: return NSNull()
        }
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

// MARK: - Current State Response

struct CurrentStateResponse {
    let story: Story
    let chapterNumber: Int?
    let scrollPosition: Double?
    let chaptersAvailable: Int
}

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

// Consent status model
struct ConsentStatus {
    let aiConsent: Bool
    let voiceConsent: Bool
}

// Helper for encoding and decoding any JSON value
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null

    init(value: Any) {
        if let string = value as? String {
            self = .string(string)
        } else if let int = value as? Int {
            self = .int(int)
        } else if let double = value as? Double {
            self = .double(double)
        } else if let bool = value as? Bool {
            self = .bool(bool)
        } else if let array = value as? [Any] {
            self = .array(array.map { AnyCodableValue(value: $0) })
        } else if let dict = value as? [String: Any] {
            self = .dictionary(dict.mapValues { AnyCodableValue(value: $0) })
        } else {
            self = .null
        }
    }

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

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        case .bool(let bool):
            try container.encode(bool)
        case .array(let array):
            try container.encode(array)
        case .dictionary(let dict):
            try container.encode(dict)
        case .null:
            try container.encodeNil()
        }
    }
}
