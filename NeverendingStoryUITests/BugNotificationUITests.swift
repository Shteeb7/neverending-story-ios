import XCTest

final class BugNotificationUITests: XCTestCase {
    var app: XCUIApplication!
    var testEmail: String!
    var testPassword: String!
    var testUserId: String?
    var testBugReportId: String?

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Generate unique test account credentials
        let timestamp = Int(Date().timeIntervalSince1970)
        testEmail = "test-bug-notif-\(timestamp)@mythweaver.app"
        testPassword = "TestPassword123!"

        // Create test user and seed data synchronously (~10 seconds for API calls + Edge Function)
        let setupExpectation = XCTestExpectation(description: "Setup complete")
        Task {
            await setupTestUserWithBugReport()
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 20.0)

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        // Clean up test data
        let expectation = XCTestExpectation(description: "Cleanup complete")
        Task {
            await cleanupTestData()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        app.terminate()
        app = nil
    }

    // MARK: - Tests

    func testLoginReachesLibraryView() throws {
        loginWithTestAccount()

        // Give extra time for all routing to complete
        sleep(5)

        // Log visible elements again after wait
        logVisibleElements()

        // Check for Library elements
        let newStoryButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'New Story' OR label CONTAINS 'new story'")).firstMatch
        let libraryTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Library' OR label CONTAINS 'My Library'")).firstMatch

        let reachedLibrary = newStoryButton.waitForExistence(timeout: 10) || libraryTitle.exists

        // Take screenshot regardless for debugging
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Print all visible elements for debugging
        NSLog("📸 Visible static texts: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
        NSLog("📸 Visible buttons: \(app.buttons.allElementsBoundByIndex.map { $0.label })")

        XCTAssertTrue(reachedLibrary, "Should reach LibraryView after login")
    }

    // Banner tests removed — banner replaced with inline "Recently Squashed" section in BugReportView (Phase 4A v1.4)

    // MARK: - Helper Methods

    private func logVisibleElements() {
        let texts = app.staticTexts.allElementsBoundByIndex.prefix(20).map { $0.label }
        let buttons = app.buttons.allElementsBoundByIndex.prefix(20).map { $0.label }
        let navBars = app.navigationBars.allElementsBoundByIndex.map { $0.identifier }
        let logContent = """
        === VISIBLE ELEMENTS ===
        Texts: \(texts)
        Buttons: \(buttons)
        Navigation bars: \(navBars)
        ========================
        """
        try? logContent.write(toFile: "/tmp/xcuitest_elements.log", atomically: true, encoding: .utf8)
        NSLog("📸 Logged visible elements to /tmp/xcuitest_elements.log")
    }

    private func makeAPICall(_ request: URLRequest, description: String) async -> (Data, Int) {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? "no body"

            // Log to file
            let logEntry = """

            === \(description) ===
            Status: \(statusCode)
            Response: \(body.prefix(500))
            ========================

            """
            if let existing = try? String(contentsOfFile: "/tmp/xcuitest_api.log", encoding: .utf8) {
                try? (existing + logEntry).write(toFile: "/tmp/xcuitest_api.log", atomically: true, encoding: .utf8)
            } else {
                try? logEntry.write(toFile: "/tmp/xcuitest_api.log", atomically: true, encoding: .utf8)
            }

            if statusCode >= 200 && statusCode < 300 {
                NSLog("✅ \(description) (HTTP \(statusCode))")
            } else {
                NSLog("❌ \(description) FAILED (HTTP \(statusCode)): \(body.prefix(200))")
            }
            return (data, statusCode)
        } catch {
            NSLog("❌ \(description) NETWORK ERROR: \(error)")
            try? "❌ \(description) NETWORK ERROR: \(error)\n".write(toFile: "/tmp/xcuitest_api.log", atomically: false, encoding: .utf8)
            return (Data(), 0)
        }
    }

    private func loginWithTestAccount() {
        // Wait for login screen
        sleep(3)
        let emailField = app.textFields.element(boundBy: 0)
        XCTAssertTrue(emailField.waitForExistence(timeout: 30), "Email field should exist")

        emailField.tap()
        emailField.typeText(testEmail)

        let passwordField = app.secureTextFields.element(boundBy: 0)
        passwordField.tap()
        passwordField.typeText(testPassword)

        // Tap sign in button
        let loginButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign In'")).firstMatch
        XCTAssertTrue(loginButton.exists, "Sign In button should exist")
        loginButton.tap()

        // Wait for authentication + routing
        sleep(8)

        // Handle consent screen if it appears (Railway API may fail or return stale data)
        // AIConsentView has a button with text containing "I Agree" or "Begin My Journey"
        let consentButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Agree' OR label CONTAINS 'Begin'")).firstMatch
        if consentButton.waitForExistence(timeout: 3) {
            NSLog("⚠️ Consent screen appeared — tapping through")
            consentButton.tap()
            sleep(3) // Wait for navigation after consent
        }

        // Handle Dedication screen if it appears (first-time user, AppStorage flag not set)
        // DedicationView requires a tap to continue
        let dedicationContinue = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Continue' OR label CONTAINS 'Begin'")).firstMatch
        if dedicationContinue.waitForExistence(timeout: 2) {
            NSLog("⚠️ Dedication screen appeared — tapping through")
            dedicationContinue.tap()
            sleep(2)
        }

        // Handle "Your Library" button on OnboardingView (appears when user has completed onboarding)
        let libraryButton = app.buttons["Your Library"]
        if libraryButton.waitForExistence(timeout: 3) {
            NSLog("⚠️ 'Your Library' button appeared — tapping to navigate")
            libraryButton.tap()
            sleep(2)
        }

        // Log what's visible after login
        logVisibleElements()
    }

    /// Creates test user via Supabase signup API, seeds preferences, and seeds a bug report
    private func setupTestUserWithBugReport() async {
        let serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzenV1dmtmZ2RmcWd0YXljb2p6Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MDY3MDY0NSwiZXhwIjoyMDg2MjQ2NjQ1fQ.Ad7SLNXk-39z0ogwi7IB73e0kZSuRwRCfmWwcJMmeIs"
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzenV1dmtmZ2RmcWd0YXljb2p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2NzA2NDUsImV4cCI6MjA4NjI0NjY0NX0.YvjON4hgMTt081xM_ZjqVqNRd9q_LXUdMCbBDeprRUU"

        // 1. Create test user via signup API
        let signupURL = URL(string: "https://hszuuvkfgdfqgtaycojz.supabase.co/auth/v1/signup")!
        var signupRequest = URLRequest(url: signupURL)
        signupRequest.httpMethod = "POST"
        signupRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        signupRequest.setValue(anonKey, forHTTPHeaderField: "apikey")

        let signupBody: [String: Any] = [
            "email": testEmail!,
            "password": testPassword!
        ]
        signupRequest.httpBody = try? JSONSerialization.data(withJSONObject: signupBody)

        let (signupData, signupStatus) = await makeAPICall(signupRequest, description: "Create user via signup")
        guard signupStatus >= 200 && signupStatus < 300 else { return }

        if let json = try? JSONSerialization.jsonObject(with: signupData) as? [String: Any],
           let user = json["user"] as? [String: Any],
           let userId = user["id"] as? String {
            self.testUserId = userId
        } else {
            NSLog("❌ Failed to parse user ID from signup response")
            return
        }

        guard let userId = testUserId else { return }

        // 2. Update user metadata with has_completed_onboarding=true
        let metadataURL = URL(string: "https://hszuuvkfgdfqgtaycojz.supabase.co/auth/v1/admin/users/\(userId)")!
        var metadataRequest = URLRequest(url: metadataURL)
        metadataRequest.httpMethod = "PUT"
        metadataRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        metadataRequest.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        metadataRequest.setValue(anonKey, forHTTPHeaderField: "apikey")

        let metadataBody: [String: Any] = [
            "user_metadata": [
                "has_completed_onboarding": true
            ]
        ]
        metadataRequest.httpBody = try? JSONSerialization.data(withJSONObject: metadataBody)

        let (_, metadataStatus) = await makeAPICall(metadataRequest, description: "Update user metadata")
        guard metadataStatus >= 200 && metadataStatus < 300 else { return }

        // 3. Seed user preferences (correct columns only)
        let prefsURL = URL(string: "https://hszuuvkfgdfqgtaycojz.supabase.co/rest/v1/user_preferences")!
        var prefsRequest = URLRequest(url: prefsURL)
        prefsRequest.httpMethod = "POST"
        prefsRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        prefsRequest.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        prefsRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
        prefsRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let prefsBody: [String: Any] = [
            "user_id": userId,
            "ai_consent": true,
            "voice_consent": false,
            "birth_year": 1995,
            "birth_month": 6,
            "is_minor": false
        ]
        prefsRequest.httpBody = try? JSONSerialization.data(withJSONObject: prefsBody)

        let (_, prefsStatus) = await makeAPICall(prefsRequest, description: "Seed user preferences")
        guard prefsStatus >= 200 && prefsStatus < 300 else { return }

        // 4. Seed bug report with status='fixed'
        let bugReportURL = URL(string: "https://hszuuvkfgdfqgtaycojz.supabase.co/rest/v1/bug_reports")!
        var bugReportRequest = URLRequest(url: bugReportURL)
        bugReportRequest.httpMethod = "POST"
        bugReportRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        bugReportRequest.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        bugReportRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
        bugReportRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let reportId = UUID().uuidString
        let bugReportBody: [String: Any] = [
            "id": reportId,
            "user_id": userId,
            "report_type": "bug",
            "interview_mode": "text",
            "peggy_summary": "Test bug report for notification UI test",
            "category": "reading",
            "severity_hint": "annoying",
            "user_description": "This is a test bug report",
            "transcript": "Test transcript",
            "status": "fixed",
            "ai_priority": "P2",
            "reviewed_at": ISO8601DateFormatter().string(from: Date()),
            "metadata": [:]
        ]
        bugReportRequest.httpBody = try? JSONSerialization.data(withJSONObject: bugReportBody)

        let (bugData, bugStatus) = await makeAPICall(bugReportRequest, description: "Seed bug report")
        guard bugStatus >= 200 && bugStatus < 300 else { return }

        if let json = try? JSONSerialization.jsonObject(with: bugData) as? [[String: Any]],
           let report = json.first,
           let id = report["id"] as? String {
            self.testBugReportId = id
        }

        guard let _ = testBugReportId else { return }

        // 5. Done — trigger skips Edge Function for reviewed statuses, so 'fixed' stays 'fixed'
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second for DB consistency
        NSLog("✅ Setup complete — bug report status is 'fixed' (Edge Function skipped)")
    }

    /// Cleans up test user and all related data
    private func cleanupTestData() async {
        guard let userId = testUserId else { return }

        let serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzenV1dmtmZ2RmcWd0YXljb2p6Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MDY3MDY0NSwiZXhwIjoyMDg2MjQ2NjQ1fQ.Ad7SLNXk-39z0ogwi7IB73e0kZSuRwRCfmWwcJMmeIs"
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzenV1dmtmZ2RmcWd0YXljb2p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2NzA2NDUsImV4cCI6MjA4NjI0NjY0NX0.YvjON4hgMTt081xM_ZjqVqNRd9q_LXUdMCbBDeprRUU"

        // Delete bug report
        if let reportId = testBugReportId {
            let reportURL = URL(string: "https://hszuuvkfgdfqgtaycojz.supabase.co/rest/v1/bug_reports?id=eq.\(reportId)")!
            var reportRequest = URLRequest(url: reportURL)
            reportRequest.httpMethod = "DELETE"
            reportRequest.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
            reportRequest.setValue(anonKey, forHTTPHeaderField: "apikey")

            let (_, _) = await makeAPICall(reportRequest, description: "Delete bug report")
        }

        // Delete user preferences
        let prefsURL = URL(string: "https://hszuuvkfgdfqgtaycojz.supabase.co/rest/v1/user_preferences?user_id=eq.\(userId)")!
        var prefsRequest = URLRequest(url: prefsURL)
        prefsRequest.httpMethod = "DELETE"
        prefsRequest.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        prefsRequest.setValue(anonKey, forHTTPHeaderField: "apikey")

        let (_, _) = await makeAPICall(prefsRequest, description: "Delete user preferences")

        // Delete auth user (cascades to other tables)
        let authURL = URL(string: "https://hszuuvkfgdfqgtaycojz.supabase.co/auth/v1/admin/users/\(userId)")!
        var authRequest = URLRequest(url: authURL)
        authRequest.httpMethod = "DELETE"
        authRequest.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        authRequest.setValue(anonKey, forHTTPHeaderField: "apikey")

        let (_, _) = await makeAPICall(authRequest, description: "Delete auth user")
    }
}
