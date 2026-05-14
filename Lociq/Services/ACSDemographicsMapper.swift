//
//  ACSDemographicsMapper.swift
//  Lociq
//
//  Converts raw ACS response values into normalized demographic models.
//

import Foundation

struct ACSDemographicsMapper {
    private let valuesByKey: [String: String]
    private let fallbackName: String

    /// Creates a mapper for one ACS result row.
    init(valuesByKey: [String: String], fallbackName: String) {
        self.valuesByKey = valuesByKey
        self.fallbackName = fallbackName
    }

    /// Converts raw ACS string values into the app's compact demographic model.
    func makeDemographics() throws -> Demographics {
        guard intValue("B01003_001E") != nil else {
            throw CensusServiceError.noDemographicsFound
        }

        let owner = intValue("B25003_002E")
        let renter = intValue("B25003_003E")
        let occupancyTotal: Int? = {
            guard let owner, let renter else { return nil }
            return owner + renter
        }()

        let workersTotal = intValue("B08301_001E")
        let workersWfh = intValue("B08301_021E")
        let transitCommuters = intValue("B08301_010E")
        let aggregateCommuteMinutes = intValue("B08013_001E")
        let totalHousingUnits = intValue("B25002_001E")
        let vacantHousingUnits = intValue("B25002_003E")
        let totalAgeUniverse = intValue("B01001_001E")
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
    private func intValue(_ key: String) -> Int? {
        ACSValueNormalizer.int(valuesByKey[key])
    }

    /// Reads a non-negative decimal ACS estimate, treating sentinel values as unavailable.
    private func doubleValue(_ key: String) -> Double? {
        ACSValueNormalizer.double(valuesByKey[key])
    }

    /// Calculates a percentage when both numerator and denominator are available.
    private func percent(_ numerator: Int?, _ denominator: Int?) -> Double? {
        guard let numerator, let denominator, denominator > 0 else { return nil }
        return (Double(numerator) / Double(denominator)) * 100.0
    }

    /// Sums ACS estimates when at least one component is available.
    private func sum(_ keys: [String]) -> Int? {
        let values = keys.compactMap(intValue)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }
}

enum ACSValueNormalizer {
    private static let missingValueCodes: Set<Int> = [
        -222_222_222,
        -333_333_333,
        -555_555_555,
        -666_666_666,
        -777_777_777,
        -888_888_888,
        -999_999_999
    ]
    private static let missingStrings: Set<String> = ["", "N", "NA", "N/A", "NULL", "-"]

    /// Converts an ACS string into an integer while filtering missing-value sentinel codes.
    static func int(_ value: String?) -> Int? {
        guard let normalized = normalized(value), let intValue = Int(normalized) else { return nil }
        guard !missingValueCodes.contains(intValue), intValue >= 0 else { return nil }
        return intValue
    }

    /// Converts an ACS string into a decimal while filtering missing-value sentinel codes.
    static func double(_ value: String?) -> Double? {
        guard let normalized = normalized(value), let doubleValue = Double(normalized) else { return nil }
        guard doubleValue >= 0 else { return nil }
        if missingValueCodes.contains(Int(doubleValue.rounded(.towardZero))) { return nil }
        return doubleValue
    }

    /// Trims ACS text and filters string-level missing markers before numeric parsing.
    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return missingStrings.contains(trimmed.uppercased()) ? nil : trimmed
    }
}
