import XCTest

final class VoiceConsentReenableUITests: XCTestCase {
    var app: XCUIApplication!
    var testEmail: String!
    var testPassword: String!
    var testUserId: String?

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Generate unique test account credentials
        let timestamp = Int(Date().timeIntervalSince1970)
        testEmail = "test-voice-reenable-\(timestamp)@mythweaver.app"
        testPassword = "TestPassword123!"

        // Create test user with ai_consent=true, voice_consent=false
        let setupExpectation = XCTestExpectation(description: "Setup complete")
        Task {
            await setupTestUser()
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

    func testVoiceButtonTappableWhenDisabled() throws {
        loginWithTestAccount()

        // Navigate to bug report view
        sleep(3)  // Wait for library to load

        // Tap profile icon to open menu
        let profileButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Profile' OR label CONTAINS 'Menu'")).firstMatch
        if profileButton.exists {
            profileButton.tap()
            sleep(1)
        }

        // Close profile menu if it opened
        let closeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Close' OR label CONTAINS 'Done'")).firstMatch
        if closeButton.exists {
            closeButton.tap()
            sleep(1)
        }

        // Find and tap the bug reporter icon
        let bugIcon = app.buttons["bugReporterIcon"]
        XCTAssertTrue(bugIcon.waitForExistence(timeout: 5), "Bug reporter icon should exist")
        bugIcon.tap()

        sleep(2)  // Wait for bug report view to appear

        // Select "Report a Bug" option
        let bugReportOption = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Report a Bug'")).firstMatch
        if bugReportOption.waitForExistence(timeout: 5) {
            bugReportOption.tap()
            sleep(2)
        }

        // Verify Voice button exists and is enabled (not disabled)
        let voiceButton = app.buttons["voiceChatButton"]
        XCTAssertTrue(voiceButton.waitForExistence(timeout: 5), "Voice button should exist")
        XCTAssertTrue(voiceButton.isEnabled, "Voice button should be enabled/tappable even when voice consent is false")

        // Take screenshot for verification
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testProfileMenuShowsEnableVoiceButton() throws {
        loginWithTestAccount()

        sleep(3)  // Wait for library to load

        // Tap profile icon to open menu
        let profileButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Profile' OR label CONTAINS 'Menu' OR label CONTAINS 'person'")).firstMatch
        XCTAssertTrue(profileButton.waitForExistence(timeout: 10), "Profile button should exist")
        profileButton.tap()

        sleep(2)  // Wait for menu to appear

        // Verify "Enable Voice Interviews" button appears (not "Voice interviews: Disabled")
        let enableVoiceButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Enable Voice Interviews'")).firstMatch
        XCTAssertTrue(enableVoiceButton.waitForExistence(timeout: 5), "Enable Voice Interviews button should exist")

        // Verify the old disabled label does NOT appear
        let disabledLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Voice interviews: Disabled'")).firstMatch
        XCTAssertFalse(disabledLabel.exists, "Old 'Voice interviews: Disabled' label should not exist")

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    // MARK: - Helper Methods

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

        // Handle consent screen if it appears
        let consentButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Agree' OR label CONTAINS 'Begin'")).firstMatch
        if consentButton.waitForExistence(timeout: 3) {
            consentButton.tap()
            sleep(3)
        }

        // Handle Dedication screen if it appears
        let dedicationContinue = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Continue' OR label CONTAINS 'Begin'")).firstMatch
        if dedicationContinue.waitForExistence(timeout: 2) {
            dedicationContinue.tap()
            sleep(2)
        }

        // Handle "Your Library" button on OnboardingView
        let libraryButton = app.buttons["Your Library"]
        if libraryButton.waitForExistence(timeout: 3) {
            libraryButton.tap()
            sleep(2)
        }
    }

    private func makeAPICall(_ request: URLRequest, description: String) async -> (Data, Int) {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0

            if statusCode >= 200 && statusCode < 300 {
                NSLog("✅ \(description) (HTTP \(statusCode))")
            } else {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                NSLog("❌ \(description) FAILED (HTTP \(statusCode)): \(body.prefix(200))")
            }
            return (data, statusCode)
        } catch {
            NSLog("❌ \(description) NETWORK ERROR: \(error)")
            return (Data(), 0)
        }
    }

    /// Creates test user via Supabase signup API, sets voice_consent=false, ai_consent=true
    private func setupTestUser() async {
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

        _ = await makeAPICall(metadataRequest, description: "Update user metadata")

        // 3. Seed user preferences with ai_consent=true, voice_consent=false
        let prefsURL = URL(string: "https://hszuuvkfgdfqgtaycojz.supabase.co/rest/v1/user_preferences")!
        var prefsRequest = URLRequest(url: prefsURL)
        prefsRequest.httpMethod = "POST"
        prefsRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        prefsRequest.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        prefsRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
        prefsRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let prefsBody: [String: Any] = [
            "user_id": userId,
            "ai_consent": true,          // AI consent granted
            "voice_consent": false,      // Voice consent NOT granted (this is what we're testing)
            "birth_year": 1995,
            "birth_month": 6,
            "is_minor": false
        ]
        prefsRequest.httpBody = try? JSONSerialization.data(withJSONObject: prefsBody)

        _ = await makeAPICall(prefsRequest, description: "Seed user preferences")
    }

    /// Clean up test user and their data
    private func cleanupTestData() async {
        guard let userId = testUserId else { return }

        let serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzenV1dmtmZ2RmcWd0YXljb2p6Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MDY3MDY0NSwiZXhwIjoyMDg2MjQ2NjQ1fQ.Ad7SLNXk-39z0ogwi7IB73e0kZSuRwRCfmWwcJMmeIs"
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzenV1dmtmZ2RmcWd0YXljb2p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2NzA2NDUsImV4cCI6MjA4NjI0NjY0NX0.YvjON4hgMTt081xM_ZjqVqNRd9q_LXUdMCbBDeprRUU"

        // Delete user preferences
        let prefsURL = URL(string: "https://hszuuvkfgdfqgtaycojz.supabase.co/rest/v1/user_preferences?user_id=eq.\(userId)")!
        var prefsRequest = URLRequest(url: prefsURL)
        prefsRequest.httpMethod = "DELETE"
        prefsRequest.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        prefsRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
        _ = await makeAPICall(prefsRequest, description: "Delete user preferences")

        // Delete user account
        let userURL = URL(string: "https://hszuuvkfgdfqgtaycojz.supabase.co/auth/v1/admin/users/\(userId)")!
        var userRequest = URLRequest(url: userURL)
        userRequest.httpMethod = "DELETE"
        userRequest.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        userRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
        _ = await makeAPICall(userRequest, description: "Delete user account")
    }
}
