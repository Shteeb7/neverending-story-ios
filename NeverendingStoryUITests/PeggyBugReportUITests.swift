//
//  PeggyBugReportUITests.swift
//  NeverendingStoryUITests
//
//  Tests for Peggy bug reporting feature
//

import XCTest

final class PeggyBugReportUITests: XCTestCase {
    var app: XCUIApplication!
    var testEmail: String!
    var testUserId: String?
    var supabaseUrl: String!
    var supabaseServiceKey: String!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Generate unique test email
        testEmail = "test-peggy-\(Int(Date().timeIntervalSince1970))@mythweaver.app"

        // Supabase configuration (use environment variables or hardcode for testing)
        supabaseUrl = "https://hszuuvkfgdfqgtaycojz.supabase.co"
        // TODO: Load service key from environment or secure location
        supabaseServiceKey = ProcessInfo.processInfo.environment["SUPABASE_SERVICE_KEY"] ?? ""

        app.launch()
    }

    override func tearDownWithError() throws {
        // Clean up test user if created
        if let userId = testUserId {
            Task {
                await cleanupTestUser(userId: userId)
            }
        }
    }

    // MARK: - Test 1: Bug icon visible after login
    func testBugIconVisible() throws {
        // Create account and log in
        try createTestAccount()

        // Wait for main screen to load (Library or Onboarding)
        let exists = app.otherElements["bugReporterIcon"].waitForExistence(timeout: 10)
        XCTAssertTrue(exists, "Bug reporter icon should be visible after login")
    }

    // MARK: - Test 2: Bug icon tap shows modal
    func testBugIconTapShowsModal() throws {
        // Create account and log in
        try createTestAccount()

        // Wait for and tap bug icon
        let bugIcon = app.otherElements["bugReporterIcon"]
        XCTAssertTrue(bugIcon.waitForExistence(timeout: 10), "Bug icon should exist")
        bugIcon.tap()

        // Verify modal appears with both options
        let reportBugButton = app.buttons["reportBugButton"]
        let suggestFeatureButton = app.buttons["suggestFeatureButton"]

        XCTAssertTrue(reportBugButton.waitForExistence(timeout: 5), "Report Bug button should appear")
        XCTAssertTrue(suggestFeatureButton.exists, "Suggest Feature button should appear")
    }

    // MARK: - Test 3: Cancel dismisses modal
    func testCancelDismisses() throws {
        // Create account and log in
        try createTestAccount()

        // Tap bug icon
        let bugIcon = app.otherElements["bugReporterIcon"]
        XCTAssertTrue(bugIcon.waitForExistence(timeout: 10), "Bug icon should exist")
        bugIcon.tap()

        // Wait for modal
        let reportBugButton = app.buttons["reportBugButton"]
        XCTAssertTrue(reportBugButton.waitForExistence(timeout: 5), "Modal should appear")

        // Tap X to dismiss
        let closeButton = app.buttons.matching(identifier: "xmark.circle.fill").firstMatch
        closeButton.tap()

        // Verify modal is gone
        XCTAssertFalse(reportBugButton.exists, "Modal should be dismissed")
    }

    // MARK: - Test 4: Settings toggle hides icon
    func testSettingsToggle() throws {
        // Create account and log in
        try createTestAccount()

        // Verify bug icon exists
        let bugIcon = app.otherElements["bugReporterIcon"]
        XCTAssertTrue(bugIcon.waitForExistence(timeout: 10), "Bug icon should exist initially")

        // Navigate to Settings
        // TODO: Adjust navigation based on actual app structure
        // This assumes Settings is accessible from the main screen
        let settingsButton = app.buttons["Settings"]
        if settingsButton.exists {
            settingsButton.tap()
        }

        // Toggle "Show Bug Reporter" off
        let toggle = app.switches["Show Bug Reporter"]
        if toggle.waitForExistence(timeout: 5) {
            toggle.tap()

            // Go back
            let doneButton = app.buttons["Done"]
            if doneButton.exists {
                doneButton.tap()
            }

            // Verify icon is gone
            XCTAssertFalse(bugIcon.exists, "Bug icon should be hidden after toggle")
        } else {
            XCTFail("Could not find Settings toggle")
        }
    }

    // MARK: - Test 5: Text bug report flow
    func testTextBugReport() throws {
        // Create account and log in
        try createTestAccount()

        // Tap bug icon
        let bugIcon = app.otherElements["bugReporterIcon"]
        XCTAssertTrue(bugIcon.waitForExistence(timeout: 10), "Bug icon should exist")
        bugIcon.tap()

        // Select "Report a Bug"
        let reportBugButton = app.buttons["reportBugButton"]
        XCTAssertTrue(reportBugButton.waitForExistence(timeout: 5), "Report Bug button should appear")
        reportBugButton.tap()

        // Select "Text"
        let textButton = app.buttons["textChatButton"]
        XCTAssertTrue(textButton.waitForExistence(timeout: 5), "Text button should appear")
        textButton.tap()

        // Verify Peggy header appears
        let peggyHeader = app.staticTexts["Line Open — Peggy, QA Division"]
        XCTAssertTrue(peggyHeader.waitForExistence(timeout: 10), "Peggy header should appear in text chat")
    }

    // MARK: - Test 6: Text suggestion flow
    func testTextSuggestion() throws {
        // Create account and log in
        try createTestAccount()

        // Tap bug icon
        let bugIcon = app.otherElements["bugReporterIcon"]
        XCTAssertTrue(bugIcon.waitForExistence(timeout: 10), "Bug icon should exist")
        bugIcon.tap()

        // Select "Suggest a Feature"
        let suggestFeatureButton = app.buttons["suggestFeatureButton"]
        XCTAssertTrue(suggestFeatureButton.waitForExistence(timeout: 5), "Suggest Feature button should appear")
        suggestFeatureButton.tap()

        // Select "Text"
        let textButton = app.buttons["textChatButton"]
        XCTAssertTrue(textButton.waitForExistence(timeout: 5), "Text button should appear")
        textButton.tap()

        // Verify Peggy header appears (same header for both bug reports and suggestions)
        let peggyHeader = app.staticTexts["Line Open — Peggy, QA Division"]
        XCTAssertTrue(peggyHeader.waitForExistence(timeout: 10), "Peggy header should appear in text chat")
    }

    // MARK: - Helper: Create test account
    private func createTestAccount() throws {
        // Look for email signup button (adjust identifier as needed)
        let emailSignupButton = app.buttons["createAccountWithEmail"]
        if !emailSignupButton.waitForExistence(timeout: 5) {
            // Try alternative identifier
            let alternativeButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'email'")).firstMatch
            if alternativeButton.exists {
                alternativeButton.tap()
            } else {
                XCTFail("Could not find email signup button")
                return
            }
        } else {
            emailSignupButton.tap()
        }

        // Enter email
        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 5), "Email field should appear")
        emailField.tap()
        emailField.typeText(testEmail)

        // Enter password
        let passwordField = app.secureTextFields.firstMatch
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5), "Password field should appear")
        passwordField.tap()
        passwordField.typeText("TestPassword123!")

        // Submit
        let submitButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'create' OR label CONTAINS[c] 'sign up'")).firstMatch
        XCTAssertTrue(submitButton.exists, "Submit button should exist")
        submitButton.tap()

        // Wait for login to complete (adjust wait condition based on actual app flow)
        sleep(3)
    }

    // MARK: - Helper: Cleanup test user
    private func cleanupTestUser(userId: String) async {
        // Delete user and associated data via Supabase REST API
        guard !supabaseServiceKey.isEmpty else {
            print("⚠️ Supabase service key not configured, skipping cleanup")
            return
        }

        let url = URL(string: "\(supabaseUrl)/rest/v1/rpc/delete_test_user")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(supabaseServiceKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["user_id": userId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("✅ Test user \(userId) cleaned up successfully")
            } else {
                print("⚠️ Failed to cleanup test user: unexpected response")
            }
        } catch {
            print("❌ Failed to cleanup test user: \(error)")
        }
    }
}
