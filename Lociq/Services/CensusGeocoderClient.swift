//
//  CensusGeocoderClient.swift
//  Lociq
//
//  Resolves device coordinates into Census county and place geography.
//
//  LOC IQ uses the Census geocoder as the bridge between Core Location and
//  Census identifiers. The app does not reverse geocode through Apple Maps for
//  the data pipeline because ACS and TIGER require Census FIPS identifiers.
//

import Foundation

/// County and place metadata returned from one Census geocoder lookup.
///
/// A coordinate can have a county without a place. LOC IQ needs the place when
/// loading city-level ACS data, but preserving county information helps with
/// fallback diagnostics and future expansion.
struct CensusGeographiesBundle: Sendable {
    /// County that contains the coordinate, when returned.
    let county: CountyInfo?

    /// Incorporated place or census-designated place that contains the coordinate.
    let place: PlaceInfo?
}

/// Client for the Census geocoder coordinates endpoint.
///
/// The request asks for three layers: counties, incorporated places, and census
/// designated places. The extraction logic prefers incorporated places, then
/// CDPs, then any place-like fallback the geocoder returns.
struct CensusGeocoderClient: Sendable {
    /// Shared Census HTTP client with retry and timeout behavior.
    private let httpClient: CensusHTTPClient

    /// Current public benchmark recommended by the Census geocoder.
    private let geocoderBenchmark = "Public_AR_Current"

    /// Current vintage paired with the public benchmark.
    private let geocoderVintage = "Current_Current"

    /// Census geocoder layer id for county features.
    private let countyLayerId = "82"

    /// Census geocoder layer id for incorporated places.
    private let incorporatedPlacesLayerId = "28"

    /// Census geocoder layer id for census-designated places.
    private let cdpLayerId = "30"

    /// Coordinates endpoint used to resolve WGS84 coordinates to Census layers.
    private let geocoderCoordinatesURL = "https://geocoding.geo.census.gov/geocoder/geographies/coordinates"

    /// Creates a Census geocoder client with an injectable HTTP transport.
    init(httpClient: CensusHTTPClient) {
        self.httpClient = httpClient
    }

    /// Resolves county and place geographies for a latitude/longitude coordinate.
    ///
    /// Longitude is sent as `x` and latitude as `y`, matching the Census
    /// geocoder API. The method returns normalized domain metadata rather than
    /// exposing the raw layer dictionary.
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

        guard let url = components?.url else { throw CensusServiceError.invalidURL }

        let data = try await httpClient.get(url)
        let decoded = try httpClient.decode(CensusGeocoderResponse.self, from: data)

        return CensusGeographiesBundle(
            county: extractCountyInfo(from: decoded),
            place: extractPlaceInfo(from: decoded)
        )
    }

    /// Extracts the best county match from a Census geocoder response.
    ///
    /// The expected key is `Counties`, but the method also scans all returned
    /// layers for a record with a county code. This makes the client resilient
    /// to small response-shape differences from the geocoder service.
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

    /// Extracts the best incorporated-place or CDP match from a Census geocoder response.
    ///
    /// Incorporated places win over CDPs because they usually represent the
    /// municipal identity users expect. CDPs are still valid city-level Census
    /// places and are used when no incorporated place contains the coordinate.
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

/// Minimal top-level Census geocoder response shape.
private struct CensusGeocoderResponse: Codable {
    let result: CensusGeocoderResult?
}

/// Container for returned geography layers keyed by Census layer name.
private struct CensusGeocoderResult: Codable {
    let geographies: [String: [CensusGeocoderGeography]]?
}

/// One geography record from a Census geocoder layer.
///
/// The property names intentionally match the Census payload. They are kept
/// uppercase here so decoding can use synthesized `Codable` conformance without
/// custom key mapping.
private struct CensusGeocoderGeography: Codable {
    let NAME: String?
    let BASENAME: String?
    let GEOID: String?
    let STATE: String?
    let COUNTY: String?
    let PLACE: String?
}
