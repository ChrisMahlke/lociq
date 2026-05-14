//
//  LociqUITestsLaunchTests.swift
//  LociqUITests
//
//  Captures launch screenshots for lightweight visual review.
//
//  Screenshot artifacts are useful for quick inspection of the minimal launch
//  state without adding automated visual diff infrastructure.
//

import XCTest

private enum UITestStrings {
    /// Attachment name used in Xcode's test report.
    static let launchScreenName = "Launch Screen"
}

/// Launch screenshot test for manual visual review.
final class LociqUITestsLaunchTests: XCTestCase {
    /// Configures each launch test to fail immediately on the first assertion failure.
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches the app and preserves a screenshot artifact for visual review.
    ///
    /// The test does not navigate because the first frame is the relevant visual
    /// regression target.
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = UITestStrings.launchScreenName
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
