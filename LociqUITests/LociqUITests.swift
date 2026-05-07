//
//  LociqUITests.swift
//  LociqUITests
//
//  Created by Chris Mahlke on 3/2/26.
//

import XCTest

private enum UITestIDs {
    static let tabMap = "tab.map"
    static let tabGuide = "tab.guide"
    static let sidebarProfile = "sidebar.profile"
    static let sidebarGuide = "sidebar.guide"
    static let moreHeroTitle = "more.hero.title"
    static let onboardingPrimary = "onboarding.primary"
}

private struct LocaleLaunchConfiguration {
    let name: String
    let languageCode: String
    let localeIdentifier: String
}

final class LociqUITests: XCTestCase {

    private func makeApp(
        skippingOnboarding: Bool = true,
        languageCode: String? = nil,
        localeIdentifier: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_RESET_STATE"]
        if skippingOnboarding {
            app.launchArguments += ["UITEST_SKIP_ONBOARDING"]
        }
        if let languageCode {
            app.launchArguments += ["-AppleLanguages", "(\(languageCode))"]
        }
        if let localeIdentifier {
            app.launchArguments += ["-AppleLocale", localeIdentifier]
        }
        return app
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {}

    @MainActor
    func testTabSwitchingShowsMoreScreenContent() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(waitForMapControl(in: app, timeout: 5))
        XCTAssertTrue(waitForGuideControl(in: app, timeout: 5))

        openGuideScreen(in: app)
        XCTAssertTrue(waitForMoreHeroTitle(in: app, timeout: 5))

        openMapScreen(in: app)
        XCTAssertTrue(waitForGuideControl(in: app, timeout: 5))
    }

    @MainActor
    func testLocalizedGuideSnapshots() throws {
        let scenarios = [
            LocaleLaunchConfiguration(name: "German", languageCode: "de", localeIdentifier: "de_DE"),
            LocaleLaunchConfiguration(name: "FrenchCanadian", languageCode: "fr-CA", localeIdentifier: "fr_CA"),
            LocaleLaunchConfiguration(name: "Arabic", languageCode: "ar", localeIdentifier: "ar"),
            LocaleLaunchConfiguration(name: "TraditionalChinese", languageCode: "zh-Hant", localeIdentifier: "zh_Hant")
        ]

        for scenario in scenarios {
            let app = makeApp(
                skippingOnboarding: true,
                languageCode: scenario.languageCode,
                localeIdentifier: scenario.localeIdentifier
            )

            app.launch()
            XCTAssertTrue(waitForGuideControl(in: app, timeout: 5))

            addNamedScreenshot(from: app, name: "\(scenario.name)-Map")

            openGuideScreen(in: app)
            XCTAssertTrue(waitForMoreHeroTitle(in: app, timeout: 5))

            addNamedScreenshot(from: app, name: "\(scenario.name)-More")
            app.terminate()
        }
    }

    @MainActor
    func testLocalizedOnboardingSnapshots() throws {
        let scenarios = [
            LocaleLaunchConfiguration(name: "German", languageCode: "de", localeIdentifier: "de_DE"),
            LocaleLaunchConfiguration(name: "Arabic", languageCode: "ar", localeIdentifier: "ar"),
            LocaleLaunchConfiguration(name: "TraditionalChinese", languageCode: "zh-Hant", localeIdentifier: "zh_Hant")
        ]

        for scenario in scenarios {
            let app = makeApp(
                skippingOnboarding: false,
                languageCode: scenario.languageCode,
                localeIdentifier: scenario.localeIdentifier
            )

            app.launch()
            let primaryButton = app.buttons[UITestIDs.onboardingPrimary]
            XCTAssertTrue(primaryButton.waitForExistence(timeout: 5))

            addNamedScreenshot(from: app, name: "\(scenario.name)-Onboarding-Page1")

            primaryButton.tap()
            XCTAssertTrue(primaryButton.waitForExistence(timeout: 5))

            addNamedScreenshot(from: app, name: "\(scenario.name)-Onboarding-Page2")
            app.terminate()
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            makeApp().launch()
        }
    }

    private func waitForMapControl(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        app.buttons[UITestIDs.tabMap].waitForExistence(timeout: timeout)
            || app.buttons[UITestIDs.sidebarProfile].waitForExistence(timeout: timeout)
    }

    private func waitForGuideControl(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        app.buttons[UITestIDs.tabGuide].waitForExistence(timeout: timeout)
            || app.buttons[UITestIDs.sidebarGuide].waitForExistence(timeout: timeout)
    }

    private func waitForMoreHeroTitle(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        app.staticTexts[UITestIDs.moreHeroTitle].waitForExistence(timeout: timeout)
            || app.otherElements[UITestIDs.moreHeroTitle].waitForExistence(timeout: timeout)
    }

    private func openGuideScreen(in app: XCUIApplication) {
        if app.buttons[UITestIDs.tabGuide].waitForExistence(timeout: 2) {
            app.buttons[UITestIDs.tabGuide].tap()
            return
        }

        app.buttons[UITestIDs.sidebarGuide].tap()
    }

    private func openMapScreen(in app: XCUIApplication) {
        if app.buttons[UITestIDs.tabMap].waitForExistence(timeout: 2) {
            app.buttons[UITestIDs.tabMap].tap()
            return
        }

        app.buttons[UITestIDs.sidebarProfile].tap()
    }

    private func addNamedScreenshot(from app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
