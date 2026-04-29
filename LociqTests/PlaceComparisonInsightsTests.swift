import Testing
@testable import Lociq

struct PlaceComparisonInsightsTests {
    @Test func buildsSummaryAndWhyDiffersCalloutsFromStrongSignals() {
        let presentation = PlaceComparisonInsightsBuilder.make(
            primary: makeProfile(
                id: "sf",
                title: "San Francisco",
                population: 41_000,
                income: 120_000,
                age: 39.4,
                households: 16_000,
                homeValue: 1_100_000,
                rent: 3_200,
                ownerOccupiedPct: 61,
                remoteWorkPct: 24,
                povertyPct: 7.2
            ),
            secondary: makeProfile(
                id: "oak",
                title: "Oakland",
                population: 32_000,
                income: 89_000,
                age: 31.1,
                households: 12_000,
                homeValue: 720_000,
                rent: 2_500,
                ownerOccupiedPct: 42,
                remoteWorkPct: 12,
                povertyPct: 13.4
            )
        )

        #expect(presentation.summary?.contains("Biggest gaps favor San Francisco") == true)
        #expect(presentation.summary?.contains(AppStrings.Labels.compareAffordabilitySummaryPhrase) == true)
        #expect(!presentation.callouts.isEmpty)
        #expect(presentation.callouts.map(\.title).contains(AppStrings.Labels.compareAffordabilityCalloutTitle))
        #expect(presentation.callouts.map(\.title).contains(AppStrings.Labels.compareAgeCalloutTitle))
    }

    @Test func includesDeltaTextAndLeaderInMetricRows() throws {
        let presentation = PlaceComparisonInsightsBuilder.make(
            primary: makeProfile(
                id: "a",
                title: "Primary",
                population: 50_000,
                income: 110_000,
                age: 36.0,
                households: 20_000,
                homeValue: 900_000,
                rent: 2_900,
                ownerOccupiedPct: 58,
                remoteWorkPct: 20,
                povertyPct: 8.0
            ),
            secondary: makeProfile(
                id: "b",
                title: "Secondary",
                population: 40_000,
                income: 90_000,
                age: 36.0,
                households: 18_000,
                homeValue: 850_000,
                rent: 2_700,
                ownerOccupiedPct: 50,
                remoteWorkPct: 20,
                povertyPct: 10.5
            )
        )

        let incomeRow = try #require(presentation.metricRows.first { $0.label == AppStrings.Metrics.medianIncome })
        #expect(incomeRow.deltaText == AppStrings.Formats.compareLeadsBy("Primary", InsightsFormatting.currency(20_000)))
        #expect(incomeRow.leadingSide == .primary)

        let remoteWorkRow = try #require(presentation.metricRows.first { $0.label == AppStrings.Labels.remoteWork })
        #expect(remoteWorkRow.deltaText == AppStrings.Labels.compareNearlySame)
        #expect(remoteWorkRow.leadingSide == .tied)
    }

    @Test func fallsBackToSimilarProfilesSummaryWhenNoSignalsClearThresholds() {
        let presentation = PlaceComparisonInsightsBuilder.make(
            primary: makeProfile(
                id: "a",
                title: "Primary",
                population: 40_000,
                income: 100_000,
                age: 35.2,
                households: 15_000,
                homeValue: 800_000,
                rent: 2_600,
                ownerOccupiedPct: 52,
                remoteWorkPct: 16,
                povertyPct: 9.5
            ),
            secondary: makeProfile(
                id: "b",
                title: "Secondary",
                population: 40_200,
                income: 101_000,
                age: 35.8,
                households: 15_200,
                homeValue: 820_000,
                rent: 2_650,
                ownerOccupiedPct: 53,
                remoteWorkPct: 17,
                povertyPct: 10.1
            )
        )

        #expect(presentation.summary == AppStrings.Labels.compareSimilarProfiles)
        #expect(presentation.callouts.isEmpty)
    }
}

private func makeProfile(
    id: String,
    title: String,
    population: Int,
    income: Int,
    age: Double,
    households: Int,
    homeValue: Int,
    rent: Int,
    ownerOccupiedPct: Double,
    remoteWorkPct: Double,
    povertyPct: Double
) -> ComparablePlaceProfile {
    ComparablePlaceProfile(
        id: id,
        title: title,
        subtitle: "\(title) County · ZIP 00000",
        metrics: CensusMetrics(
            population: population,
            medianIncome: income,
            medianAge: age,
            households: households,
            populationTrend: nil,
            ageBuckets: nil,
            educationLevels: nil,
            householdIncome: nil
        ),
        demographics: Demographics(
            name: title,
            population: population,
            medianHouseholdIncome: income,
            medianAge: age,
            housingUnits: households + 2_000,
            medianHomeValue: homeValue,
            medianGrossRent: rent,
            averageHouseholdSize: 2.5,
            ownerOccupied: Int(Double(households) * ownerOccupiedPct / 100),
            renterOccupied: Int(Double(households) * (100 - ownerOccupiedPct) / 100),
            ownerOccupiedPct: ownerOccupiedPct,
            renterOccupiedPct: 100 - ownerOccupiedPct,
            workersTotal: households,
            workersWfh: Int(Double(households) * remoteWorkPct / 100),
            workersWfhPct: remoteWorkPct,
            povertyUniverse: population,
            povertyBelow: Int(Double(population) * povertyPct / 100),
            povertyRatePct: povertyPct,
            whiteAlone: Int(Double(population) * 0.4),
            blackAlone: Int(Double(population) * 0.1),
            asianAlone: Int(Double(population) * 0.2),
            hispanicOrLatino: Int(Double(population) * 0.2)
        ),
        metricsSource: .tract
    )
}
