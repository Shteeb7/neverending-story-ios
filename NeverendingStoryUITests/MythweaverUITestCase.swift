import XCTest

class MythweaverUITestCase: XCTestCase {
    var app: XCUIApplication!
    var testEmail: String!
    var testPassword: String!
    var testUserId: String?
    var testAccessToken: String?

    var preset: String? { return nil }
    var cloneSourceEmail: String? { return nil }

    override func setUpWithError() throws {
        continueAfterFailure = false
        let timestamp = Int(Date().timeIntervalSince1970)
        let testPrefix = String(describing: type(of: self)).prefix(20)
        testEmail = "test-\(testPrefix)-\(timestamp)@mythweaver.app"
        testPassword = "TestPassword123!"
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]

        // Seed state BEFORE launching app
        let expectation = XCTestExpectation(description: "Seeding complete")
        Task {
            do {
                switch preset {
                case "post-onboarding":
                    let r = try await TestFixtures.seedPostOnboarding(email: testEmail, password: testPassword)
                    testUserId = r.userId; testAccessToken = r.accessToken
                case "mid-story":
                    let r = try await TestFixtures.seedMidStory(email: testEmail, password: testPassword)
                    testUserId = r.userId; testAccessToken = r.accessToken
                case "end-of-book":
                    let r = try await TestFixtures.seedEndOfBook(email: testEmail, password: testPassword)
                    testUserId = r.userId; testAccessToken = r.accessToken
                case "multi-book":
                    let r = try await TestFixtures.seedMultiBook(email: testEmail, password: testPassword)
                    testUserId = r.userId; testAccessToken = r.accessToken
                case "minor-user":
                    let r = try await TestFixtures.seedMinorUser(email: testEmail, password: testPassword)
                    testUserId = r.userId; testAccessToken = r.accessToken
                case "clone-user":
                    guard let src = cloneSourceEmail else { XCTFail("clone-user needs cloneSourceEmail"); return }
                    let r = try await TestFixtures.seedCloneUser(email: testEmail, password: testPassword, sourceEmail: src)
                    testUserId = r.userId; testAccessToken = r.accessToken
                default:
                    let r = try await TestFixtures.seedFreshUser(email: testEmail, password: testPassword)
                    testUserId = r.userId; testAccessToken = r.accessToken
                }
            } catch { XCTFail("Seed failed: \(error)") }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 30.0)
        app.launch()
    }

    override func tearDownWithError() throws {
        let email = testEmail!
        let expectation = XCTestExpectation(description: "Cleanup")
        Task { await TestFixtures.cleanupTestUser(email: email); expectation.fulfill() }
        wait(for: [expectation], timeout: 10.0)
        app.terminate(); app = nil
    }

    func loginWithTestAccount() throws {
        let emailField = app.textFields.element(matching: .textField, identifier: "Email or username")
        XCTAssertTrue(emailField.waitForExistence(timeout: 15), "Login email field should appear")
        emailField.tap(); emailField.typeText(testEmail)
        let passwordField = app.secureTextFields.firstMatch
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap(); passwordField.typeText(testPassword)
        let signIn = app.buttons["Sign In"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()
        sleep(3)
    }

    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 10, message: String? = nil) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message ?? "Element didn't appear in \(timeout)s")
    }
}
