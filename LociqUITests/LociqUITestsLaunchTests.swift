//
//  LociqUITestsLaunchTests.swift
//  LociqUITests
//
//  Captures launch screenshots for lightweight visual review.
//

import XCTest

private enum UITestStrings {
    static let launchScreenName = "Launch Screen"
}

final class LociqUITestsLaunchTests: XCTestCase {
    /// Configures each launch test to fail immediately on the first assertion failure.
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches the app and preserves a screenshot artifact for visual review.
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = UITestStrings.launchScreenName
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
