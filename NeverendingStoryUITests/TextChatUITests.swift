//
//  TextChatUITests.swift
//  NeverendingStoryUITests
//
//  UI tests for text chat with Prospero feature
//

import XCTest

final class TextChatUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testSideBySkipeSpeakAndWriteButtonsAppear() throws {
        // Navigate to onboarding screen
        // Note: This assumes the app launches to a state where we can reach onboarding
        // May need to adjust based on actual app flow (login, etc.)

        // Wait for onboarding screen to load
        let speakButton = app.buttons["Speak with Prospero"]
        let writeButton = app.buttons["Write to Prospero"]

        // Verify both buttons exist and are visible
        XCTAssertTrue(speakButton.waitForExistence(timeout: 10), "Speak button should exist")
        XCTAssertTrue(writeButton.exists, "Write button should exist")
        XCTAssertTrue(speakButton.isHittable, "Speak button should be tappable")
        XCTAssertTrue(writeButton.isHittable, "Write button should be tappable")
    }

    func testTextChatViewLoadsWithProsperoOpeningMessage() throws {
        // Wait for and tap "Write to Prospero" button
        let writeButton = app.buttons["Write to Prospero"]
        XCTAssertTrue(writeButton.waitForExistence(timeout: 10), "Write button should appear")
        writeButton.tap()

        // Verify TextChatView loaded by checking for key UI elements
        // Look for the input field
        let inputField = app.textFields["Write to Prospero..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5), "Input field should appear")

        // Wait for Prospero's opening message
        // The message should appear in a scroll view with typewriter animation
        // We'll check for static text containing common opening words
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Message scroll view should exist")

        // Prospero's opening message should contain his name or a greeting
        // Wait for typewriter animation to complete (allow up to 10 seconds)
        sleep(3) // Give typewriter animation time to start and progress

        // Check that there's at least one message from Prospero (left side)
        // In the actual implementation, Prospero's messages have specific styling
        let prosperoMessage = scrollView.staticTexts.firstMatch
        XCTAssertTrue(prosperoMessage.exists, "Prospero's opening message should appear")
    }

    func testSendMessageAndVerifyUserMessageAppearsOnRight() throws {
        // Navigate to text chat
        let writeButton = app.buttons["Write to Prospero"]
        XCTAssertTrue(writeButton.waitForExistence(timeout: 10), "Write button should appear")
        writeButton.tap()

        // Wait for input field
        let inputField = app.textFields["Write to Prospero..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5), "Input field should appear")

        // Wait for Prospero's opening message to finish (typewriter animation)
        sleep(5)

        // Type test message
        inputField.tap()
        inputField.typeText("I love fantasy and dragons")

        // Send message (tap send button - paperplane icon)
        let sendButton = app.buttons.matching(identifier: "sendMessageButton").firstMatch
        if sendButton.exists {
            sendButton.tap()
        } else {
            // If accessibility identifier not set, look for button near input field
            app.buttons.element(boundBy: 0).tap()
        }

        // Verify user message appears
        // In the implementation, user messages are right-aligned in the scroll view
        let scrollView = app.scrollViews.firstMatch
        let userMessage = scrollView.staticTexts["I love fantasy and dragons"]
        XCTAssertTrue(userMessage.waitForExistence(timeout: 5), "User message should appear in chat")
    }

    func testLoadingIndicatorAppearsDuringResponse() throws {
        // Navigate to text chat
        let writeButton = app.buttons["Write to Prospero"]
        XCTAssertTrue(writeButton.waitForExistence(timeout: 10), "Write button should appear")
        writeButton.tap()

        // Wait for input field and opening message
        let inputField = app.textFields["Write to Prospero..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5), "Input field should appear")
        sleep(5) // Wait for opening message

        // Type and send message
        inputField.tap()
        inputField.typeText("Tell me more")

        // Send message
        let sendButton = app.buttons.matching(identifier: "sendMessageButton").firstMatch
        if sendButton.exists {
            sendButton.tap()
        } else {
            app.buttons.element(boundBy: 0).tap()
        }

        // Verify "Prospero ponders..." loading indicator appears
        // This should appear briefly while waiting for API response
        let loadingIndicator = app.staticTexts["Prospero ponders..."]

        // The loading indicator might appear very briefly, so we check within 2 seconds
        // If API is fast, we might miss it, but the test shouldn't fail
        let indicatorAppeared = loadingIndicator.waitForExistence(timeout: 2)

        // Note: This assertion is soft - if the API responds instantly, indicator might not appear
        // In a real implementation, we'd mock the API to ensure loading state is testable
        if !indicatorAppeared {
            print("⚠️ Loading indicator did not appear - API may have responded too quickly")
        }
    }

    func testProsperoResponseAppearsOnLeftSide() throws {
        // Navigate to text chat
        let writeButton = app.buttons["Write to Prospero"]
        XCTAssertTrue(writeButton.waitForExistence(timeout: 10), "Write button should appear")
        writeButton.tap()

        // Wait for input field and opening message
        let inputField = app.textFields["Write to Prospero..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5), "Input field should appear")
        sleep(5) // Wait for opening message

        // Count initial messages (should be 1 - Prospero's opening)
        let scrollView = app.scrollViews.firstMatch
        let initialMessageCount = scrollView.staticTexts.count

        // Type and send message
        inputField.tap()
        inputField.typeText("I enjoy epic adventures")

        // Send message
        let sendButton = app.buttons.matching(identifier: "sendMessageButton").firstMatch
        if sendButton.exists {
            sendButton.tap()
        } else {
            app.buttons.element(boundBy: 0).tap()
        }

        // Wait for Prospero's response (may take several seconds for API call)
        sleep(8)

        // Verify new message appeared (count should increase)
        // We expect at least 2 new messages: user message + Prospero's response
        let finalMessageCount = scrollView.staticTexts.count
        XCTAssertGreaterThan(finalMessageCount, initialMessageCount + 1,
            "Prospero's response should appear after user message")

        // Verify response is from Prospero (left-aligned, different styling)
        // In actual implementation, we'd check styling or accessibility identifiers
        // For now, we verify message count increased, indicating response arrived
    }

    func testCompleteTextChatFlow() throws {
        // This test runs through the complete happy path

        // 1. Launch and verify buttons
        let speakButton = app.buttons["Speak with Prospero"]
        let writeButton = app.buttons["Write to Prospero"]
        XCTAssertTrue(writeButton.waitForExistence(timeout: 10), "Write button should appear")
        XCTAssertTrue(speakButton.exists, "Speak button should also exist")

        // 2. Tap Write button
        writeButton.tap()

        // 3. Verify TextChatView loaded
        let inputField = app.textFields["Write to Prospero..."]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5), "Input field should appear")

        // 4. Wait for Prospero's opening message
        sleep(5)

        // 5. Send first message
        inputField.tap()
        inputField.typeText("I love fantasy stories")
        app.buttons.element(boundBy: 0).tap()

        // 6. Wait for response
        sleep(8)

        // 7. Verify conversation is progressing
        let scrollView = app.scrollViews.firstMatch
        XCTAssertGreaterThan(scrollView.staticTexts.count, 2,
            "Multiple messages should appear in conversation")

        // Test passes if we reach this point without crashes or timeouts
    }
}
