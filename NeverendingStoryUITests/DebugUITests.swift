//
//  DebugUITests.swift
//  NeverendingStoryUITests
//
//  Debug test to see what UI elements exist
//

import XCTest

final class DebugUITests: XCTestCase {

    func testPrintViewHierarchy() {
        let app = XCUIApplication()
        app.launch()

        // Wait for launch
        sleep(5)

        // Print full view hierarchy
        print("\n" + String(repeating: "=", count: 80))
        print("VIEW HIERARCHY:")
        print(String(repeating: "=", count: 80))
        print(app.debugDescription)
        print(String(repeating: "=", count: 80) + "\n")

        // Also collect specific elements
        print("\nBUTTONS (\(app.buttons.count) total):")
        for i in 0..<min(20, app.buttons.count) {
            let button = app.buttons.element(boundBy: i)
            print("  [\(i)] label='\(button.label)' exists=\(button.exists)")
        }

        print("\nTEXT FIELDS (\(app.textFields.count) total):")
        for i in 0..<app.textFields.count {
            let field = app.textFields.element(boundBy: i)
            print("  [\(i)] placeholder='\(field.placeholderValue ?? "N/A")' exists=\(field.exists)")
        }

        // This test should always pass - just for debugging
        XCTAssertTrue(app.exists)
    }
}
