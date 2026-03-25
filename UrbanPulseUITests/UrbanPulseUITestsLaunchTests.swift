//
//  UrbanPulseUITestsLaunchTests.swift
//  UrbanPulseUITests
//
//  Created by Chris Mahlke on 3/2/26.
//

import XCTest

private enum UITestStrings {
    static let launchScreenName = "Launch Screen"
}

final class UrbanPulseUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

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
