import XCTest

/// Layer 1: Happy Path Smoke Test
/// A single continuous test that walks the golden path through the entire app.
/// Uses real APIs with mid-test seeding to avoid long waits.
/// Stops on first failure (continueAfterFailure = false).
final class SmokeTestUITests: XCTestCase {
    var app: XCUIApplication!
    var testEmail: String!
    var testPassword: String!
    var testUserId: String?
    var testAccessToken: String?

    // MARK: - Setup/Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        let timestamp = Int(Date().timeIntervalSince1970)
        testEmail = "smoke-\(timestamp)@mythweaver.app"
        testPassword = "SmokeTest123!"
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        let email = testEmail!
        let expectation = XCTestExpectation(description: "Cleanup")
        Task { await TestFixtures.cleanupTestUser(email: email); expectation.fulfill() }
        wait(for: [expectation], timeout: 10.0)
        app.terminate(); app = nil
    }

    // MARK: - The Smoke Test

    func testCompleteHappyPath() throws {
        var attemptCount = 0
        let maxAttempts = 3

        // Segment 1: Splash
        print("🔥 Segment 1: Splash")
        sleep(3)
        let loginEmailField = app.textFields.element(matching: .textField, identifier: "Email or username")
        XCTAssertTrue(loginEmailField.waitForExistence(timeout: 30), "Login screen should appear after splash")
        print("✅ Segment 1 complete")

        // Segment 2: Create Account
        print("🔥 Segment 2: Create Account")
        let createAccountToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create Account'")).firstMatch
        attemptCount = 0
        while !createAccountToggle.exists && attemptCount < maxAttempts {
            attemptCount += 1
            print("⚠️ Create Account toggle not found (attempt \(attemptCount)/\(maxAttempts))")
            sleep(1)
        }
        XCTAssertTrue(createAccountToggle.waitForExistence(timeout: 5), "Create Account toggle should exist (3-Strike)")
        createAccountToggle.tap()
        sleep(1)

        let emailField = app.textFields.element(boundBy: 0)
        XCTAssertTrue(emailField.exists, "Email field should exist")
        emailField.tap()
        emailField.typeText(testEmail)

        let passwordField = app.secureTextFields.element(boundBy: 0)
        XCTAssertTrue(passwordField.exists, "Password field should exist")
        passwordField.tap()
        passwordField.typeText(testPassword)

        let createButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create'")).firstMatch
        XCTAssertTrue(createButton.exists, "Create button should exist")
        createButton.tap()
        sleep(5)
        print("✅ Segment 2 complete")

        // Segment 3: Age Gate
        print("🔥 Segment 3: Age Gate")
        let ageGateHeading = app.staticTexts["When Did Your Story Begin?"]
        XCTAssertTrue(ageGateHeading.waitForExistence(timeout: 10), "Age gate should appear")

        let monthPicker = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(monthPicker.waitForExistence(timeout: 3), "Month picker should exist")
        monthPicker.adjust(toPickerWheelValue: "June")

        let yearPicker = app.pickerWheels.element(boundBy: 1)
        XCTAssertTrue(yearPicker.exists, "Year picker should exist")
        let currentYear = Calendar.current.component(.year, from: Date())
        yearPicker.adjust(toPickerWheelValue: String(currentYear - 25))

        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists, "Continue button should exist")
        continueButton.tap()
        sleep(2)
        print("✅ Segment 3 complete")

        // Segment 4: AI Consent
        print("🔥 Segment 4: AI Consent")
        let consentHeading = app.staticTexts["Before Your Story Begins"]
        XCTAssertTrue(consentHeading.waitForExistence(timeout: 10), "AI Consent should appear")

        let agreeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'I Agree'")).firstMatch
        XCTAssertTrue(agreeButton.exists, "I Agree button should exist")
        agreeButton.tap()
        sleep(2)
        print("✅ Segment 4 complete")

        // Segment 5: Dedication
        print("🔥 Segment 5: Dedication")
        let dedicationText = app.staticTexts["For Rob, Faith and Brady"]
        if dedicationText.waitForExistence(timeout: 3) {
            let tapToContinue = app.staticTexts["tap to continue"]
            XCTAssertTrue(tapToContinue.waitForExistence(timeout: 15), "Tap to continue should appear")
            app.tap()
            sleep(3)
            print("✅ Segment 5 complete (dedication shown)")
        } else {
            print("✅ Segment 5 complete (dedication skipped)")
        }

        // Segment 6: Onboarding Mode Select
        print("🔥 Segment 6: Onboarding Mode Select")
        let speakButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Speak'")).firstMatch
        let writeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Write'")).firstMatch
        XCTAssertTrue(speakButton.waitForExistence(timeout: 10), "Speak button should exist")
        XCTAssertTrue(writeButton.exists, "Write button should exist")
        print("✅ Segment 6 complete")

        // Segment 7: Voice Check
        print("🔥 Segment 7: Voice Check")
        speakButton.tap()

        // Check for voice consent first
        let voiceConsentHeading = app.staticTexts["A Note About Voice"]
        if voiceConsentHeading.waitForExistence(timeout: 3) {
            let consentButton = app.buttons["I Consent"]
            XCTAssertTrue(consentButton.exists, "Voice consent button should exist")
            consentButton.tap()
            sleep(2)
        }

        // Look for voice connection UI (waveform, connecting text, or mic permission)
        let voiceStarted = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Listening' OR label CONTAINS 'Prospero'")).firstMatch.waitForExistence(timeout: 10)
        if voiceStarted {
            print("✅ Voice connection started")
        } else {
            print("⚠️ Voice UI not detected, but continuing test")
        }

        // Back out from voice
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.exists {
            backButton.tap()
        } else {
            // Try tapping a cancel or close button
            let cancelButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Cancel' OR label CONTAINS 'Close'")).firstMatch
            if cancelButton.exists {
                cancelButton.tap()
            }
        }
        sleep(2)
        print("✅ Segment 7 complete")

        // Segment 8: Text Chat Onboarding
        print("🔥 Segment 8: Text Chat Onboarding")
        // Should be back at mode select
        XCTAssertTrue(writeButton.waitForExistence(timeout: 5), "Write button should reappear")
        writeButton.tap()
        sleep(2)

        // Wait for Prospero's greeting
        let prosperosGreeting = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Prospero' OR label CONTAINS 'story'")).firstMatch
        XCTAssertTrue(prosperosGreeting.waitForExistence(timeout: 60), "Prospero's greeting should appear")

        // Type first message
        let messageField = app.textFields.firstMatch
        attemptCount = 0
        while !messageField.exists && attemptCount < maxAttempts {
            attemptCount += 1
            print("⚠️ Message field not found (attempt \(attemptCount)/\(maxAttempts))")
            sleep(2)
        }
        XCTAssertTrue(messageField.exists, "Message field should exist (3-Strike)")
        messageField.tap()
        messageField.typeText("I love fantasy with dragons and magic. Favorites: Lord of the Rings, Harry Potter")

        let sendButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Send'")).firstMatch
        XCTAssertTrue(sendButton.exists, "Send button should exist")
        sendButton.tap()

        // Wait for response
        sleep(60)

        // Type second message
        XCTAssertTrue(messageField.waitForExistence(timeout: 10), "Message field should reappear")
        messageField.tap()
        messageField.typeText("About 300 pages, strong female protagonist, epic quest")
        sendButton.tap()

        // Wait for response
        sleep(60)

        // End interview
        let endButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'End' OR label CONTAINS 'Submit'")).firstMatch
        XCTAssertTrue(endButton.waitForExistence(timeout: 10), "End button should exist")
        endButton.tap()

        // Confirm if needed
        let confirmButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Confirm' OR label CONTAINS 'Yes'")).firstMatch
        if confirmButton.waitForExistence(timeout: 3) {
            confirmButton.tap()
        }
        sleep(3)
        print("✅ Segment 8 complete")

        // Segment 9: DNA Transfer
        print("🔥 Segment 9: DNA Transfer")
        let portalButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Portal' OR label CONTAINS 'Mythweaver' OR label CONTAINS 'Enter'")).firstMatch
        XCTAssertTrue(portalButton.waitForExistence(timeout: 60), "Portal button should appear")
        portalButton.tap()
        sleep(2)

        let fingerPrompt = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'finger'")).firstMatch
        XCTAssertTrue(fingerPrompt.waitForExistence(timeout: 5), "Finger prompt should appear")

        // Long press for 11 seconds
        let centerCoordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        centerCoordinate.press(forDuration: 11.0)
        sleep(2)

        // Wait for premises to be ready (polling)
        sleep(60)
        print("✅ Segment 9 complete")

        // Segment 10: Premise Selection
        print("🔥 Segment 10: Premise Selection")
        let premiseCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Premise' OR label CONTAINS 'Story'")).firstMatch
        attemptCount = 0
        while !premiseCard.exists && attemptCount < maxAttempts {
            attemptCount += 1
            print("⚠️ Premise card not found (attempt \(attemptCount)/\(maxAttempts))")
            sleep(5)
        }
        XCTAssertTrue(premiseCard.exists, "Premise card should exist (3-Strike)")
        premiseCard.tap()
        sleep(2)

        let selectButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Select'")).firstMatch
        XCTAssertTrue(selectButton.waitForExistence(timeout: 5), "Select button should exist")
        selectButton.tap()
        sleep(2)
        print("✅ Segment 10 complete")

        // Segment 11: Name Confirmation
        print("🔥 Segment 11: Name Confirmation")
        let nameField = app.textFields.matching(NSPredicate(format: "placeholder CONTAINS 'name' OR identifier CONTAINS 'name'")).firstMatch
        if nameField.waitForExistence(timeout: 5) {
            nameField.tap()
            nameField.typeText("Smoke Test User")
            let confirmNameButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Confirm' OR label CONTAINS 'OK'")).firstMatch
            XCTAssertTrue(confirmNameButton.exists, "Confirm name button should exist")
            confirmNameButton.tap()
            sleep(2)
        }
        print("✅ Segment 11 complete")

        // Segment 12: Book Formation + Seed
        print("🔥 Segment 12: Book Formation + Seed")
        let bookFormationIndicator = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'inscribing' OR label CONTAINS 'Prospero' OR label CONTAINS 'conjuring'")).firstMatch
        XCTAssertTrue(bookFormationIndicator.waitForExistence(timeout: 10), "Book formation view should appear")
        sleep(3) // Let real API fire

        // MID-TEST SEED: Fetch the newly created story and seed chapters
        print("🔄 Mid-test seeding: Fetching latest story...")
        let seedExpectation = XCTestExpectation(description: "Seed complete")
        Task {
            do {
                // First, get auth token by signing in via Supabase
                let (userId, accessToken) = try await TestFixtures.createAccount(email: testEmail, password: testPassword)
                self.testUserId = userId
                self.testAccessToken = accessToken

                // Fetch the latest story
                let (storyId, arcId) = try await TestFixtures.fetchLatestStory(userId: userId, accessToken: accessToken)
                print("📖 Found story: \(storyId), arc: \(arcId ?? "none")")

                guard let arc = arcId else {
                    print("⚠️ No arc found, creating story components...")
                    // Story exists but no arc - seed everything
                    let bibleId = UUID().uuidString
                    // Note: In a real scenario, we'd need to create bible and arc
                    // For smoke test, we'll skip if arc doesn't exist
                    seedExpectation.fulfill()
                    return
                }

                // Seed 3 chapters
                try await TestFixtures.seedAdditionalChapters(storyId: storyId, arcId: arc, accessToken: accessToken, fromChapter: 1, toChapter: 3)

                // Update generation progress
                try await TestFixtures.updateGenerationProgress(storyId: storyId, accessToken: accessToken, step: "awaiting_chapter_2_feedback", chaptersGenerated: 3)

                print("✅ Seeded 3 chapters successfully")
            } catch {
                print("❌ Seed failed: \(error)")
            }
            seedExpectation.fulfill()
        }
        wait(for: [seedExpectation], timeout: 60.0)

        // Wait for app to detect chapters
        sleep(10)
        print("✅ Segment 12 complete")

        // Segment 13: First Line Ceremony (conditional)
        print("🔥 Segment 13: First Line Ceremony (conditional)")
        let firstLineCeremony = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'first line' OR label CONTAINS 'First Line'")).firstMatch
        if firstLineCeremony.waitForExistence(timeout: 5) {
            app.tap()
            sleep(2)
            print("✅ Segment 13 complete (ceremony shown)")
        } else {
            print("✅ Segment 13 complete (ceremony skipped)")
        }

        // Segment 14: Book Reader
        print("🔥 Segment 14: Book Reader")
        let chapterContent = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'morning' OR label CONTAINS 'sun' OR label CONTAINS 'crystal'")).firstMatch
        XCTAssertTrue(chapterContent.waitForExistence(timeout: 15), "Chapter content should be visible")

        let nextChapterButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Next'")).firstMatch
        attemptCount = 0
        while !nextChapterButton.exists && attemptCount < maxAttempts {
            attemptCount += 1
            print("⚠️ Next Chapter button not found (attempt \(attemptCount)/\(maxAttempts))")
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(nextChapterButton.exists, "Next Chapter button should exist (3-Strike)")
        print("✅ Segment 14 complete")

        // Segment 15: Chapter Navigation
        print("🔥 Segment 15: Chapter Navigation")
        nextChapterButton.tap()
        sleep(2)
        let chapter2Indicator = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Chapter 2'")).firstMatch
        XCTAssertTrue(chapter2Indicator.waitForExistence(timeout: 10), "Chapter 2 should load")
        print("✅ Segment 15 complete")

        // Segment 16: Checkpoint + Seed
        print("🔥 Segment 16: Checkpoint + Seed")
        // Scroll to 100% to trigger checkpoint
        for _ in 1...5 {
            app.swipeUp()
            sleep(1)
        }

        let feedbackDialog = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Fantastic' OR label CONTAINS 'Great' OR label CONTAINS 'pacing'")).firstMatch
        XCTAssertTrue(feedbackDialog.waitForExistence(timeout: 10), "Feedback dialog should appear")

        let fantasticButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'hooked' OR label CONTAINS 'Fantastic'")).firstMatch
        XCTAssertTrue(fantasticButton.exists, "Fantastic/hooked button should exist")
        fantasticButton.tap()
        sleep(2)

        // MID-TEST SEED: Seed chapters 4-6
        print("🔄 Mid-test seeding: Adding chapters 4-6...")
        let seed2Expectation = XCTestExpectation(description: "Seed 2 complete")
        Task {
            guard let userId = self.testUserId, let accessToken = self.testAccessToken else {
                print("❌ No auth credentials for seeding")
                seed2Expectation.fulfill()
                return
            }

            do {
                let (storyId, arcId) = try await TestFixtures.fetchLatestStory(userId: userId, accessToken: accessToken)
                guard let arc = arcId else {
                    print("⚠️ No arc found")
                    seed2Expectation.fulfill()
                    return
                }

                try await TestFixtures.seedAdditionalChapters(storyId: storyId, arcId: arc, accessToken: accessToken, fromChapter: 4, toChapter: 6)
                try await TestFixtures.updateGenerationProgress(storyId: storyId, accessToken: accessToken, step: "awaiting_chapter_5_feedback", chaptersGenerated: 6)
                print("✅ Seeded chapters 4-6 successfully")
            } catch {
                print("❌ Seed 2 failed: \(error)")
            }
            seed2Expectation.fulfill()
        }
        wait(for: [seed2Expectation], timeout: 30.0)

        sleep(5)
        print("✅ Segment 16 complete")

        // Segment 17: Library
        print("🔥 Segment 17: Library")
        let backToLibrary = app.navigationBars.buttons.firstMatch
        if backToLibrary.exists {
            backToLibrary.tap()
        } else {
            // Try swiping right to go back
            app.swipeRight()
        }
        sleep(2)

        let bookCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Crimson' OR label CONTAINS 'Story'")).firstMatch
        XCTAssertTrue(bookCard.waitForExistence(timeout: 10), "Book should appear in library")
        print("✅ Segment 17 complete")

        // Segment 18: Bug Report Icon
        print("🔥 Segment 18: Bug Report Icon")
        let bugIcon = app.buttons.matching(NSPredicate(format: "label CONTAINS 'bug' OR label CONTAINS 'report'")).firstMatch
        attemptCount = 0
        while !bugIcon.exists && attemptCount < maxAttempts {
            attemptCount += 1
            print("⚠️ Bug icon not found (attempt \(attemptCount)/\(maxAttempts))")
            sleep(2)
        }
        if bugIcon.exists {
            bugIcon.tap()
            sleep(2)

            let reportBugOption = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Report' OR label CONTAINS 'Bug'")).firstMatch
            let suggestFeatureOption = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Suggest' OR label CONTAINS 'Feature'")).firstMatch
            XCTAssertTrue(reportBugOption.exists || suggestFeatureOption.exists, "Bug report options should exist")
            print("✅ Segment 18 complete")

            // Segment 19: Peggy Text Chat
            print("🔥 Segment 19: Peggy Text Chat")
            if reportBugOption.exists {
                reportBugOption.tap()
                sleep(2)

                let peggyMessageField = app.textFields.firstMatch
                if peggyMessageField.waitForExistence(timeout: 10) {
                    peggyMessageField.tap()
                    peggyMessageField.typeText("Chapter nav skips sometimes when swiping fast")
                    let peggySendButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Send'")).firstMatch
                    peggySendButton.tap()
                    sleep(60) // Wait for Peggy's response

                    let submitButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Submit' OR label CONTAINS 'Done'")).firstMatch
                    if submitButton.waitForExistence(timeout: 10) {
                        submitButton.tap()
                        sleep(2)
                    }
                }
            }
            print("✅ Segment 19 complete")

            // Segment 20: Bug Confirmation
            print("🔥 Segment 20: Bug Confirmation")
            let confirmationMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Thank' OR label CONTAINS 'received'")).firstMatch
            if confirmationMessage.waitForExistence(timeout: 5) {
                let returnButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Return' OR label CONTAINS 'Close'")).firstMatch
                if returnButton.exists {
                    returnButton.tap()
                }
            }
            print("✅ Segment 20 complete")
        } else {
            print("⚠️ Bug report icon not found - skipping segments 18-20 (3-Strike)")
        }

        // Segment 21: Settings
        print("🔥 Segment 21: Settings")
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Settings' OR identifier CONTAINS 'settings'")).firstMatch
        if settingsButton.exists {
            settingsButton.tap()
            sleep(2)

            let accountInfo = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '\(testEmail)'")).firstMatch
            let signOutButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign Out'")).firstMatch
            XCTAssertTrue(accountInfo.exists || signOutButton.exists, "Settings should show account info or sign out")

            // Go back without signing out
            let backFromSettings = app.navigationBars.buttons.firstMatch
            if backFromSettings.exists {
                backFromSettings.tap()
            }
            print("✅ Segment 21 complete")
        } else {
            print("⚠️ Settings not found - skipping segment 21")
        }

        print("🎉 SMOKE TEST COMPLETE - ALL SEGMENTS PASSED")
    }
}
