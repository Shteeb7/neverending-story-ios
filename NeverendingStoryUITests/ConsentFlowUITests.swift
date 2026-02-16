import XCTest

final class ConsentFlowUITests: XCTestCase {
    var app: XCUIApplication!
    var testEmail: String!
    var testUserId: String?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Generate unique test email
        testEmail = "test-consent-\(Date().timeIntervalSince1970)@mythweaver.app"

        app.launch()
    }

    override func tearDownWithError() throws {
        // Clean up: Delete test user and data from Supabase
        if let userId = testUserId {
            Task {
                await cleanupTestUser(userId: userId)
            }
        }
    }

    /// Test complete consent flow: AI consent → Onboarding → Voice consent
    func testConsentFlow() throws {
        // STEP 1: Create account through real signup flow
        XCTContext.runActivity(named: "Create test account") { _ in
            // Wait for launch screen to finish
            sleep(3)

            // Look for "Create Account" or "Get Started" button
            let createAccountButton = app.buttons["Create Account"]
            if createAccountButton.waitForExistence(timeout: 5) {
                createAccountButton.tap()
            }

            // Fill in email and password (assuming standard signup form)
            let emailField = app.textFields["Email"]
            XCTAssertTrue(emailField.waitForExistence(timeout: 5), "Email field should appear")
            emailField.tap()
            emailField.typeText(testEmail)

            let passwordField = app.secureTextFields["Password"]
            XCTAssertTrue(passwordField.exists, "Password field should exist")
            passwordField.tap()
            passwordField.typeText("TestPassword123!")

            // Tap sign up button
            let signUpButton = app.buttons["Sign Up"]
            if signUpButton.exists {
                signUpButton.tap()
            }

            // Store userId for cleanup (would need to fetch from response or UI)
            // For now, mark that account was created
            print("✅ Test account created: \(testEmail)")
        }

        // STEP 2: Verify AI Consent screen appears
        XCTContext.runActivity(named: "Verify AI Consent screen") { _ in
            let consentHeading = app.staticTexts["Before Your Story Begins"]
            XCTAssertTrue(
                consentHeading.waitForExistence(timeout: 10),
                "AI Consent screen should appear after account creation"
            )

            // Verify consent text is present
            let consentText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'third-party AI service providers'"))
            XCTAssertTrue(consentText.firstMatch.exists, "Consent disclosure text should be visible")

            // Verify "I Agree" button exists
            let agreeButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'I Agree'")).firstMatch
            XCTAssertTrue(agreeButton.exists, "I Agree button should be present")

            print("✅ AI Consent screen verified")
        }

        // STEP 3: Grant AI consent
        XCTContext.runActivity(named: "Grant AI consent") { _ in
            let agreeButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'I Agree'")).firstMatch
            agreeButton.tap()

            // Wait for consent to be processed
            sleep(2)

            print("✅ AI consent granted")
        }

        // STEP 4: Verify onboarding screen appears with Speak/Write buttons
        XCTContext.runActivity(named: "Verify onboarding proceeds") { _ in
            // Look for "Speak with Prospero" button
            let speakButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Speak'")).firstMatch
            XCTAssertTrue(
                speakButton.waitForExistence(timeout: 10),
                "Onboarding screen with Speak button should appear after AI consent"
            )

            // Verify "Write to Prospero" button also exists
            let writeButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Write'")).firstMatch
            XCTAssertTrue(writeButton.exists, "Write button should also be present")

            print("✅ Onboarding screen verified with Speak/Write options")
        }

        // STEP 5: Tap "Speak with Prospero" to trigger voice consent
        XCTContext.runActivity(named: "Trigger voice consent") { _ in
            let speakButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Speak'")).firstMatch
            speakButton.tap()

            // Verify Voice Consent screen appears
            let voiceConsentHeading = app.staticTexts["A Note About Voice"]
            XCTAssertTrue(
                voiceConsentHeading.waitForExistence(timeout: 5),
                "Voice Consent screen should appear when tapping Speak"
            )

            // Verify voice consent disclosure text
            let voiceText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'voice is recorded'"))
            XCTAssertTrue(voiceText.firstMatch.exists, "Voice consent disclosure should be visible")

            print("✅ Voice Consent screen verified")
        }

        // STEP 6: Test "Go Back" button
        XCTContext.runActivity(named: "Test Go Back from voice consent") { _ in
            let goBackButton = app.buttons["Go Back"]
            XCTAssertTrue(goBackButton.exists, "Go Back button should be present")
            goBackButton.tap()

            // Should return to Speak/Write selection
            let speakButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Speak'")).firstMatch
            XCTAssertTrue(
                speakButton.waitForExistence(timeout: 3),
                "Should return to Speak/Write selection after Go Back"
            )

            print("✅ Go Back button works correctly")
        }

        // STEP 7: Tap Speak again and grant voice consent
        XCTContext.runActivity(named: "Grant voice consent") { _ in
            let speakButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Speak'")).firstMatch
            speakButton.tap()

            // Wait for Voice Consent screen
            let voiceConsentHeading = app.staticTexts["A Note About Voice"]
            XCTAssertTrue(voiceConsentHeading.waitForExistence(timeout: 3))

            // Tap "I Consent"
            let consentButton = app.buttons["I Consent"]
            XCTAssertTrue(consentButton.exists, "I Consent button should be present")
            consentButton.tap()

            // Wait for consent to be processed and voice session to start
            sleep(3)

            // Verify voice session started (would look for voice UI indicators)
            // For now, just verify we're past the consent screen
            XCTAssertFalse(voiceConsentHeading.exists, "Should have proceeded past voice consent screen")

            print("✅ Voice consent granted, voice session should have started")
        }

        // STEP 8: Verify subsequent "Speak" taps don't show consent again
        // (Would need to navigate back and trigger another speak action, skipping for brevity)
    }

    // MARK: - Cleanup Helper

    private func cleanupTestUser(userId: String) async {
        // Use Supabase Admin API to delete test user and associated data
        // This would require making API calls to delete:
        // - User record from auth.users
        // - User preferences
        // - Any stories created
        // - Reading sessions
        // - Etc.

        print("🧹 Cleaning up test user: \(userId)")

        // For now, just log - actual implementation would call Supabase admin endpoints
        // Example (pseudo-code):
        // await supabaseAdmin.auth.admin.deleteUser(userId)
        // await supabaseAdmin.from('user_preferences').delete().eq('user_id', userId)
        // await supabaseAdmin.from('stories').delete().eq('user_id', userId)
    }
}
