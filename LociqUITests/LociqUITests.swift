//
//  LociqUITests.swift
//  LociqUITests
//
//  Verifies the minimal app shell launches successfully in UI automation.
//
//  The UI test target is intentionally lightweight. Most behavior is covered by
//  unit tests because the app depends on location and public network services.
//

import XCTest

/// Smoke tests for launching the app under UI automation.
final class LociqUITests: XCTestCase {
    /// Configures each UI test to fail immediately on the first assertion failure.
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Verifies the minimal app shell reaches the foreground.
    ///
    /// This catches launch-time crashes, bad app icon or asset catalog issues,
    /// and invalid Info.plist configuration.
    @MainActor
    func testMinimalShellLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
