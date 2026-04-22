import SwiftUI
import XCTest
@testable import Lociq

@MainActor
final class LocalizedLayoutSnapshotTests: XCTestCase {
    private struct Scenario {
        let name: String
        let localeIdentifier: String
        let layoutDirection: LayoutDirection
    }

    private struct SnapshotCase {
        let name: String
        let size: CGSize
        let view: AnyView
    }

    func testRepresentativeLocalesRenderAcrossPhoneAndTabletLayouts() {
        let scenarios = [
            Scenario(name: "de", localeIdentifier: "de", layoutDirection: .leftToRight),
            Scenario(name: "fr-CA", localeIdentifier: "fr-CA", layoutDirection: .leftToRight),
            Scenario(name: "pt-BR", localeIdentifier: "pt-BR", layoutDirection: .leftToRight),
            Scenario(name: "zh-Hant", localeIdentifier: "zh-Hant", layoutDirection: .leftToRight),
            Scenario(name: "ar", localeIdentifier: "ar", layoutDirection: .rightToLeft)
        ]

        for scenario in scenarios {
            for snapshot in makeSnapshotCases() {
                assertSnapshot(snapshot, scenario: scenario)
            }
        }
    }

    private func makeSnapshotCases() -> [SnapshotCase] {
        let fixtures = SnapshotFixtures.make()

        return [
            SnapshotCase(
                name: "more-compact",
                size: CGSize(width: 320, height: 1400),
                view: AnyView(MoreScreen())
            ),
            SnapshotCase(
                name: "more-regular",
                size: CGSize(width: 834, height: 1194),
                view: AnyView(MoreScreen())
            ),
            SnapshotCase(
                name: "insights-compact",
                size: CGSize(width: 320, height: 960),
                view: AnyView(
                    InsightsSheetContent(
                        zipCode: fixtures.zipCode,
                        metrics: fixtures.metrics,
                        demographics: fixtures.demographics,
                        zipBundle: fixtures.zipBundle,
                        metricsSource: .tract,
                        hasActiveSelection: true,
                        isLoadingSelection: false,
                        boundaryScale: .constant(.tract),
                        sheetOffset: .constant(1000)
                    )
                )
            ),
            SnapshotCase(
                name: "insights-regular",
                size: CGSize(width: 420, height: 1100),
                view: AnyView(
                    InsightsSheetContent(
                        zipCode: fixtures.zipCode,
                        metrics: fixtures.metrics,
                        demographics: fixtures.demographics,
                        zipBundle: fixtures.zipBundle,
                        metricsSource: .tract,
                        hasActiveSelection: true,
                        isLoadingSelection: false,
                        boundaryScale: .constant(.tract),
                        sheetOffset: .constant(1000)
                    )
                )
            ),
            SnapshotCase(
                name: "bottom-ribbon-compact",
                size: CGSize(width: 320, height: 92),
                view: AnyView(BottomRibbon(selection: .constant(.more)))
            ),
            SnapshotCase(
                name: "onboarding-compact",
                size: CGSize(width: 320, height: 700),
                view: AnyView(OnboardingExperienceView(onDone: {}))
            ),
            SnapshotCase(
                name: "onboarding-regular",
                size: CGSize(width: 834, height: 1112),
                view: AnyView(OnboardingExperienceView(onDone: {}))
            )
        ]
    }

    private func assertSnapshot(_ snapshot: SnapshotCase, scenario: Scenario) {
        let configuredView = snapshot.view
            .environment(\.locale, Locale(identifier: scenario.localeIdentifier))
            .environment(\.layoutDirection, scenario.layoutDirection)
            .environment(\.sizeCategory, .large)
            .frame(width: snapshot.size.width, height: snapshot.size.height)
            .background(Color(.systemBackground))

        let hostingController = UIHostingController(rootView: configuredView)
        hostingController.view.frame = CGRect(origin: .zero, size: snapshot.size)
        hostingController.view.backgroundColor = UIColor.systemBackground
        hostingController.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        let image = UIGraphicsImageRenderer(size: snapshot.size).image { _ in
            hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
        }

        let attachment = XCTAttachment(image: image)
        attachment.name = "\(snapshot.name)-\(scenario.name)"
        attachment.lifetime = .keepAlways
        add(attachment)

        let truncatedTexts = collectTruncatedSingleLineLabels(from: hostingController.view)
        XCTAssertTrue(
            truncatedTexts.isEmpty,
            "Detected truncated single-line text in \(snapshot.name)-\(scenario.name): \(truncatedTexts.joined(separator: " | "))"
        )
    }

    private func collectTruncatedSingleLineLabels(from rootView: UIView) -> [String] {
        var labels: [String] = []

        func visit(_ view: UIView) {
            if let label = view as? UILabel,
               !label.isHidden,
               label.alpha > 0.01,
               label.numberOfLines == 1,
               label.bounds.width > 0,
               let text = label.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                let fittedSize = label.sizeThatFits(CGSize(width: .greatestFiniteMagnitude, height: label.bounds.height))
                if fittedSize.width > label.bounds.width + 1 {
                    labels.append(text)
                }
            }

            for subview in view.subviews {
                visit(subview)
            }
        }

        visit(rootView)
        return labels
    }
}

private enum SnapshotFixtures {
    struct FixtureBundle {
        let zipCode: String
        let metrics: CensusMetrics
        let demographics: Demographics
        let zipBundle: ZipLookupResult
    }

    static func make() -> FixtureBundle {
        let zipCode = "94110"
        let metrics = CensusMetrics(
            population: 72_814,
            medianIncome: 128_400,
            medianAge: 37.8,
            households: 28_912,
            populationTrend: nil,
            ageBuckets: nil,
            educationLevels: nil,
            householdIncome: nil
        )

        let demographics = Demographics(
            name: "Mission District",
            population: 72_814,
            medianHouseholdIncome: 128_400,
            medianAge: 37.8,
            housingUnits: 31_455,
            medianHomeValue: 1_245_000,
            medianGrossRent: 2_980,
            averageHouseholdSize: 2.6,
            ownerOccupied: 10_420,
            renterOccupied: 18_492,
            ownerOccupiedPct: 36.0,
            renterOccupiedPct: 64.0,
            workersTotal: 39_500,
            workersWfh: 9_875,
            workersWfhPct: 25.0,
            povertyUniverse: 69_000,
            povertyBelow: 7_590,
            povertyRatePct: 11.0,
            whiteAlone: 27_200,
            blackAlone: 3_650,
            asianAlone: 11_500,
            hispanicOrLatino: 28_900
        )

        let insights = [
            Insight(
                category: .affordability,
                severity: .caution,
                title: "High housing costs",
                detail: "Home values and rents both sit above many nearby ZIP-level comparisons."
            ),
            Insight(
                category: .mobility,
                severity: .positive,
                title: "Remote work remains common",
                detail: "A quarter of workers report working from home, which is relatively elevated for the city."
            ),
            Insight(
                category: .demographics,
                severity: .neutral,
                title: "Mixed household profile",
                detail: "The area combines dense renter activity with a broad spread of household types."
            )
        ]

        let zipBundle = ZipLookupResult(
            zcta: zipCode,
            county: CountyInfo(name: "San Francisco County", stateFIPS: "06", countyFIPS: "075", geoid: "06075"),
            tract: TractInfo(name: "Census Tract 0229.02", geoid: "06075022902", stateFIPS: "06", countyFIPS: "075", tractCode: "022902"),
            place: PlaceInfo(name: "San Francisco", stateFIPS: "06", placeFIPS: "67000", type: .incorporatedPlace),
            isIncorporatedPlace: true,
            boundary: GeoJSONFeatureCollection(type: "FeatureCollection", features: []),
            boundaryMetrics: nil,
            demographics: demographics,
            insights: insights
        )

        return FixtureBundle(zipCode: zipCode, metrics: metrics, demographics: demographics, zipBundle: zipBundle)
    }
}
