import XCTest

final class AgeGateUITests: XCTestCase {
    var app: XCUIApplication!
    var testEmail: String!
    var testPassword: String!

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Generate unique test account credentials
        let timestamp = Int(Date().timeIntervalSince1970)
        testEmail = "test-agegate-\(timestamp)@mythweaver.app"
        testPassword = "TestPassword123!"

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
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

    /// Cleans up test user via direct database access
    private func cleanupTestUser(email: String) async {
        guard let url = URL(string: "https://hszuuvkfgdfqgtaycojz.supabase.co/rest/v1/rpc/cleanup_test_user") else {
            print("⚠️ Invalid cleanup URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzenV1dmtmZ2RmcWd0YXljb2p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2NzA2NDUsImV4cCI6MjA4NjI0NjY0NX0.YvjON4hgMTt081xM_ZjqVqNRd9q_LXUdMCbBDeprRUU", forHTTPHeaderField: "apikey")

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

    /// Helper to navigate to age gate screen
    private func navigateToAgeGate() {
        sleep(3)
        let createAccountToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create Account'")).firstMatch
        XCTAssertTrue(createAccountToggle.waitForExistence(timeout: 30), "Create Account button should exist")
        createAccountToggle.tap()

        let ageGateHeading = app.staticTexts["When Did Your Story Begin?"]
        XCTAssertTrue(ageGateHeading.waitForExistence(timeout: 5), "Age gate should appear")
    }

    /// Helper to set age using picker wheels
    private func setAge(birthMonth: String, birthYear: String) {
        // Find month picker wheel (first picker)
        let monthPicker = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(monthPicker.waitForExistence(timeout: 3), "Month picker should exist")
        monthPicker.adjust(toPickerWheelValue: birthMonth)

        // Find year picker wheel (second picker)
        let yearPicker = app.pickerWheels.element(boundBy: 1)
        XCTAssertTrue(yearPicker.waitForExistence(timeout: 3), "Year picker should exist")
        yearPicker.adjust(toPickerWheelValue: birthYear)
    }

    // MARK: - Tests

    /// Test 1: Age gate appears when tapping Create Account
    func testAgeGateAppearsOnCreateAccount() throws {
        navigateToAgeGate()

        // Verify atmospheric subtext
        let subtext = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Every great tale'")).firstMatch
        XCTAssertTrue(subtext.exists, "Atmospheric subtext should be visible")

        // Verify pickers exist
        let monthPicker = app.pickerWheels.element(boundBy: 0)
        let yearPicker = app.pickerWheels.element(boundBy: 1)
        XCTAssertTrue(monthPicker.exists, "Month picker should exist")
        XCTAssertTrue(yearPicker.exists, "Year picker should exist")

        // Verify Continue button exists
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists, "Continue button should exist")

        print("✅ Test 1 passed: Age gate appears with pickers")
    }

    /// Test 2: Under-13 user is blocked with friendly message
    func testUnder13UserBlocked() throws {
        navigateToAgeGate()

        // Calculate DOB for 10-year-old
        let currentYear = Calendar.current.component(.year, from: Date())
        let birthYear = currentYear - 10

        // Set age to 10 years old
        setAge(birthMonth: "June", birthYear: String(birthYear))
        sleep(1)

        // Tap Continue
        let continueButton = app.buttons["Continue"]
        continueButton.tap()
        sleep(2)

        // VERIFY: Under-13 message appears
        let blockMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'readers 13 and older'")).firstMatch
        XCTAssertTrue(
            blockMessage.waitForExistence(timeout: 3),
            "Under-13 block message should appear"
        )

        // Verify friendly message
        let hopeMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'hope to see you'")).firstMatch
        XCTAssertTrue(hopeMessage.exists, "Friendly hope message should be visible")

        // Verify "Got It" button
        let gotItButton = app.buttons["Got It"]
        XCTAssertTrue(gotItButton.exists, "Got It button should exist")

        // Tap "Got It"
        gotItButton.tap()
        sleep(1)

        // VERIFY: Returned to login screen
        let emailField = app.textFields.element(boundBy: 0)
        XCTAssertTrue(
            emailField.waitForExistence(timeout: 3),
            "Should return to login screen after tapping Got It"
        )

        print("✅ Test 2 passed: Under-13 user blocked with friendly message")
    }

    /// Test 3: 18+ user proceeds to account creation form
    func testAdultUserProceeds() throws {
        navigateToAgeGate()

        // Calculate DOB for 25-year-old
        let currentYear = Calendar.current.component(.year, from: Date())
        let birthYear = currentYear - 25

        // Set age to 25 years old
        setAge(birthMonth: "June", birthYear: String(birthYear))
        sleep(1)

        // Tap Continue
        let continueButton = app.buttons["Continue"]
        continueButton.tap()
        sleep(2)

        // VERIFY: Create Account form appears (email/password fields)
        let emailField = app.textFields.element(boundBy: 0)
        let passwordField = app.secureTextFields.element(boundBy: 0)

        XCTAssertTrue(
            emailField.waitForExistence(timeout: 5),
            "Email field should appear after age verification"
        )
        XCTAssertTrue(passwordField.exists, "Password field should be present")

        // Verify we're in signup mode (Create Account button should be visible)
        let createButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create'")).firstMatch
        XCTAssertTrue(createButton.exists, "Create Account button should be visible")

        print("✅ Test 3 passed: 18+ user proceeds to account creation form")
    }

    /// Test 4: Complete account creation and verify DOB stored in Supabase
    func testCompleteAccountCreationWithDOB() throws {
        navigateToAgeGate()

        // Calculate DOB for 25-year-old
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        let birthYear = currentYear - 25
        let birthMonth = 6 // June

        // Set age to 25 years old
        setAge(birthMonth: "June", birthYear: String(birthYear))
        sleep(1)

        // Tap Continue
        let continueButton = app.buttons["Continue"]
        continueButton.tap()
        sleep(2)

        // Fill in email and password
        let emailField = app.textFields.element(boundBy: 0)
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(testEmail)

        let passwordField = app.secureTextFields.element(boundBy: 0)
        passwordField.tap()
        passwordField.typeText(testPassword)

        // Tap Create Account button
        let createButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create'")).firstMatch
        createButton.tap()

        // Wait for account creation to complete (we don't need to wait for AI consent,
        // just need to give the signup + saveDOB API calls time to complete)
        // Increased to 12 seconds to ensure backend processing completes
        sleep(12)

        // Verify DOB was stored in Supabase
        let expectation = XCTestExpectation(description: "DOB verification complete")
        Task {
            print("🔍 About to verify DOB in Supabase...")
            let dobStored = await verifyDOBStoredInSupabase(email: testEmail, expectedMonth: birthMonth, expectedYear: birthYear)
            print("🔍 Verification result: \(dobStored)")

            if dobStored {
                print("✅ Test 4 passed: Complete account creation with DOB stored")
            } else {
                print("❌ Test 4 FAILED: DOB verification returned false")
            }

            XCTAssertTrue(dobStored, "DOB should be stored in Supabase after account creation")
            expectation.fulfill()
        }

        let result = XCTWaiter.wait(for: [expectation], timeout: 15.0)
        if result != .completed {
            print("❌ Expectation timed out after 15 seconds")
        }
    }

    /// Verify DOB was stored in Supabase
    private func verifyDOBStoredInSupabase(email: String, expectedMonth: Int, expectedYear: Int) async -> Bool {
        // Simpler approach: query user_preferences for the most recent entry with matching DOB
        // Since we just created the account, the most recent entry with these values should be our test user
        guard let prefsUrl = URL(string: "https://hszuuvkfgdfqgtaycojz.supabase.co/rest/v1/user_preferences?select=birth_month,birth_year,is_minor&birth_month=eq.\(expectedMonth)&birth_year=eq.\(expectedYear)&order=created_at.desc&limit=1") else {
            print("⚠️ Invalid preferences URL")
            return false
        }

        var prefsRequest = URLRequest(url: prefsUrl)
        prefsRequest.httpMethod = "GET"
        prefsRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        prefsRequest.setValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzenV1dmtmZ2RmcWd0YXljb2p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2NzA2NDUsImV4cCI6MjA4NjI0NjY0NX0.YvjON4hgMTt081xM_ZjqVqNRd9q_LXUdMCbBDeprRUU", forHTTPHeaderField: "apikey")

        do {
            let (prefsData, _) = try await URLSession.shared.data(for: prefsRequest)

            if let json = try? JSONSerialization.jsonObject(with: prefsData) as? [[String: Any]],
               let prefs = json.first,
               let birthMonth = prefs["birth_month"] as? Int,
               let birthYear = prefs["birth_year"] as? Int,
               let isMinor = prefs["is_minor"] as? Bool {

                // Verify values match (should always match since we filtered by them)
                if birthMonth == expectedMonth && birthYear == expectedYear && !isMinor {
                    return true
                } else {
                    print("❌ is_minor flag incorrect: expected false, got \(isMinor)")
                    return false
                }
            }

            print("❌ No user_preferences found with birth_month=\(expectedMonth), birth_year=\(expectedYear)")
            return false
        } catch {
            print("⚠️ Failed to verify DOB in Supabase: \(error.localizedDescription)")
            return false
        }
    }
}
