enum CensusMetricsMapper {
    nonisolated static func metrics(from demographics: Demographics) -> CensusMetrics {
        CensusMetrics(
            population: demographics.population,
            medianIncome: demographics.medianHouseholdIncome,
            medianAge: demographics.medianAge,
            households: demographics.housingUnits,
            populationTrend: nil,
            ageBuckets: nil,
            educationLevels: nil,
            householdIncome: nil
        )
    }
}
