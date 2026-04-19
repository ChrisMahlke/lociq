//
//  LociqUITests.swift
//  LociqUITests
//
//  Created by Chris Mahlke on 3/2/26.
//

import XCTest

final class LociqUITests: XCTestCase {

    private func makeApp(skippingOnboarding: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        if skippingOnboarding {
            app.launchArguments += ["UITEST_SKIP_ONBOARDING"]
        }
        return app
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testTabSwitchingShowsMoreScreenContent() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.buttons["Map"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 5))

        app.buttons["More"].tap()
        XCTAssertTrue(app.staticTexts["How Lociq works"].waitForExistence(timeout: 5))

        app.buttons["Map"].tap()
        XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            makeApp().launch()
        }
    }
}
