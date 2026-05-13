//
//  LociqUITests.swift
//  LociqUITests
//

import XCTest

final class LociqUITests: XCTestCase {
    /// Configures each UI test to fail immediately on the first assertion failure.
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Verifies the minimal app shell reaches the foreground.
    @MainActor
    func testMinimalShellLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
