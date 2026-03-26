//
//  SampleMetricsFactory.swift
//  Lociq
//
//  Deterministic fallback metric generation used when live census lookups are unavailable.
//

import Foundation

/// Produces stable, pseudo-randomized `CensusMetrics` seeded by a string value.
enum SampleMetricsFactory {
    /// Builds a reproducible metrics payload so the UI remains populated offline.
    static func make(seedString: String) -> CensusMetrics {
        let seed = abs(seedString.hashValue)

        /// Samples a value around a baseline and span using a deterministic seed/index pair.
        func sample(_ base: Double, _ span: Double, idx: Int) -> Double {
            let normalized = Double((seed ^ (idx * 1_234_567)) & 0xFFFF) / 65535.0
            return base + (normalized - 0.5) * span
        }

        let population = max(5_000, Int(sample(80_000, 30_000, idx: 1)))
        let medianIncome = max(30_000, Int(sample(120_000, 60_000, idx: 2)))
        let medianAge = max(20.0, sample(36.0, 10.0, idx: 3))
        let households = max(2_000, Int(sample(30_000, 15_000, idx: 4)))

        let trend: [CensusMetrics.YearValue] = SampleData.years.enumerated().map { i, year in
            let delta = Int(sample(Double(i) * 800.0, 600.0, idx: 10 + i))
            return .init(year: year, value: population - 2_000 + delta)
        }

        let age: [CensusMetrics.LabeledPercent] = SampleData.ageLabels.enumerated().map { i, l in
            .init(label: l, percent: max(4, min(35, sample(16, 14, idx: 20 + i))))
        }

        let education: [CensusMetrics.LabeledPercent] = SampleData.educationLabels.enumerated().map { i, l in
            .init(label: l, percent: max(8, min(40, sample(24, 20, idx: 30 + i))))
        }

        let income: [CensusMetrics.LabeledPercent] = SampleData.incomeLabels.enumerated().map { i, l in
            .init(label: l, percent: max(5, min(35, sample(20, 18, idx: 40 + i))))
        }

        return CensusMetrics(
            population: population,
            medianIncome: medianIncome,
            medianAge: medianAge,
            households: households,
            populationTrend: trend,
            ageBuckets: normalize(age),
            educationLevels: normalize(education),
            householdIncome: normalize(income)
        )
    }

    /// Normalizes a percentage distribution so all values sum to 100.
    private static func normalize(_ values: [CensusMetrics.LabeledPercent]) -> [CensusMetrics.LabeledPercent] {
        let total = values.reduce(0.0) { $0 + $1.percent }
        guard total > 0 else { return values }
        return values.map { .init(label: $0.label, percent: ($0.percent / total) * 100.0) }
    }
}
