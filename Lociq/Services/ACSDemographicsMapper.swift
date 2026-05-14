//
//  ACSDemographicsMapper.swift
//  Lociq
//
//  Converts raw ACS response values into normalized demographic models.
//
//  The mapper is the only layer that understands ACS variable semantics. It
//  converts table codes such as `B01003_001E` into domain properties such as
//  total population, median rent, or age distribution. Keeping that knowledge
//  here prevents Census variable codes from leaking into views or domain models.
//

import Foundation

/// Converts one ACS value dictionary into the app's demographic aggregate.
///
/// ACS returns every value as text. Some values are direct estimates, while
/// others need to be summed across age bands or divided by a universe to become
/// percentages. This mapper performs those derivations and filters missing or
/// suppressed ACS sentinel values through `ACSValueNormalizer`.
struct ACSDemographicsMapper {
    /// Raw ACS values keyed by variable code, plus `NAME`.
    private let valuesByKey: [String: String]

    /// Place name from geocoding used when ACS omits the `NAME` field.
    private let fallbackName: String

    /// Creates a mapper for one ACS result row.
    init(valuesByKey: [String: String], fallbackName: String) {
        self.valuesByKey = valuesByKey
        self.fallbackName = fallbackName
    }

    /// Converts raw ACS string values into the app's compact demographic model.
    ///
    /// `B01003_001E` is used as the minimum viability check because population
    /// is the anchor metric for the home screen. If it is unavailable after
    /// normalization, the row is treated as unusable for the product surface.
    ///
    /// - Returns: A normalized `Demographics` value grouped by product concepts.
    /// - Throws: `CensusServiceError.noDemographicsFound` when the row does not
    ///   contain enough usable ACS data.
    func makeDemographics() throws -> Demographics {
        guard intValue("B01003_001E") != nil else {
            throw CensusServiceError.noDemographicsFound
        }

        // Tenure is reported as separate owner and renter occupied counts. The
        // app computes the occupied housing universe from those two components
        // so percentages stay internally consistent.
        let owner = intValue("B25003_002E")
        let renter = intValue("B25003_003E")
        let occupancyTotal: Int? = {
            guard let owner, let renter else { return nil }
            return owner + renter
        }()

        // Mobility values are mostly commute mode counts. Average commute time
        // is derived from aggregate minutes divided by the worker universe.
        let workersTotal = intValue("B08301_001E")
        let workersWfh = intValue("B08301_021E")
        let transitCommuters = intValue("B08301_010E")
        let aggregateCommuteMinutes = intValue("B08013_001E")
        let totalHousingUnits = intValue("B25002_001E")
        let vacantHousingUnits = intValue("B25002_003E")
        let totalAgeUniverse = intValue("B01001_001E")
        // Age distribution is built from Census sex-by-age bands. The UI only
        // needs broad age buckets, so male and female bands are combined.
        let under18 = sum([
            "B01001_003E", "B01001_004E", "B01001_005E", "B01001_006E",
            "B01001_027E", "B01001_028E", "B01001_029E", "B01001_030E"
        ])
        let age18To34 = sum([
            "B01001_007E", "B01001_008E", "B01001_009E", "B01001_010E", "B01001_011E", "B01001_012E",
            "B01001_031E", "B01001_032E", "B01001_033E", "B01001_034E", "B01001_035E", "B01001_036E"
        ])
        let age35To64 = sum([
            "B01001_013E", "B01001_014E", "B01001_015E", "B01001_016E", "B01001_017E", "B01001_018E", "B01001_019E",
            "B01001_037E", "B01001_038E", "B01001_039E", "B01001_040E", "B01001_041E", "B01001_042E", "B01001_043E"
        ])
        let age65Plus = sum([
            "B01001_020E", "B01001_021E", "B01001_022E", "B01001_023E", "B01001_024E", "B01001_025E",
            "B01001_044E", "B01001_045E", "B01001_046E", "B01001_047E", "B01001_048E", "B01001_049E"
        ])
        // Education and poverty percentages are computed against their ACS
        // table universes, not total population.
        let educationUniverse = intValue("B15003_001E")
        let bachelorsOrHigher = sum(["B15003_022E", "B15003_023E", "B15003_024E", "B15003_025E"])
        let povertyUniverse = intValue("B17001_001E")
        let povertyBelow = intValue("B17001_002E")

        return Demographics(
            name: valuesByKey["NAME"] ?? fallbackName,
            population: PopulationDemographics(total: intValue("B01003_001E")),
            income: IncomeDemographics(medianHousehold: intValue("B19013_001E")),
            age: AgeDemographics(
                median: doubleValue("B01002_001E"),
                under18Pct: percent(under18, totalAgeUniverse),
                age18To34Pct: percent(age18To34, totalAgeUniverse),
                age35To64Pct: percent(age35To64, totalAgeUniverse),
                age65PlusPct: percent(age65Plus, totalAgeUniverse)
            ),
            housing: HousingDemographics(
                units: intValue("B25001_001E"),
                medianHomeValue: intValue("B25077_001E"),
                medianGrossRent: intValue("B25064_001E"),
                averageHouseholdSize: doubleValue("B25010_001E"),
                ownerOccupied: owner,
                renterOccupied: renter,
                ownerOccupiedPct: percent(owner, occupancyTotal),
                renterOccupiedPct: percent(renter, occupancyTotal),
                vacantUnits: vacantHousingUnits,
                vacancyRatePct: percent(vacantHousingUnits, totalHousingUnits)
            ),
            education: EducationDemographics(
                bachelorsOrHigherPct: percent(bachelorsOrHigher, educationUniverse)
            ),
            mobility: MobilityDemographics(
                workersTotal: workersTotal,
                workersWfh: workersWfh,
                workersWfhPct: percent(workersWfh, workersTotal),
                transitCommuters: transitCommuters,
                transitCommutersPct: percent(transitCommuters, workersTotal),
                averageCommuteMinutes: {
                    guard let aggregateCommuteMinutes, let workersTotal, workersTotal > 0 else { return nil }
                    return Double(aggregateCommuteMinutes) / Double(workersTotal)
                }()
            ),
            poverty: PovertyDemographics(
                universe: povertyUniverse,
                below: povertyBelow,
                ratePct: percent(povertyBelow, povertyUniverse)
            ),
            raceEthnicity: RaceEthnicityDemographics(
                whiteAlone: intValue("B02001_002E"),
                blackAlone: intValue("B02001_003E"),
                asianAlone: intValue("B02001_005E"),
                hispanicOrLatino: intValue("B03003_003E")
            )
        )
    }

    /// Reads a non-negative integer ACS estimate, treating sentinel values as unavailable.
    ///
    /// ACS missing values can look numeric, so all parsing routes through the
    /// normalizer instead of using `Int(...)` directly.
    private func intValue(_ key: String) -> Int? {
        ACSValueNormalizer.int(valuesByKey[key])
    }

    /// Reads a non-negative decimal ACS estimate, treating sentinel values as unavailable.
    ///
    /// Decimal parsing is used for median age, average household size, and any
    /// future ACS variables that return fractional values.
    private func doubleValue(_ key: String) -> Double? {
        ACSValueNormalizer.double(valuesByKey[key])
    }

    /// Calculates a percentage when both numerator and denominator are available.
    ///
    /// Missing numerators, missing denominators, and zero denominators all
    /// produce `nil` so the UI can display unavailable values honestly.
    private func percent(_ numerator: Int?, _ denominator: Int?) -> Double? {
        guard let numerator, let denominator, denominator > 0 else { return nil }
        return (Double(numerator) / Double(denominator)) * 100.0
    }

    /// Sums ACS estimates when at least one component is available.
    ///
    /// Returning `nil` for an entirely unavailable group is important. Returning
    /// zero would falsely imply the estimate exists and is exactly zero.
    private func sum(_ keys: [String]) -> Int? {
        let values = keys.compactMap(intValue)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }
}

/// Normalizes ACS estimate strings before domain conversion.
///
/// The ACS API uses sentinel values for suppressed, unavailable, and not
/// applicable estimates. Many of those sentinels are negative numeric strings,
/// which means simple numeric parsing is not enough. This helper centralizes
/// that filtering so every demographic field behaves consistently.
enum ACSValueNormalizer {
    /// Numeric sentinel values documented by Census tables for missing estimates.
    private static let missingValueCodes: Set<Int> = [
        -222_222_222,
        -333_333_333,
        -555_555_555,
        -666_666_666,
        -777_777_777,
        -888_888_888,
        -999_999_999
    ]

    /// String markers that should be treated as unavailable before parsing.
    private static let missingStrings: Set<String> = ["", "N", "NA", "N/A", "NULL", "-"]

    /// Converts an ACS string into an integer while filtering missing-value sentinel codes.
    ///
    /// Negative values are rejected because LOC IQ only displays count, dollar,
    /// and universe fields where negative estimates would indicate missing or
    /// suppressed data rather than meaningful product data.
    static func int(_ value: String?) -> Int? {
        guard let normalized = normalized(value), let intValue = Int(normalized) else { return nil }
        guard !missingValueCodes.contains(intValue), intValue >= 0 else { return nil }
        return intValue
    }

    /// Converts an ACS string into a decimal while filtering missing-value sentinel codes.
    ///
    /// Sentinel checks are still applied after decimal parsing because some ACS
    /// values may arrive in decimal-compatible form.
    static func double(_ value: String?) -> Double? {
        guard let normalized = normalized(value), let doubleValue = Double(normalized) else { return nil }
        guard doubleValue >= 0 else { return nil }
        if missingValueCodes.contains(Int(doubleValue.rounded(.towardZero))) { return nil }
        return doubleValue
    }

    /// Trims ACS text and filters string-level missing markers before numeric parsing.
    ///
    /// This keeps whitespace and case differences from leaking into every
    /// numeric conversion path.
    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return missingStrings.contains(trimmed.uppercased()) ? nil : trimmed
    }
}
