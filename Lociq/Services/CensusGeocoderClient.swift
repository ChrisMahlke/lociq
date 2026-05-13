import Foundation

struct CensusGeographiesBundle: Sendable {
    let county: CountyInfo?
    let place: PlaceInfo?
}

final class CensusGeocoderClient: @unchecked Sendable {
    private typealias ServiceError = CensusCityProfileService.ServiceError

    private let httpClient: CensusHTTPClient
    private let geocoderBenchmark = "Public_AR_Current"
    private let geocoderVintage = "Current_Current"
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
                    countyLayerId,
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
            county: extractCountyInfo(from: decoded),
            place: extractPlaceInfo(from: decoded)
        )
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
    let NAME: String?
    let BASENAME: String?
    let GEOID: String?
    let STATE: String?
    let COUNTY: String?
    let PLACE: String?
}
