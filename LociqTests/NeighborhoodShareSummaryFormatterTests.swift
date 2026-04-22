import Testing
@testable import Lociq

struct NeighborhoodShareSummaryFormatterTests {
    @Test func includesAreaMetricsInsightsAndDataset() {
        let summary = NeighborhoodShareSummaryFormatter.makeSummary(
            areaTitle: "San Francisco",
            areaSubtitle: "San Francisco County · ZIP 94107 · Tract 022900",
            boundaryScale: .tract,
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
            demographics: makeShareDemographics(),
            insights: [
                Insight(category: .mobility, severity: .positive, title: "Remote-work common", detail: "20.0% of workers report working from home."),
                Insight(category: .affordability, severity: .neutral, title: "Poverty rate", detail: "10.5% of people are below the poverty line (ACS estimate)."),
                Insight(category: .housing, severity: .neutral, title: "Housing snapshot", detail: "This should be filtered.")
            ]
        )

        #expect(summary.contains(AppStrings.Labels.neighborhoodProfile))
        #expect(summary.contains("San Francisco County · ZIP 94107 · Tract 022900"))
        #expect(summary.contains("\(AppStrings.Labels.currentScale): \(BoundaryOverlayScale.tract.displayTitle)"))
        #expect(summary.contains(InsightsFormatting.dataSourceText(.zcta)))
        #expect(summary.contains("\(AppStrings.Metrics.population): \(InsightsFormatting.number(41_000))"))
        #expect(summary.contains("\(AppStrings.Metrics.medianIncome): \(InsightsFormatting.currency(120_000))"))
        #expect(summary.contains("\(AppStrings.Metrics.medianAge): 36.4"))
        #expect(summary.contains("\(AppStrings.Metrics.households): \(InsightsFormatting.number(16_000))"))
        #expect(summary.contains(AppStrings.Labels.insights))
        #expect(summary.contains("• Remote-work common: 20.0% of workers report working from home."))
        #expect(summary.contains("• Poverty rate: 10.5% of people are below the poverty line (ACS estimate)."))
        #expect(!summary.contains("Housing snapshot"))
        #expect(summary.contains("\(AppStrings.Labels.latestACSDataset): \(AppStrings.Release.latestACS5YearDataset)"))
    }

    @Test func omitsUnavailableMetricsAndInsightsSection() {
        let summary = NeighborhoodShareSummaryFormatter.makeSummary(
            areaTitle: "Fallback Area",
            areaSubtitle: "",
            boundaryScale: .zip,
            metricsSource: nil,
            metrics: CensusMetrics(
                population: 8_000,
                medianIncome: nil,
                medianAge: nil,
                households: nil,
                populationTrend: nil,
                ageBuckets: nil,
                educationLevels: nil,
                householdIncome: nil
            ),
            demographics: nil,
            insights: []
        )

        #expect(summary.contains("\(AppStrings.Metrics.population): \(InsightsFormatting.number(8_000))"))
        #expect(!summary.contains("\(AppStrings.Metrics.medianIncome):"))
        #expect(!summary.contains("\(AppStrings.Metrics.medianAge):"))
        #expect(!summary.contains("\(AppStrings.Metrics.households):"))
        #expect(!summary.contains("\n\(AppStrings.Labels.insights)\n"))
    }
}

private func makeShareDemographics() -> Demographics {
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
