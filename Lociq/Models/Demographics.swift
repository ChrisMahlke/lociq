//
//  Demographics.swift
//  Lociq
//
//  Defines normalized app-domain demographic models derived from ACS values.
//

import Foundation

/// Top-level city/place demographic aggregate consumed by the UI snapshot layer.
struct Demographics: Sendable {
    let name: String
    let population: PopulationDemographics
    let income: IncomeDemographics
    let age: AgeDemographics
    let housing: HousingDemographics
    let education: EducationDemographics
    let mobility: MobilityDemographics
    let poverty: PovertyDemographics
    let raceEthnicity: RaceEthnicityDemographics

    /// Creates a normalized ACS demographic aggregate used by the UI snapshot layer.
    init(
        name: String,
        population: PopulationDemographics,
        income: IncomeDemographics,
        age: AgeDemographics,
        housing: HousingDemographics,
        education: EducationDemographics,
        mobility: MobilityDemographics,
        poverty: PovertyDemographics,
        raceEthnicity: RaceEthnicityDemographics
    ) {
        self.name = name
        self.population = population
        self.income = income
        self.age = age
        self.housing = housing
        self.education = education
        self.mobility = mobility
        self.poverty = poverty
        self.raceEthnicity = raceEthnicity
    }
}

/// Population totals for the resolved city/place.
struct PopulationDemographics: Sendable {
    let total: Int?

    /// Creates population totals for the resolved city/place.
    init(total: Int?) {
        self.total = total
    }
}

/// Household income estimates for the resolved city/place.
struct IncomeDemographics: Sendable {
    let medianHousehold: Int?

    /// Creates household income estimates for the resolved city/place.
    init(medianHousehold: Int?) {
        self.medianHousehold = medianHousehold
    }
}

/// Age distribution estimates for the resolved city/place.
struct AgeDemographics: Sendable {
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

/// Housing supply, tenure, vacancy, and cost estimates for the resolved city/place.
struct HousingDemographics: Sendable {
    let units: Int?
    let medianHomeValue: Int?
    let medianGrossRent: Int?
    let averageHouseholdSize: Double?
    let ownerOccupied: Int?
    let renterOccupied: Int?
    let ownerOccupiedPct: Double?
    let renterOccupiedPct: Double?
    let vacantUnits: Int?
    let vacancyRatePct: Double?

    /// Creates housing supply, tenure, vacancy, and cost estimates for the resolved city/place.
    init(
        units: Int?,
        medianHomeValue: Int?,
        medianGrossRent: Int?,
        averageHouseholdSize: Double?,
        ownerOccupied: Int?,
        renterOccupied: Int?,
        ownerOccupiedPct: Double?,
        renterOccupiedPct: Double?,
        vacantUnits: Int?,
        vacancyRatePct: Double?
    ) {
        self.units = units
        self.medianHomeValue = medianHomeValue
        self.medianGrossRent = medianGrossRent
        self.averageHouseholdSize = averageHouseholdSize
        self.ownerOccupied = ownerOccupied
        self.renterOccupied = renterOccupied
        self.ownerOccupiedPct = ownerOccupiedPct
        self.renterOccupiedPct = renterOccupiedPct
        self.vacantUnits = vacantUnits
        self.vacancyRatePct = vacancyRatePct
    }
}

/// Educational attainment estimates for the resolved city/place.
struct EducationDemographics: Sendable {
    let bachelorsOrHigherPct: Double?

    /// Creates educational attainment estimates for the resolved city/place.
    init(bachelorsOrHigherPct: Double?) {
        self.bachelorsOrHigherPct = bachelorsOrHigherPct
    }
}

/// Commuting and work-location estimates for the resolved city/place.
struct MobilityDemographics: Sendable {
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

/// Poverty estimates for the resolved city/place.
struct PovertyDemographics: Sendable {
    let universe: Int?
    let below: Int?
    let ratePct: Double?

    /// Creates poverty estimates for the resolved city/place.
    init(universe: Int?, below: Int?, ratePct: Double?) {
        self.universe = universe
        self.below = below
        self.ratePct = ratePct
    }
}

/// Race and ethnicity estimates for the resolved city/place.
struct RaceEthnicityDemographics: Sendable {
    let whiteAlone: Int?
    let blackAlone: Int?
    let asianAlone: Int?
    let hispanicOrLatino: Int?

    /// Creates race and ethnicity estimates for the resolved city/place.
    init(whiteAlone: Int?, blackAlone: Int?, asianAlone: Int?, hispanicOrLatino: Int?) {
        self.whiteAlone = whiteAlone
        self.blackAlone = blackAlone
        self.asianAlone = asianAlone
        self.hispanicOrLatino = hispanicOrLatino
    }
}
