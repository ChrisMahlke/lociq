//
//  Demographics.swift
//  Lociq
//
//  Defines normalized app-domain demographic models derived from ACS values.
//

import Foundation

/// Top-level city/place demographic aggregate consumed by the UI snapshot layer.
///
/// This is an app-domain model, not the raw ACS response. The Census ACS API returns tabular JSON
/// values keyed by variable codes, and `ACSDemographicsMapper` is responsible for translating those
/// codes into these semantic groups. Optional values represent unavailable, suppressed, or missing
/// ACS estimates after normalization.
///
/// Only values the app displays are modeled. Add a field together with the feature that shows it.
nonisolated struct Demographics: Sendable {
    let name: String
    let population: PopulationDemographics
    let income: IncomeDemographics
    let age: AgeDemographics
    let housing: HousingDemographics
    let education: EducationDemographics
    let mobility: MobilityDemographics

    /// Creates a normalized ACS demographic aggregate used by the UI snapshot layer.
    init(
        name: String,
        population: PopulationDemographics,
        income: IncomeDemographics,
        age: AgeDemographics,
        housing: HousingDemographics,
        education: EducationDemographics,
        mobility: MobilityDemographics
    ) {
        self.name = name
        self.population = population
        self.income = income
        self.age = age
        self.housing = housing
        self.education = education
        self.mobility = mobility
    }
}

/// Marks a median that falls in an open-ended top or bottom interval.
///
/// ACS publishes such medians as the interval bound with a `+` or `-`
/// annotation, for example `250,000+`. The value is then a bound, not an
/// estimate, and must be displayed with its annotation.
nonisolated enum MedianBound: Sendable, Equatable {
    /// The median is at least the reported value (`250,000+`).
    case atLeast

    /// The median is at most the reported value (`2,500-`).
    case atMost
}

/// Population totals for the resolved city/place.
nonisolated struct PopulationDemographics: Sendable {
    let total: Int?

    /// Creates population totals for the resolved city/place.
    init(total: Int?) {
        self.total = total
    }
}

/// Household income estimates for the resolved city/place.
nonisolated struct IncomeDemographics: Sendable {
    let medianHousehold: Int?
    let medianHouseholdBound: MedianBound?

    /// Creates household income estimates for the resolved city/place.
    init(medianHousehold: Int?, medianHouseholdBound: MedianBound? = nil) {
        self.medianHousehold = medianHousehold
        self.medianHouseholdBound = medianHouseholdBound
    }
}

/// Age distribution estimates for the resolved city/place.
nonisolated struct AgeDemographics: Sendable {
    let median: Double?
    let under18Pct: Double?
    let age18To34Pct: Double?
    let age35To64Pct: Double?
    let age65PlusPct: Double?

    /// Creates age distribution estimates for the resolved city/place.
    init(
        median: Double?,
        under18Pct: Double?,
        age18To34Pct: Double?,
        age35To64Pct: Double?,
        age65PlusPct: Double?
    ) {
        self.median = median
        self.under18Pct = under18Pct
        self.age18To34Pct = age18To34Pct
        self.age35To64Pct = age35To64Pct
        self.age65PlusPct = age65PlusPct
    }
}

/// Housing tenure, vacancy, and cost estimates for the resolved city/place.
nonisolated struct HousingDemographics: Sendable {
    let medianHomeValue: Int?
    let medianHomeValueBound: MedianBound?
    let medianGrossRent: Int?
    let medianGrossRentBound: MedianBound?
    let ownerOccupied: Int?
    let renterOccupied: Int?
    let ownerOccupiedPct: Double?
    let totalUnits: Int?
    let vacantUnits: Int?
    let vacancyRatePct: Double?

    /// Creates housing tenure, vacancy, and cost estimates for the resolved city/place.
    init(
        medianHomeValue: Int?,
        medianHomeValueBound: MedianBound? = nil,
        medianGrossRent: Int?,
        medianGrossRentBound: MedianBound? = nil,
        ownerOccupied: Int?,
        renterOccupied: Int?,
        ownerOccupiedPct: Double?,
        totalUnits: Int?,
        vacantUnits: Int?,
        vacancyRatePct: Double?
    ) {
        self.medianHomeValue = medianHomeValue
        self.medianHomeValueBound = medianHomeValueBound
        self.medianGrossRent = medianGrossRent
        self.medianGrossRentBound = medianGrossRentBound
        self.ownerOccupied = ownerOccupied
        self.renterOccupied = renterOccupied
        self.ownerOccupiedPct = ownerOccupiedPct
        self.totalUnits = totalUnits
        self.vacantUnits = vacantUnits
        self.vacancyRatePct = vacancyRatePct
    }
}

/// Educational attainment estimates for the resolved city/place.
nonisolated struct EducationDemographics: Sendable {
    let bachelorsOrHigherPct: Double?

    /// Creates educational attainment estimates for the resolved city/place.
    init(bachelorsOrHigherPct: Double?) {
        self.bachelorsOrHigherPct = bachelorsOrHigherPct
    }
}

/// Commuting and work-location estimates for the resolved city/place.
nonisolated struct MobilityDemographics: Sendable {
    let workersTotal: Int?
    let workersWfh: Int?
    let workersWfhPct: Double?
    let transitCommuters: Int?
    let transitCommutersPct: Double?
    let averageCommuteMinutes: Double?

    /// Creates commuting and work-location estimates for the resolved city/place.
    init(
        workersTotal: Int?,
        workersWfh: Int?,
        workersWfhPct: Double?,
        transitCommuters: Int?,
        transitCommutersPct: Double?,
        averageCommuteMinutes: Double?
    ) {
        self.workersTotal = workersTotal
        self.workersWfh = workersWfh
        self.workersWfhPct = workersWfhPct
        self.transitCommuters = transitCommuters
        self.transitCommutersPct = transitCommutersPct
        self.averageCommuteMinutes = averageCommuteMinutes
    }
}
