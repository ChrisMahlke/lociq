import Foundation
import Testing
@testable import Lociq

@MainActor
struct NeighborhoodShareCardExporterTests {
    @Test func rendersShareCardAssetWithPNGDataAndSummary() {
        let asset = NeighborhoodShareCardExporter.makeAsset(
            areaTitle: "San Francisco",
            areaSubtitle: "San Francisco County · ZIP 94107",
            boundaryScale: .zip,
            metricsSource: .zcta,
            metrics: CensusMetrics(
                population: 41_000,
                medianIncome: 120_000,
                medianAge: 36.4,
                households: 16_000,
                populationTrend: nil,
                ageBuckets: nil,
                educationLevels: nil,
                householdIncome: nil
            ),
            demographics: makeShareCardDemographics(),
            insights: [
                Insight(category: .mobility, severity: .positive, title: "Remote-work common", detail: "20.0% of workers report working from home."),
                Insight(category: .affordability, severity: .neutral, title: "Poverty rate", detail: "10.5% of people are below the poverty line (ACS estimate).")
            ]
        )

        #expect(asset != nil)
        #expect(asset?.summary.contains("San Francisco") == true)
        #expect(asset?.imageData.starts(with: Data([0x89, 0x50, 0x4E, 0x47])) == true)
    }

    @Test func rendersComparisonShareCardAssetWithPNGDataAndSummary() {
        let asset = ComparisonShareCardExporter.makeAsset(
            boundaryScale: .tract,
            primary: ComparablePlaceProfile(
                id: "primary",
                title: "San Francisco",
                subtitle: "San Francisco County · ZIP 94107",
                metrics: CensusMetrics(
                    population: 41_000,
                    medianIncome: 120_000,
                    medianAge: 36.4,
                    households: 16_000,
                    populationTrend: nil,
                    ageBuckets: nil,
                    educationLevels: nil,
                    householdIncome: nil
                ),
                demographics: makeShareCardDemographics(),
                metricsSource: .zcta
            ),
            secondary: ComparablePlaceProfile(
                id: "secondary",
                title: "Oakland",
                subtitle: "Alameda County · ZIP 94607",
                metrics: CensusMetrics(
                    population: 30_000,
                    medianIncome: 92_000,
                    medianAge: 35.1,
                    households: 12_000,
                    populationTrend: nil,
                    ageBuckets: nil,
                    educationLevels: nil,
                    householdIncome: nil
                ),
                demographics: makeShareCardDemographics(),
                metricsSource: .tract
            )
        )

        #expect(asset != nil)
        #expect(asset?.summary.contains("San Francisco vs Oakland") == true)
        #expect(asset?.imageData.starts(with: Data([0x89, 0x50, 0x4E, 0x47])) == true)
    }
}

private func makeShareCardDemographics() -> Demographics {
    Demographics(
        name: "San Francisco",
        population: 41_000,
        medianHouseholdIncome: 120_000,
        medianAge: 36.4,
        housingUnits: 18_000,
        medianHomeValue: 1_100_000,
        medianGrossRent: 2_800,
        averageHouseholdSize: 2.4,
        ownerOccupied: 9_000,
        renterOccupied: 7_000,
        ownerOccupiedPct: 56,
        renterOccupiedPct: 44,
        workersTotal: 15_000,
        workersWfh: 3_000,
        workersWfhPct: 20,
        povertyUniverse: 38_000,
        povertyBelow: 4_000,
        povertyRatePct: 10.5,
        whiteAlone: 18_000,
        blackAlone: 2_000,
        asianAlone: 9_000,
        hispanicOrLatino: 6_000
    )
}
