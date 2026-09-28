//
//  LociqUITests.swift
//  LociqUITests
//
//  Verifies the app shell and its main states in UI automation.
//
//  Fixture launches (`--lociq-ui-fixture <name>`, Debug builds only) replace
//  Core Location and the Census services with canned data, so these tests run
//  without network, location permission, or the real cache.
//

import XCTest

/// UI tests for launch, the loaded profile, failure states, details, and large text.
final class LociqUITests: XCTestCase {
    /// Configures each UI test to fail immediately on the first assertion failure.
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The minimal app shell reaches the foreground.
    ///
    /// This catches launch-time crashes, bad asset catalog issues, and invalid
    /// Info.plist configuration.
    @MainActor
    func testMinimalShellLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    /// C8 #16: a fixture profile renders its title and metrics with no network.
    @MainActor
    func testFixtureProfileRendersOffline() throws {
        let app = launch(fixture: "cambridge")

        let title = app.staticTexts["demographics.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "CAMBRIDGE, MA")
        XCTAssertTrue(element(app, "metric.population").exists)
        XCTAssertTrue(element(app, "metric.education").exists)
        XCTAssertTrue(element(app, "boundary.density").exists)
        XCTAssertTrue(app.buttons["action.toggleDetails"].exists)
    }

    /// UX-004: an offline failure explains itself and offers Try Again.
    @MainActor
    func testOfflineFailureOffersTryAgain() throws {
        let app = launch(fixture: "offline")

        let title = app.staticTexts["demographics.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "OFFLINE")
        XCTAssertEqual(app.staticTexts["demographics.status"].label, "CHECK CONNECTION")
        XCTAssertTrue(app.buttons["action.retry"].exists)
    }

    /// GIS-007: outside every place, the county explains it and no retry is offered.
    @MainActor
    func testOutsideCityLimitsOffersNoRetry() throws {
        let app = launch(fixture: "outsideCityLimits")

        let title = app.staticTexts["demographics.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "OUTSIDE CITY LIMITS")
        XCTAssertEqual(app.staticTexts["demographics.status"].label, "MIDDLESEX COUNTY, MA")
        XCTAssertFalse(app.buttons["action.retry"].exists)
    }

    /// GIS-010: the details view names the source and carries the Census API notice.
    @MainActor
    func testDetailsShowSourceAndAppearance() throws {
        let app = launch(fixture: "cambridge")

        let toggle = app.buttons["action.toggleDetails"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.tap()

        let source = element(app, "details.source")
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertTrue(source.label.contains("not endorsed or certified by the Census Bureau"))
        XCTAssertTrue(element(app, "details.appearance").exists)
    }

    /// A11Y-002 / VIS-001: at the largest text size, every metric scrolls fully above the bottom bar.
    @MainActor
    func testLargeTextKeepsMetricsAboveBottomBar() throws {
        let app = launch(fixture: "cambridge", extraArguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])

        let title = app.staticTexts["demographics.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let toggle = app.buttons["action.toggleDetails"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))

        let education = element(app, "metric.education")
        for _ in 0..<8 where !(education.exists && education.frame.maxY <= toggle.frame.minY - 8) {
            app.swipeUp()
        }

        XCTAssertTrue(education.exists)
        XCTAssertLessThanOrEqual(education.frame.maxY, toggle.frame.minY - 8)
    }

    // MARK: - Helpers

    @MainActor
    private func launch(fixture: String, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--lociq-ui-fixture", fixture] + extraArguments
        app.launch()
        return app
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
