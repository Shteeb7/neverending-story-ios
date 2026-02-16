//
//  DebugUITests.swift
//  NeverendingStoryUITests
//
//  Debug test to see what UI elements exist
//

import XCTest

final class DebugUITests: XCTestCase {

    func testPrintAllUIElements() {
        let app = XCUIApplication()
        app.launch()

        // Wait for launch
        sleep(3)

        // Collect button info
        var buttonInfo = "BUTTONS (\(app.buttons.count) total):\n"
        for i in 0..<min(20, app.buttons.count) {
            let button = app.buttons.element(boundBy: i)
            buttonInfo += "  [\(i)] '\(button.label)'\n"
        }

        // Collect text field info
        var textFieldInfo = "TEXT FIELDS (\(app.textFields.count) total):\n"
        for i in 0..<app.textFields.count {
            let field = app.textFields.element(boundBy: i)
            textFieldInfo += "  [\(i)] placeholder='\(field.placeholderValue ?? "")'\n"
        }

        // Report findings as failure so we can see them
        XCTFail("\n\n=== UI ELEMENTS ON SCREEN ===\n\(buttonInfo)\n\(textFieldInfo)\n")
    }
}
