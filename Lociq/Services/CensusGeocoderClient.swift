import Foundation

struct CensusGeographiesBundle: Sendable {
    let zcta: String
    let county: CountyInfo?
    let tract: TractInfo?
    let place: PlaceInfo?
}

final class CensusGeocoderClient: @unchecked Sendable {
    private typealias ServiceError = CensusZipDemographicsService.ServiceError

    private let httpClient: CensusHTTPClient
    private let geocoderBenchmark = "Public_AR_Current"
    private let geocoderVintage = "Current_Current"
    private let zctaLayerId = "2"
    private let tractLayerId = "8"
    private let countyLayerId = "82"
    private let incorporatedPlacesLayerId = "28"
    private let cdpLayerId = "30"
    private let geocoderCoordinatesURL = "https://geocoding.geo.census.gov/geocoder/geographies/coordinates"

    nonisolated init(httpClient: CensusHTTPClient) {
        self.httpClient = httpClient
    }

    func fetchGeographiesFromCoordinate(latitude: Double, longitude: Double) async throws -> CensusGeographiesBundle {
        var components = URLComponents(string: geocoderCoordinatesURL)
        components?.queryItems = [
            .init(name: "x", value: String(longitude)),
            .init(name: "y", value: String(latitude)),
            .init(name: "benchmark", value: geocoderBenchmark),
            .init(name: "vintage", value: geocoderVintage),
            .init(
                name: "layers",
                value: [
                    zctaLayerId,
                    countyLayerId,
                    tractLayerId,
                    incorporatedPlacesLayerId,
                    cdpLayerId
                ].joined(separator: ",")
            ),
            .init(name: "format", value: "json")
        ]

        guard let url = components?.url else { throw ServiceError.invalidURL }

        let data = try await httpClient.get(url)
        let decoded = try httpClient.decode(CensusGeocoderResponse.self, from: data)

        return CensusGeographiesBundle(
            zcta: try extractZCTA(from: decoded),
            county: extractCountyInfo(from: decoded),
            tract: extractTractInfo(from: decoded),
            place: extractPlaceInfo(from: decoded)
        )
    }

    private func extractZCTA(from decoded: CensusGeocoderResponse) throws -> String {
        let zctaKey = "2020 Census ZIP Code Tabulation Areas"

        if let value = decoded.result?.geographies?[zctaKey]?.first?.ZCTA5, value.count == 5 {
            return value
        }

        if let geographies = decoded.result?.geographies {
            for (_, geos) in geographies {
                if let found = geos.first?.ZCTA5, found.count == 5 {
                    return found
                }
            }
        }

        throw ServiceError.noZCTAFound
    }

    private func extractCountyInfo(from decoded: CensusGeocoderResponse) -> CountyInfo? {
        guard let geographies = decoded.result?.geographies else { return nil }

        if let county = geographies["Counties"]?.first {
            return CountyInfo(
                name: county.NAME ?? county.BASENAME ?? "County",
                stateFIPS: county.STATE,
                countyFIPS: county.COUNTY,
                geoid: county.GEOID
            )
        }

        for (_, entries) in geographies {
            if let first = entries.first, first.COUNTY != nil {
                return CountyInfo(
                    name: first.NAME ?? first.BASENAME ?? "County",
                    stateFIPS: first.STATE,
                    countyFIPS: first.COUNTY,
                    geoid: first.GEOID
                )
            }
        }

        return nil
    }

    private func extractTractInfo(from decoded: CensusGeocoderResponse) -> TractInfo? {
        guard let geographies = decoded.result?.geographies else { return nil }

        if let tract = geographies["Census Tracts"]?.first {
            let geoid = tract.GEOID
            return TractInfo(
                name: tract.NAME ?? tract.BASENAME,
                geoid: geoid,
                stateFIPS: tract.STATE,
                countyFIPS: tract.COUNTY,
                tractCode: tract.TRACT ?? geoid.map { String($0.suffix(6)) }
            )
        }

        for (_, entries) in geographies {
            if let first = entries.first, let tract = first.TRACT {
                return TractInfo(
                    name: first.NAME ?? first.BASENAME,
                    geoid: first.GEOID,
                    stateFIPS: first.STATE,
                    countyFIPS: first.COUNTY,
                    tractCode: tract
                )
            }

            if let first = entries.first, let geoid = first.GEOID, geoid.count == 11 {
                return TractInfo(
                    name: first.NAME ?? first.BASENAME,
                    geoid: geoid,
                    stateFIPS: first.STATE,
                    countyFIPS: first.COUNTY,
                    tractCode: String(geoid.suffix(6))
                )
            }
        }

        return nil
    }

    private func extractPlaceInfo(from decoded: CensusGeocoderResponse) -> PlaceInfo? {
        guard let geographies = decoded.result?.geographies else { return nil }

        if let incorporated = geographies["Incorporated Places"]?.first,
           let name = incorporated.NAME ?? incorporated.BASENAME,
           !name.isEmpty {
            return PlaceInfo(
                name: name,
                stateFIPS: incorporated.STATE,
                placeFIPS: incorporated.PLACE,
                type: .incorporatedPlace
            )
        }

        if let cdp = geographies["Census Designated Places"]?.first,
           let name = cdp.NAME ?? cdp.BASENAME,
           !name.isEmpty {
            return PlaceInfo(
                name: name,
                stateFIPS: cdp.STATE,
                placeFIPS: cdp.PLACE,
                type: .censusDesignatedPlace
            )
        }

        for (_, entries) in geographies {
            if let first = entries.first,
               let name = first.NAME ?? first.BASENAME,
               !name.isEmpty,
               first.PLACE != nil {
                return PlaceInfo(
                    name: name,
                    stateFIPS: first.STATE,
                    placeFIPS: first.PLACE,
                    type: .unknown
                )
            }
        }

        return nil
    }
}

private struct CensusGeocoderResponse: Codable {
    let result: CensusGeocoderResult?
}

private struct CensusGeocoderResult: Codable {
    let geographies: [String: [CensusGeocoderGeography]]?
}

private struct CensusGeocoderGeography: Codable {
    let ZCTA5: String?
    let NAME: String?
    let BASENAME: String?
    let GEOID: String?
    let STATE: String?
    let COUNTY: String?
    let TRACT: String?
    let PLACE: String?
}
