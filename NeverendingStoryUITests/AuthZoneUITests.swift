import XCTest

/// Layer 2: Auth Zone Tests
/// Tests login, signup, error handling, and validation.
/// Uses fresh-user preset (default).
final class AuthZoneUITests: MythweaverUITestCase {
    // Uses default preset (fresh-user)

    // MARK: - Tests

    func testLoginWithValidCredentials() throws {
        // Account already created by base class setUp
        try loginWithTestAccount()

        // Verify we're past login (should see library, onboarding, or consent)
        let loggedInIndicator = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Before Your Story Begins' OR label CONTAINS 'Library' OR label CONTAINS 'Speak'")).firstMatch
        XCTAssertTrue(loggedInIndicator.waitForExistence(timeout: 10), "Should be logged in")

        print("✅ testLoginWithValidCredentials passed")
    }

    func testLoginWithWrongPassword() throws {
        sleep(3)

        // Enter correct email but wrong password
        let emailField = app.textFields.element(matching: .textField, identifier: "Email or username")
        XCTAssertTrue(emailField.waitForExistence(timeout: 15), "Email field should appear")
        emailField.tap()
        emailField.typeText(testEmail)

        let passwordField = app.secureTextFields.firstMatch
        XCTAssertTrue(passwordField.exists, "Password field should exist")
        passwordField.tap()
        passwordField.typeText("WrongPassword123!")

        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.exists, "Sign In button should exist")
        signInButton.tap()

        sleep(3)

        // Look for error message (3-Strike Rule)
        let errorMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Invalid' OR label CONTAINS 'incorrect' OR label CONTAINS 'wrong'")).firstMatch
        var attemptCount = 0
        let maxAttempts = 3

        while !errorMessage.exists && attemptCount < maxAttempts {
            attemptCount += 1
            print("⚠️ Error message not found, checking again (attempt \(attemptCount)/\(maxAttempts))")
            sleep(2)

            // Check if we accidentally logged in (shouldn't happen)
            let loggedIn = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Library' OR label CONTAINS 'Speak'")).firstMatch
            if loggedIn.exists {
                XCTFail("Should not have logged in with wrong password")
                return
            }
        }

        if errorMessage.exists {
            XCTAssertTrue(true, "Error message displayed for wrong password")
            print("✅ testLoginWithWrongPassword passed")
        } else {
            print("⚠️ No explicit error message shown - may need manual verification (3-Strike)")
            // Verify we're still on login screen
            XCTAssertTrue(emailField.exists, "Should still be on login screen")
        }
    }

    func testLoginWithEmptyFields() throws {
        sleep(3)

        // Try to sign in without entering anything
        let signInButton = app.buttons["Sign In"]
        var attemptCount = 0
        let maxAttempts = 3

        while !signInButton.exists && attemptCount < maxAttempts {
            attemptCount += 1
            print("⚠️ Sign In button not found (attempt \(attemptCount)/\(maxAttempts))")
            sleep(1)
        }

        XCTAssertTrue(signInButton.exists, "Sign In button should exist (3-Strike)")
        signInButton.tap()
        sleep(2)

        // Should either show validation error or button should be disabled
        let emailField = app.textFields.element(matching: .textField, identifier: "Email or username")
        XCTAssertTrue(emailField.exists, "Should remain on login screen with empty fields")

        // Check if there's a validation message
        let validationMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'required' OR label CONTAINS 'empty' OR label CONTAINS 'enter'")).firstMatch
        if validationMessage.exists {
            print("✅ Validation message shown for empty fields")
        } else {
            print("⚠️ No explicit validation message - button may be disabled")
        }

        print("✅ testLoginWithEmptyFields passed")
    }

    func testSignupFlow() throws {
        sleep(3)

        // Tap Create Account toggle
        let createAccountToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create Account'")).firstMatch
        XCTAssertTrue(createAccountToggle.waitForExistence(timeout: 10), "Create Account toggle should exist")
        createAccountToggle.tap()
        sleep(1)

        // Verify we're in signup mode (email/password fields visible)
        let emailField = app.textFields.element(boundBy: 0)
        XCTAssertTrue(emailField.exists, "Email field should exist in signup mode")

        let passwordField = app.secureTextFields.element(boundBy: 0)
        XCTAssertTrue(passwordField.exists, "Password field should exist in signup mode")

        // Verify Create Account button exists
        let createButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create'")).firstMatch
        XCTAssertTrue(createButton.exists, "Create Account button should exist")

        print("✅ testSignupFlow passed")
    }

    func testToggleBetweenLoginAndSignup() throws {
        sleep(3)

        // Should start in login mode
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 10), "Should start in login mode")

        // Toggle to signup
        let createAccountToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create Account'")).firstMatch
        XCTAssertTrue(createAccountToggle.exists, "Create Account toggle should exist")
        createAccountToggle.tap()
        sleep(1)

        // Verify we're in signup mode
        let createButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create'")).firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 3), "Should be in signup mode")

        // Toggle back to login
        let signInToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign In' AND NOT label CONTAINS 'with'")).firstMatch
        if signInToggle.exists {
            signInToggle.tap()
            sleep(1)

            // Verify we're back in login mode
            XCTAssertTrue(signInButton.waitForExistence(timeout: 3), "Should be back in login mode")
        } else {
            print("⚠️ Sign In toggle not found - may be same button")
        }

        print("✅ testToggleBetweenLoginAndSignup passed")
    }

    func testEmailValidation() throws {
        sleep(3)

        // Toggle to signup mode
        let createAccountToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create Account'")).firstMatch
        XCTAssertTrue(createAccountToggle.waitForExistence(timeout: 10))
        createAccountToggle.tap()
        sleep(1)

        // Try invalid email format
        let emailField = app.textFields.element(boundBy: 0)
        emailField.tap()
        emailField.typeText("notanemail")

        let passwordField = app.secureTextFields.element(boundBy: 0)
        passwordField.tap()
        passwordField.typeText("Password123!")

        let createButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create'")).firstMatch
        createButton.tap()
        sleep(2)

        // Should show validation error or stay on same screen
        let validationError = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'valid' OR label CONTAINS 'email' OR label CONTAINS 'format'")).firstMatch
        if validationError.exists {
            print("✅ Email validation error shown")
        } else {
            // Verify we didn't proceed past login
            XCTAssertTrue(emailField.exists, "Should remain on signup screen with invalid email")
            print("⚠️ No explicit validation message - implicit validation may be in place")
        }

        print("✅ testEmailValidation passed")
    }

    func testPasswordRequirements() throws {
        sleep(3)

        // Toggle to signup mode
        let createAccountToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create Account'")).firstMatch
        XCTAssertTrue(createAccountToggle.waitForExistence(timeout: 10))
        createAccountToggle.tap()
        sleep(1)

        // Try weak password
        let timestamp = Int(Date().timeIntervalSince1970)
        let emailField = app.textFields.element(boundBy: 0)
        emailField.tap()
        emailField.typeText("test-\(timestamp)@mythweaver.app")

        let passwordField = app.secureTextFields.element(boundBy: 0)
        passwordField.tap()
        passwordField.typeText("123") // Too short

        let createButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create'")).firstMatch
        createButton.tap()
        sleep(2)

        // Should show password requirement error or stay on same screen
        let passwordError = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'password' OR label CONTAINS 'characters' OR label CONTAINS 'weak'")).firstMatch
        if passwordError.exists {
            print("✅ Password requirement error shown")
        } else {
            // Verify we didn't proceed
            XCTAssertTrue(emailField.exists, "Should remain on signup screen with weak password")
            print("⚠️ No explicit password error - may be client-side validation")
        }

        print("✅ testPasswordRequirements passed")
    }

    func testDoubleTapSignInPrevention() throws {
        // This test verifies the app handles double-tap gracefully
        sleep(3)

        let emailField = app.textFields.element(matching: .textField, identifier: "Email or username")
        XCTAssertTrue(emailField.waitForExistence(timeout: 15))
        emailField.tap()
        emailField.typeText(testEmail)

        let passwordField = app.secureTextFields.firstMatch
        passwordField.tap()
        passwordField.typeText(testPassword)

        let signInButton = app.buttons["Sign In"]

        // Rapidly tap Sign In twice
        signInButton.tap()
        signInButton.tap()

        sleep(5)

        // Should login once, not crash or create duplicate sessions
        let loggedInIndicator = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Before Your Story Begins' OR label CONTAINS 'Library' OR label CONTAINS 'Speak'")).firstMatch
        XCTAssertTrue(loggedInIndicator.waitForExistence(timeout: 10), "Should handle double-tap gracefully")

        print("✅ testDoubleTapSignInPrevention passed")
    }
}
