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
            inQuery: "state:\(state)+county:\(county)",
            fallbackName: AppStrings.Formats.tract(tractGeoid)
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
            "B08301_001E",
            "B08301_021E",
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
        let baseURL = "https://api.census.gov/data/\(acsYear)/acs/acs5"
        var components = URLComponents(string: baseURL)
        var queryItems: [URLQueryItem] = [
            .init(name: "get", value: acsExtendedVariables.joined(separator: ",")),
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

        return try makeDemographics(
            valuesByKey: Dictionary(uniqueKeysWithValues: zip(header, row)),
            fallbackName: fallbackName
        )
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
