//
//  LociqIPadTests.swift
//  LociqUITests
//
//  Verifies the iPad layouts and the keyboard shortcuts.
//
//  Layout tests run only on iPad and skip on iPhone, which is portrait-only.
//  Each attaches a screenshot to the test result, for design review.
//

import XCTest

/// UI tests for the large and spread iPad compositions and the menu commands.
final class LociqIPadTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    /// iPad landscape: the details sit beside the summary, and the toggle is gone.
    @MainActor
    func testLandscapeShowsDetailsBesideSummary() throws {
        try requireIPad()
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launch(fixture: "cambridge")

        let title = app.staticTexts["demographics.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        // A spread needs 720 pt inside the safe area (status bar and home
        // indicator take about 44 pt); iPad mini in landscape is shorter.
        guard app.windows.firstMatch.frame.height >= 764 else {
            throw XCTSkip("This iPad's landscape window is too short for a spread.")
        }
        XCTAssertTrue(element(app, "metric.population").exists)
        XCTAssertTrue(element(app, "details.source").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "details.appearance").exists)
        XCTAssertFalse(app.buttons["action.toggleDetails"].exists)

        // The details column is right of the summary, and the title stays above both.
        let population = element(app, "metric.population")
        let source = element(app, "details.source")
        XCTAssertLessThan(population.frame.maxX, source.frame.minX)
        XCTAssertLessThan(title.frame.maxY, population.frame.minY)

        attachScreenshot(named: "iPad landscape spread")
    }

    /// iPad portrait: the scaled composition keeps the summary/details toggle.
    @MainActor
    func testPortraitKeepsDetailsToggle() throws {
        try requireIPad()
        XCUIDevice.shared.orientation = .portrait
        let app = launch(fixture: "cambridge")

        XCTAssertTrue(app.staticTexts["demographics.title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["action.toggleDetails"].exists)
        XCTAssertFalse(element(app, "details.source").exists)

        attachScreenshot(named: "iPad portrait")
    }

    /// ⌘2 shows the details and ⌘1 returns to the summary.
    @MainActor
    func testKeyboardShortcutsSwitchSummaryAndDetails() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launch(fixture: "cambridge")
        XCTAssertTrue(app.buttons["action.toggleDetails"].waitForExistence(timeout: 10))

        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(element(app, "details.source").waitForExistence(timeout: 5))

        app.typeKey("1", modifierFlags: .command)
        let population = element(app, "metric.population")
        XCTAssertTrue(population.waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "details.source").exists)
    }

    // MARK: - Helpers

    private func requireIPad() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("iPad layouts are tested on iPad simulators.")
        }
    }

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

    /// Keeps a full-screen screenshot with the test result.
    @MainActor
    private func attachScreenshot(named name: String) {
        // Let the boundary trace and marker reveal finish.
        Thread.sleep(forTimeInterval: 2.5)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
