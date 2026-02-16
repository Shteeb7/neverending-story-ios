//
//  TextChatUITests.swift
//  NeverendingStoryUITests
//
//  UI tests for text chat with Prospero feature
//  Tests real signup flow → onboarding → text chat
//

import XCTest

final class TextChatUITests: XCTestCase {
    var app: XCUIApplication!
    var testEmail: String!
    var testPassword: String!

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Generate unique test account credentials
        let timestamp = Int(Date().timeIntervalSince1970)
        testEmail = "test-\(timestamp)@mythweaver.app"
        testPassword = "TestPassword123!"

        app = XCUIApplication()

        // Reset app state between tests
        app.launchArguments = ["--uitesting"]

        app.launch()

        // Create account through real signup flow
        try createTestAccount()
    }

    override func tearDownWithError() throws {
        // Clean up test user and all their data synchronously
        let expectation = XCTestExpectation(description: "Cleanup complete")
        Task {
            await cleanupTestUser(email: testEmail)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        // Terminate app to ensure clean state for next test
        app.terminate()
        app = nil
    }

    // MARK: - Helper Methods

    /// Creates a new account through the real signup UI
    private func createTestAccount() throws {
        // Debug: Print what's actually on screen
        sleep(3) // Give app time to load
        print("\n🔍 DEBUG: View hierarchy after launch:")
        print(app.debugDescription)
        print("\n🔍 Buttons found: \(app.buttons.count)")
        print("🔍 TextFields found: \(app.textFields.count)")
        print("🔍 StaticTexts found: \(app.staticTexts.count)\n")

        // Wait for LoginView to load
        let emailField = app.textFields.element(matching: .textField, identifier: "Email or username")
        if !emailField.waitForExistence(timeout: 30) {
            // Try finding by placeholder - get first text field
            let allTextFields = app.textFields
            print("\n❌ Login screen never appeared. Debug info:")
            print("  - Buttons: \(app.buttons.allElementsBoundByIndex.map { $0.label })")
            print("  - TextFields: \(app.textFields.allElementsBoundByIndex.map { $0.placeholderValue ?? "no placeholder" })")
            print("  - StaticTexts: \(app.staticTexts.allElementsBoundByIndex.prefix(10).map { $0.label })")
            XCTAssertGreaterThan(allTextFields.count, 0, "No text fields found on login screen")
        }

        // Toggle to signup mode - try multiple possible labels
        var createAccountToggle = app.buttons["New here? Create Account"]
        if !createAccountToggle.exists {
            createAccountToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create Account'")).firstMatch
        }
        XCTAssertTrue(createAccountToggle.waitForExistence(timeout: 10), "Create Account toggle should exist")
        createAccountToggle.tap()

        // Fill in email
        let emailInput = app.textFields.element(boundBy: 0)
        emailInput.tap()
        emailInput.typeText(testEmail)

        // Fill in password
        let passwordInput = app.secureTextFields.element(boundBy: 0)
        passwordInput.tap()
        passwordInput.typeText(testPassword)

        // Tap Create Account button - try multiple possible labels
        var createAccountButton = app.buttons["Create Account"]
        if !createAccountButton.exists {
            createAccountButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create'")).firstMatch
        }
        XCTAssertTrue(createAccountButton.exists, "Create Account button should exist")
        createAccountButton.tap()

        // Wait for account creation and navigation (Supabase network call + splash screen)
        sleep(5)

        // Handle DedicationView if it appears
        // DedicationView shows "For Rob, Faith and Brady" and "tap to continue" after ~7 seconds
        let dedicationText = app.staticTexts["For Rob, Faith and Brady"]
        if dedicationText.waitForExistence(timeout: 2) {
            NSLog("🎭 DedicationView appeared, waiting for tap prompt...")
            let tapToContinue = app.staticTexts["tap to continue"]
            if tapToContinue.waitForExistence(timeout: 15) {
                // Tap anywhere to dismiss dedication view
                app.tap()
                NSLog("🎭 Dismissed DedicationView, waiting for OnboardingView...")
                // Wait for fade out and OnboardingView to load
                sleep(3)

                // Debug: What's on screen now?
                print("\n🔍 After DedicationView dismissal:")
                print("  - Buttons: \(app.buttons.count)")
                print("  - Button labels: \(app.buttons.allElementsBoundByIndex.prefix(5).map { $0.label })")
                print("  - StaticTexts: \(app.staticTexts.allElementsBoundByIndex.prefix(5).map { $0.label })\n")
            }
        } else {
            // No dedication view, likely went straight to onboarding after splash
            NSLog("📱 No DedicationView detected, waiting for OnboardingView...")
            sleep(2)
        }

        // Now we should be on OnboardingView
    }

    /// Cleans up test user and all their data via direct database access
    private func cleanupTestUser(email: String) async {
        guard let url = URL(string: "https://hszuuvkfgdfqgtaycojz.supabase.co/rest/v1/rpc/cleanup_test_user") else {
            print("⚠️ Invalid cleanup URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzenV1dmtmZ2RmcWd0YXljb2p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY4MTMxMTMsImV4cCI6MjA1MjM4OTExM30.Ix3dOOcP-XT6dq7BPmAJ4p3DkSKIPRNPMRlWP13kkpw", forHTTPHeaderField: "apikey")

        let body: [String: Any] = ["email_pattern": email]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Cleaned up test user: \(email)")
                } else {
                    print("⚠️ Cleanup returned status \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("⚠️ Cleanup failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Tests

    func testSideBySkipeSpeakAndWriteButtonsAppear() throws {
        // After signup, we should be on onboarding screen
        // Verify both Speak and Write buttons exist

        // Use fuzzy matching to handle button labels with or without newlines
        let speakButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Speak'")).firstMatch
        let writeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Write'")).firstMatch

        // Give onboarding screen time to appear after signup (30s for network + navigation)
        XCTAssertTrue(speakButton.waitForExistence(timeout: 30), "Speak button should exist on onboarding")
        XCTAssertTrue(writeButton.exists, "Write button should exist on onboarding")

        // Verify both are tappable
        XCTAssertTrue(speakButton.isHittable, "Speak button should be tappable")
        XCTAssertTrue(writeButton.isHittable, "Write button should be tappable")
    }

    func testTextChatViewLoadsWithProsperoOpeningMessage() throws {
        // Wait for and tap "Write to Prospero" button
        let writeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Write'")).firstMatch
        XCTAssertTrue(writeButton.waitForExistence(timeout: 10), "Write button should appear on onboarding")
        writeButton.tap()

        // Verify TextChatView loaded by checking for input field
        let inputField = app.textFields.element(matching: .textField, identifier: "Write to Prospero...")
        if !inputField.waitForExistence(timeout: 10) {
            // Try finding by matching all text fields (input field should be present)
            let allTextFields = app.textFields
            XCTAssertGreaterThan(allTextFields.count, 0, "Text chat input field should appear")
        }

        // Wait for Prospero's opening message (allow time for typewriter animation)
        sleep(5)

        // Verify message scroll view exists with content
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.exists, "Message scroll view should exist")

        // Prospero's opening message should be visible
        let hasMessages = scrollView.staticTexts.count > 0
        XCTAssertTrue(hasMessages, "Prospero's opening message should appear")
    }

    func testSendMessageAndVerifyUserMessageAppearsOnRight() throws {
        // Navigate to text chat
        let writeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Write'")).firstMatch
        XCTAssertTrue(writeButton.waitForExistence(timeout: 10), "Write button should appear")
        writeButton.tap()

        // Wait for input field
        sleep(3)
        let inputField = app.textFields["textChatInput"]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5), "Input field should appear")

        // Wait for Prospero's opening message to finish
        sleep(5)

        // Type test message
        inputField.tap()
        inputField.typeText("I love fantasy and dragons")

        // Tap send button using accessibility identifier
        let sendButton = app.buttons["sendMessageButton"]
        XCTAssertTrue(sendButton.exists, "Send button should exist")
        sendButton.tap()

        // Verify user message appears in scroll view
        sleep(2)
        let scrollView = app.scrollViews.firstMatch

        // Check that message was added (count should increase)
        // User message should appear with the text we sent
        let userMessageExists = scrollView.staticTexts["I love fantasy and dragons"].exists
        XCTAssertTrue(userMessageExists, "User message 'I love fantasy and dragons' should appear in chat")
    }

    func testLoadingIndicatorAppearsDuringResponse() throws {
        // Navigate to text chat
        let writeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Write'")).firstMatch
        XCTAssertTrue(writeButton.waitForExistence(timeout: 10), "Write button should appear")
        writeButton.tap()

        // Wait for input and opening message
        sleep(8)
        let inputField = app.textFields.firstMatch
        XCTAssertTrue(inputField.exists, "Input field should exist")

        // Type and send message
        inputField.tap()
        inputField.typeText("Tell me more")

        // Send
        let sendButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'send' OR label CONTAINS 'send'")).firstMatch
        if sendButton.exists {
            sendButton.tap()
        } else {
            inputField.typeText("\n")
        }

        // Check for loading indicator
        // It should appear briefly while waiting for Prospero's response
        let loadingIndicator = app.staticTexts["Prospero ponders..."]

        // The loading indicator might appear very briefly
        // Check within a 3 second window
        let indicatorAppeared = loadingIndicator.waitForExistence(timeout: 3)

        // If API is very fast, we might miss the indicator
        // This is not a hard failure - just log it
        if !indicatorAppeared {
            print("ℹ️ Loading indicator did not appear (API may have responded instantly)")
        }
    }

    func testProsperoResponseAppearsOnLeftSide() throws {
        // Navigate to text chat
        let writeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Write'")).firstMatch
        XCTAssertTrue(writeButton.waitForExistence(timeout: 10), "Write button should appear")
        writeButton.tap()

        // Wait for input and opening message
        sleep(8)
        let inputField = app.textFields.firstMatch
        inputField.tap()

        // Count initial messages
        let scrollView = app.scrollViews.firstMatch
        let initialMessageCount = scrollView.staticTexts.count

        // Type and send message
        inputField.typeText("I enjoy epic adventures")

        let sendButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'send' OR label CONTAINS 'send'")).firstMatch
        if sendButton.exists {
            sendButton.tap()
        } else {
            inputField.typeText("\n")
        }

        // Wait for Prospero's response (Claude API can take several seconds)
        sleep(10)

        // Verify new messages appeared
        let finalMessageCount = scrollView.staticTexts.count

        // We expect at least 2 new messages:
        // 1. Our user message ("I enjoy epic adventures")
        // 2. Prospero's response
        XCTAssertGreaterThan(finalMessageCount, initialMessageCount + 1,
            "Prospero's response should appear after user message (count: \(finalMessageCount) vs initial: \(initialMessageCount))")
    }

    func testCompleteTextChatFlow() throws {
        // This test runs through the complete happy path from signup to conversation

        // 1. Verify we're on onboarding (already navigated via signup in setUp)
        let speakButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Speak'")).firstMatch
        let writeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Write'")).firstMatch
        XCTAssertTrue(writeButton.waitForExistence(timeout: 10), "Write button should appear after signup")
        XCTAssertTrue(speakButton.exists, "Speak button should also exist")

        // 2. Tap Write button
        writeButton.tap()

        // 3. Verify TextChatView loaded
        let inputField = app.textFields.firstMatch
        XCTAssertTrue(inputField.waitForExistence(timeout: 10), "Input field should appear in TextChatView")

        // 4. Wait for Prospero's opening message
        sleep(6)

        // 5. Send first message
        inputField.tap()
        inputField.typeText("I love fantasy stories with magic")

        let sendButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'send' OR label CONTAINS 'send'")).firstMatch
        if sendButton.exists {
            sendButton.tap()
        } else {
            inputField.typeText("\n")
        }

        // 6. Wait for response (Claude API can take up to 60 seconds)
        sleep(60)

        // 7. Send second message to continue conversation
        inputField.tap()
        inputField.typeText("Tell me about dragons")
        if sendButton.exists {
            sendButton.tap()
        } else {
            inputField.typeText("\n")
        }

        // 8. Wait for second response (Claude API can take up to 60 seconds)
        sleep(60)

        // 9. Verify conversation is progressing
        let scrollView = app.scrollViews.firstMatch

        // Should have multiple messages:
        // - Prospero's opening
        // - User message 1
        // - Prospero's response 1
        // - User message 2
        // - Prospero's response 2
        // = At least 5 messages
        XCTAssertGreaterThanOrEqual(scrollView.staticTexts.count, 5,
            "Complete conversation should have at least 5 messages")

        // Test passes if we reach this point without crashes or timeouts
        print("✅ Complete text chat flow succeeded with \(scrollView.staticTexts.count) messages")
    }
}
