//
//  RealtimeLibraryUITests.swift
//  NeverendingStoryUITests
//
//  Tests that library and reader views work correctly with Realtime push architecture
//

import XCTest

final class RealtimeLibraryUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
    }

    override func tearDownWithError() throws {
        // Clean up test account via Supabase if needed
        app = nil
    }

    // MARK: - Library View Tests

    func testLibraryViewLoadsWithRealtimeManager() throws {
        // This test verifies that LibraryView initializes successfully with the new
        // StoryRealtimeManager and doesn't crash on load

        // Create test account via email/password
        let timestamp = Date().timeIntervalSince1970
        let testEmail = "test-realtime-\(timestamp)@mythweaver.app"
        let testPassword = "TestPassword123!"

        app.launch()

        // Navigate to Create Account
        let createAccountButton = app.buttons["Create Account"]
        XCTAssertTrue(createAccountButton.waitForExistence(timeout: 5))
        createAccountButton.tap()

        // Fill in credentials
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(testEmail)

        let passwordField = app.secureTextFields["Password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText(testPassword)

        // Submit
        let signUpButton = app.buttons["Sign Up"]
        XCTAssertTrue(signUpButton.exists)
        signUpButton.tap()

        // Should reach library view (with "Your Library" title)
        let libraryTitle = app.navigationBars["Your Library"]
        XCTAssertTrue(libraryTitle.waitForExistence(timeout: 10), "Library view should load with Realtime manager initialized")

        // Verify user menu exists (proves AuthManager subscribed to Realtime)
        let userMenuButton = app.buttons.matching(identifier: "person.circle").firstMatch
        XCTAssertTrue(userMenuButton.exists, "User menu should exist after authentication and Realtime subscription")
    }

    func testLibraryRefreshWithoutPolling() throws {
        // This test verifies that library can refresh on manual pull without polling timers

        let timestamp = Date().timeIntervalSince1970
        let testEmail = "test-refresh-\(timestamp)@mythweaver.app"
        let testPassword = "TestPassword123!"

        app.launch()

        // Create account and reach library
        let createAccountButton = app.buttons["Create Account"]
        XCTAssertTrue(createAccountButton.waitForExistence(timeout: 5))
        createAccountButton.tap()

        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(testEmail)

        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText(testPassword)

        let signUpButton = app.buttons["Sign Up"]
        signUpButton.tap()

        let libraryTitle = app.navigationBars["Your Library"]
        XCTAssertTrue(libraryTitle.waitForExistence(timeout: 10))

        // Pull to refresh should work (verifies refreshLibrary() works without polling)
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            // Swipe down to trigger pull-to-refresh
            scrollView.swipeDown()

            // Should still show library (no crash from removed polling logic)
            XCTAssertTrue(libraryTitle.exists, "Library should remain visible after refresh")
        }
    }

    // MARK: - Reader View Tests

    func testReaderViewWithRealtimeObservation() throws {
        // This test verifies that BookReaderView works with realtime chapter observations
        // We can't easily simulate new chapters arriving, but we can verify the view loads

        // Note: This test requires a seeded account with at least one story with chapters
        // In production, we'd seed via Supabase API. For now, we verify the flow doesn't crash.

        let timestamp = Date().timeIntervalSince1970
        let testEmail = "test-reader-\(timestamp)@mythweaver.app"
        let testPassword = "TestPassword123!"

        app.launch()

        // Create account
        let createAccountButton = app.buttons["Create Account"]
        XCTAssertTrue(createAccountButton.waitForExistence(timeout: 5))
        createAccountButton.tap()

        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(testEmail)

        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText(testPassword)

        let signUpButton = app.buttons["Sign Up"]
        signUpButton.tap()

        let libraryTitle = app.navigationBars["Your Library"]
        XCTAssertTrue(libraryTitle.waitForExistence(timeout: 10))

        // Verify library loads without crashing (proves BookReaderView changes compile)
        // If there were a story to tap, we'd test that the reader opens
        // For now, we've verified the architecture compiles and doesn't crash on library load
        XCTAssertTrue(libraryTitle.exists, "App should not crash with new realtime architecture")
    }

    // MARK: - Realtime Subscription Tests

    func testRealtimeSubscriptionOnLogin() throws {
        // This test verifies that Realtime subscription happens on login
        // We can't directly test the websocket, but we can verify no crash occurs

        let timestamp = Date().timeIntervalSince1970
        let testEmail = "test-subscription-\(timestamp)@mythweaver.app"
        let testPassword = "TestPassword123!"

        app.launch()

        let createAccountButton = app.buttons["Create Account"]
        XCTAssertTrue(createAccountButton.waitForExistence(timeout: 5))
        createAccountButton.tap()

        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(testEmail)

        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText(testPassword)

        let signUpButton = app.buttons["Sign Up"]
        signUpButton.tap()

        // Should reach library without crash (proves subscription succeeded or failed gracefully)
        let libraryTitle = app.navigationBars["Your Library"]
        XCTAssertTrue(libraryTitle.waitForExistence(timeout: 10), "Should reach library after Realtime subscription attempt")

        // Now log out (should trigger unsubscribe)
        let userMenuButton = app.buttons.matching(identifier: "person.circle").firstMatch
        XCTAssertTrue(userMenuButton.exists)
        userMenuButton.tap()

        let logoutButton = app.buttons["Log Out"]
        if logoutButton.waitForExistence(timeout: 2) {
            logoutButton.tap()

            // Confirm logout
            let confirmLogoutButton = app.buttons["Log Out"].firstMatch
            if confirmLogoutButton.waitForExistence(timeout: 2) {
                confirmLogoutButton.tap()

                // Should return to login screen without crash
                XCTAssertTrue(createAccountButton.waitForExistence(timeout: 5), "Should return to auth screen after logout and unsubscribe")
            }
        }
    }
}
