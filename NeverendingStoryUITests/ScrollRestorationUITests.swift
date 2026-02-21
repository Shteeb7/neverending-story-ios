//
//  ScrollRestorationUITests.swift
//  NeverendingStoryUITests
//
//  Tests that scroll position restoration works correctly using percentage-based paragraphs
//

import XCTest

final class ScrollRestorationUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// SCROLL POSITION RESTORATION TEST
    /// Tests that a book with saved scroll position (50% of Chapter 2) restores to the middle,
    /// NOT to the top of the chapter.
    ///
    /// Test account has been pre-seeded with:
    /// - Story: "The Eighth Amendment"
    /// - Chapter: 2 (1-based, so currentChapterIndex = 1)
    /// - Scroll position: 50.0 (percentage)
    ///
    /// Expected: Reader opens to MIDDLE of Chapter 2, chapter title NOT visible
    func testScrollRestorationToMiddleOfChapter() throws {
        app.launch()

        // STEP 1: Wait for login screen to appear (after splash screen)
        sleep(3) // Wait for splash screen to dismiss

        let emailField = app.textFields.element(boundBy: 0)
        XCTAssertTrue(emailField.waitForExistence(timeout: 10), "Email field should appear after splash")

        // STEP 2: Sign in with pre-seeded test account (email/password)
        emailField.tap()
        emailField.typeText("debug-clone-1771698307241@mythweaver.app")

        let passwordField = app.secureTextFields.element(boundBy: 0)
        XCTAssertTrue(passwordField.exists, "Password field should exist")
        passwordField.tap()
        passwordField.typeText("299d06df151368a61ddc3f468186deb8")

        // Submit sign in (button initially shows "Sign In" text)
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.exists, "Sign in button should exist")
        signInButton.tap()

        // STEP 2: Handle DedicationView if it appears (--uitesting clears hasSeenDedication)
        // DedicationView has ~8 second animation before becoming tappable
        let dedicationText = app.staticTexts["For Rob, Faith and Brady"]
        if dedicationText.waitForExistence(timeout: 5) {
            let tapToContinue = app.staticTexts["tap to continue"]
            if tapToContinue.waitForExistence(timeout: 15) {
                // Wait an extra second for fade-in animation to complete
                sleep(1)
                app.tap() // Tap anywhere on the screen
                sleep(1) // Wait for fade-out
            }
        }

        // STEP 3: Wait for library to load
        let libraryTitle = app.navigationBars["Your Library"]
        XCTAssertTrue(libraryTitle.waitForExistence(timeout: 10), "Should reach library after sign in")

        // STEP 4: Find and tap "The Eighth Amendment" book
        // The book might be in different UI elements depending on library state
        // Try button first (if it's the "Continue Your Tale" hero card)
        let bookButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'The Eighth Amendment'")).firstMatch

        if bookButton.waitForExistence(timeout: 5) {
            bookButton.tap()
        } else {
            // If not a button, might be in a different container - tap any element with the title
            let bookElement = app.staticTexts["The Eighth Amendment"].firstMatch
            XCTAssertTrue(bookElement.waitForExistence(timeout: 5), "Book 'The Eighth Amendment' should be in library")
            bookElement.tap()
        }

        // STEP 5: Wait for reader to open and verify scroll position
        // Give the reader time to load and apply scroll restoration
        sleep(2)

        // EXPECTED: Should see Chapter 2 content, but NOT the chapter title at top
        let chapterTitle = app.staticTexts["Chapter 2"]
        let chapterTitleVisible = chapterTitle.exists && chapterTitle.isHittable

        // Look for text that should be visible in the MIDDLE of Chapter 2 (around 50%)
        // Based on the test context, these paragraphs should be visible:
        let middleText1 = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Denise read each one'")).firstMatch
        let middleText2 = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Zhao projected the report'")).firstMatch
        let middleText3 = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Zhao let the silence hold'")).firstMatch

        // At least one of the middle paragraphs should be visible
        let middleTextVisible = middleText1.exists || middleText2.exists || middleText3.exists

        // ASSERTIONS
        XCTAssertFalse(chapterTitleVisible,
                      "FAIL: Chapter 2 title is visible at top of screen. Scroll restoration did NOT work - reader is at top of chapter instead of middle.")

        XCTAssertTrue(middleTextVisible,
                     "PASS: Middle-chapter text is visible. Scroll restoration worked - reader opened to ~50% of Chapter 2.")

        // Additional verification: Check that we're in Chapter 2 at all
        // (The reader might show chapter number somewhere in the UI)
        let inChapterTwo = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Chapter 2'")).firstMatch.exists
        XCTAssertTrue(inChapterTwo, "Should be viewing Chapter 2")

        // Print debug info
        print("📖 Scroll Restoration Test Results:")
        print("   Chapter 2 title visible at top: \(chapterTitleVisible) (should be false)")
        print("   Middle paragraph text visible: \(middleTextVisible) (should be true)")
        print("   Test verdict: \(chapterTitleVisible ? "FAIL - at top" : "PASS - at middle")")
    }

    /// Fallback test: Verify scroll restoration works even if we can't find specific text
    /// This test just ensures the reader opens without crashing when there's saved progress
    func testScrollRestorationDoesNotCrash() throws {
        app.launch()

        // Wait for login screen
        sleep(3)

        let emailField = app.textFields.element(boundBy: 0)
        XCTAssertTrue(emailField.waitForExistence(timeout: 10))
        emailField.tap()
        emailField.typeText("debug-clone-1771698307241@mythweaver.app")

        let passwordField = app.secureTextFields.element(boundBy: 0)
        passwordField.tap()
        passwordField.typeText("299d06df151368a61ddc3f468186deb8")

        let signInButton = app.buttons["Sign In"]
        signInButton.tap()

        let libraryTitle = app.navigationBars["Your Library"]
        XCTAssertTrue(libraryTitle.waitForExistence(timeout: 10))

        // Tap any book (should be The Eighth Amendment)
        let bookButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'The Eighth Amendment'")).firstMatch
        if bookButton.waitForExistence(timeout: 5) {
            bookButton.tap()
        }

        // Reader should open without crashing
        sleep(2)

        // Verify we're in the reader (not crashed, not stuck in library)
        // The reader should have some chapter content visible
        let hasContent = app.staticTexts.containing(NSPredicate(format: "label.length > 50")).count > 0
        XCTAssertTrue(hasContent, "Reader should display chapter content without crashing")
    }
}
