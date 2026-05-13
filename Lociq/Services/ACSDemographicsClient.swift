import Foundation

final class ACSDemographicsClient: @unchecked Sendable {
    private typealias ServiceError = CensusZipDemographicsService.ServiceError

    private let censusApiKey: String
    private let acsYear: Int
    private let httpClient: CensusHTTPClient

    nonisolated init(censusApiKey: String, acsYear: Int, httpClient: CensusHTTPClient) {
        self.censusApiKey = censusApiKey
        self.acsYear = acsYear
        self.httpClient = httpClient
    }

    func fetchDemographics(zcta: String) async throws -> Demographics {
        try await fetchACSDemographics(
            forQuery: "zip code tabulation area:\(zcta)",
            inQuery: nil,
            fallbackName: AppStrings.Formats.zip(zcta)
        )
    }

    func fetchDemographics(tractGeoid: String) async throws -> Demographics {
        let state = String(tractGeoid.prefix(2))
        let county = String(tractGeoid.dropFirst(2).prefix(3))
        let tract = String(tractGeoid.suffix(6))

        return try await fetchACSDemographics(
            forQuery: "tract:\(tract)",
            inQuery: "state:\(state) county:\(county)",
            fallbackName: AppStrings.Formats.tract(tractGeoid)
        )
    }

    func fetchDemographics(place: PlaceInfo) async throws -> Demographics {
        guard
            let state = place.stateFIPS,
            let placeFIPS = place.placeFIPS,
            state.count == 2,
            placeFIPS.count == 5
        else {
            throw ServiceError.noDemographicsFound
        }

        return try await fetchACSDemographics(
            forQuery: "place:\(placeFIPS)",
            inQuery: "state:\(state)",
            fallbackName: place.name
        )
    }

    func fetchDemographics(blockGroupGeoid: String) async throws -> Demographics {
        guard blockGroupGeoid.count >= 12 else {
            throw ServiceError.noDemographicsFound
        }

        let state = String(blockGroupGeoid.prefix(2))
        let county = String(blockGroupGeoid.dropFirst(2).prefix(3))
        let tract = String(blockGroupGeoid.dropFirst(5).prefix(6))
        let blockGroup = String(blockGroupGeoid.dropFirst(11).prefix(1))

        return try await fetchACSDemographics(
            forQuery: "block group:\(blockGroup)",
            inQuery: "state:\(state) county:\(county) tract:\(tract)",
            fallbackName: "Block Group \(blockGroupGeoid)"
        )
    }

    private var acsExtendedVariables: [String] {
        [
            "NAME",
            "B01003_001E",
            "B19013_001E",
            "B01002_001E",
            "B25001_001E",
            "B25077_001E",
            "B25064_001E",
            "B25010_001E",
            "B25003_002E",
            "B25003_003E",
            "B25002_001E",
            "B25002_003E",
            "B08301_001E",
            "B08301_010E",
            "B08301_021E",
            "B08013_001E",
            "B01001_001E",
            "B01001_003E",
            "B01001_004E",
            "B01001_005E",
            "B01001_006E",
            "B01001_007E",
            "B01001_008E",
            "B01001_009E",
            "B01001_010E",
            "B01001_011E",
            "B01001_012E",
            "B01001_013E",
            "B01001_014E",
            "B01001_015E",
            "B01001_016E",
            "B01001_017E",
            "B01001_018E",
            "B01001_019E",
            "B01001_020E",
            "B01001_021E",
            "B01001_022E",
            "B01001_023E",
            "B01001_024E",
            "B01001_025E",
            "B01001_027E",
            "B01001_028E",
            "B01001_029E",
            "B01001_030E",
            "B01001_031E",
            "B01001_032E",
            "B01001_033E",
            "B01001_034E",
            "B01001_035E",
            "B01001_036E",
            "B01001_037E",
            "B01001_038E",
            "B01001_039E",
            "B01001_040E",
            "B01001_041E",
            "B01001_042E",
            "B01001_043E",
            "B01001_044E",
            "B01001_045E",
            "B01001_046E",
            "B01001_047E",
            "B01001_048E",
            "B01001_049E",
            "B15003_001E",
            "B15003_022E",
            "B15003_023E",
            "B15003_024E",
            "B15003_025E",
            "B17001_001E",
            "B17001_002E",
            "B02001_002E",
            "B02001_003E",
            "B02001_005E",
            "B03003_003E"
        ]
    }

    private func fetchACSDemographics(
        forQuery: String,
        inQuery: String?,
        fallbackName: String
    ) async throws -> Demographics {
        let valuesByKey = try await fetchACSValues(forQuery: forQuery, inQuery: inQuery)

        return try makeDemographics(
            valuesByKey: valuesByKey,
            fallbackName: fallbackName
        )
    }

    private func fetchACSValues(forQuery: String, inQuery: String?) async throws -> [String: String] {
        var mergedValues: [String: String] = [:]

        for variables in acsExtendedVariables.chunked(into: 45) {
            let values = try await fetchACSValues(
                variables: variables,
                forQuery: forQuery,
                inQuery: inQuery
            )
            mergedValues.merge(values) { existing, _ in existing }
        }

        guard !mergedValues.isEmpty else {
            throw ServiceError.noDemographicsFound
        }

        return mergedValues
    }

    private func fetchACSValues(
        variables: [String],
        forQuery: String,
        inQuery: String?
    ) async throws -> [String: String] {
        let baseURL = "https://api.census.gov/data/\(acsYear)/acs/acs5"
        var components = URLComponents(string: baseURL)
        var queryItems: [URLQueryItem] = [
            .init(name: "get", value: variables.joined(separator: ",")),
            .init(name: "for", value: forQuery)
        ]

        if let inQuery {
            queryItems.append(.init(name: "in", value: inQuery))
        }

        if !censusApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(.init(name: "key", value: censusApiKey))
        }

        components?.queryItems = queryItems
        guard let url = components?.url else { throw ServiceError.invalidURL }

        let data = try await httpClient.get(url)

        guard
            let top = try JSONSerialization.jsonObject(with: data) as? [[String]],
            top.count >= 2
        else {
            throw ServiceError.decodeFailed("Unexpected ACS response shape")
        }

        let header = top[0]
        let row = top[1]
        guard header.count == row.count else {
            throw ServiceError.decodeFailed("Header/row length mismatch")
        }

        return Dictionary(uniqueKeysWithValues: zip(header, row))
    }

    private func makeDemographics(valuesByKey: [String: String], fallbackName: String) throws -> Demographics {
        func intValue(_ key: String) -> Int? {
            guard let value = valuesByKey[key], let intValue = Int(value) else { return nil }
            return intValue
        }

        func doubleValue(_ key: String) -> Double? {
            guard let value = valuesByKey[key], let doubleValue = Double(value) else { return nil }
            return doubleValue
        }

        func percent(_ numerator: Int?, _ denominator: Int?) -> Double? {
            guard let numerator, let denominator, denominator > 0 else { return nil }
            return (Double(numerator) / Double(denominator)) * 100.0
        }

        func sum(_ keys: [String]) -> Int? {
            let values = keys.compactMap(intValue)
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +)
        }

        guard valuesByKey["B01003_001E"] != nil else {
            throw ServiceError.noDemographicsFound
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
            population: intValue("B01003_001E"),
            medianHouseholdIncome: intValue("B19013_001E"),
            medianAge: doubleValue("B01002_001E"),
            housingUnits: intValue("B25001_001E"),
            medianHomeValue: intValue("B25077_001E"),
            medianGrossRent: intValue("B25064_001E"),
            averageHouseholdSize: doubleValue("B25010_001E"),
            ownerOccupied: owner,
            renterOccupied: renter,
            ownerOccupiedPct: percent(owner, occupancyTotal),
            renterOccupiedPct: percent(renter, occupancyTotal),
            workersTotal: workersTotal,
            workersWfh: workersWfh,
            workersWfhPct: percent(workersWfh, workersTotal),
            transitCommuters: transitCommuters,
            transitCommutersPct: percent(transitCommuters, workersTotal),
            averageCommuteMinutes: {
                guard let aggregateCommuteMinutes, let workersTotal, workersTotal > 0 else { return nil }
                return Double(aggregateCommuteMinutes) / Double(workersTotal)
            }(),
            vacantHousingUnits: vacantHousingUnits,
            vacancyRatePct: percent(vacantHousingUnits, totalHousingUnits),
            under18Pct: percent(under18, totalAgeUniverse),
            age18To34Pct: percent(age18To34, totalAgeUniverse),
            age35To64Pct: percent(age35To64, totalAgeUniverse),
            age65PlusPct: percent(age65Plus, totalAgeUniverse),
            bachelorsOrHigherPct: percent(bachelorsOrHigher, educationUniverse),
            povertyUniverse: povertyUniverse,
            povertyBelow: povertyBelow,
            povertyRatePct: percent(povertyBelow, povertyUniverse),
            whiteAlone: intValue("B02001_002E"),
            blackAlone: intValue("B02001_003E"),
            asianAlone: intValue("B02001_005E"),
            hispanicOrLatino: intValue("B03003_003E")
        )
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }

        return stride(from: 0, to: count, by: size).map { startIndex in
            Array(self[startIndex..<Swift.min(startIndex + size, count)])
        }
    }
}
