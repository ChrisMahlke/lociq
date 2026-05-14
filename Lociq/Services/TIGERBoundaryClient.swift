//
//  TIGERBoundaryClient.swift
//  Lociq
//
//  Fetches city and place boundary GeoJSON from Census TIGERweb.
//
//  Boundary geometry is useful but not required for the core demographic
//  snapshot. The client therefore returns optional geometry and logs failures
//  instead of forcing every TIGER issue to fail the whole profile load.
//

import Foundation

/// Loads and memoizes TIGERweb GeoJSON boundaries for Census places.
///
/// The client supports incorporated places and census-designated places. Those
/// geographies live in different TIGERweb layers, so `PlaceInfo.PlaceType`
/// determines which layer is queried.
struct TIGERBoundaryClient: Sendable {
    /// Shared Census HTTP client.
    private let httpClient: CensusHTTPClient

    /// URL builder for TIGERweb layer queries.
    private let requestBuilder = TIGERRequestBuilder()

    /// TIGERweb layer id for incorporated places.
    private let incorporatedPlacesLayerId = "28"

    /// TIGERweb layer id for census-designated places.
    private let cdpLayerId = "30"

    /// Actor-backed in-memory cache keyed by state, place, and place type.
    private let boundaryCache = TIGERBoundaryCache()

    /// Creates a TIGERweb boundary client with an injectable HTTP transport.
    init(httpClient: CensusHTTPClient) {
        self.httpClient = httpClient
    }

    /// Fetches a GeoJSON boundary for the supplied incorporated place or CDP.
    ///
    /// Invalid or missing FIPS identifiers return `nil` immediately. This keeps
    /// malformed geography from becoming an unsafe query string and preserves
    /// the loader's partial-data behavior.
    func fetchPlaceBoundary(place: PlaceInfo?) async -> GeoJSONFeatureCollection? {
        guard
            let place,
            let state = place.stateFIPS,
            let placeFIPS = place.placeFIPS,
            isValid(value: state, regex: #"^\d{2}$"#),
            isValid(value: placeFIPS, regex: #"^\d{5}$"#)
        else {
            return nil
        }

        let cacheKey = TIGERBoundaryCacheKey(stateFIPS: state, placeFIPS: placeFIPS, type: place.type)
        if let cachedBoundary = await boundaryCache.boundary(for: cacheKey) {
            return cachedBoundary
        }

        let layerId = place.type == .censusDesignatedPlace ? cdpLayerId : incorporatedPlacesLayerId
        let boundary: GeoJSONFeatureCollection?
        do {
            boundary = try await fetchBoundaryGeoJSON(
                layerId: layerId,
                whereClause: "STATE='\(state)' AND PLACE='\(placeFIPS)'",
                outFields: "STATE,PLACE,GEOID,NAME"
            )
        } catch {
            LociqDiagnostics.cityProfilePartialLoadFailed(error, stage: "tiger-boundary")
            boundary = nil
        }

        if let boundary {
            await boundaryCache.store(boundary, for: cacheKey)
        }
        return boundary
    }

    /// Executes a TIGERweb query and decodes the returned GeoJSON feature collection.
    ///
    /// The method throws when TIGERweb returns an empty feature collection
    /// because an empty response is not drawable by the boundary preview.
    private func fetchBoundaryGeoJSON(layerId: String, whereClause: String, outFields: String) async throws -> GeoJSONFeatureCollection {
        let url = try requestBuilder.makeBoundaryURL(layerId: layerId, whereClause: whereClause, outFields: outFields)
        let data = try await httpClient.get(url)
        let featureCollection = try httpClient.decode(GeoJSONFeatureCollection.self, from: data)

        guard !featureCollection.features.isEmpty else {
            throw CensusServiceError.noBoundaryFound
        }

        return featureCollection
    }

    /// Validates a TIGERweb query component against a strict regular expression.
    ///
    /// The where clause is built from Census identifiers. Validating those
    /// identifiers before interpolation avoids sending malformed queries.
    private func isValid(value: String, regex: String) -> Bool {
        value.range(of: regex, options: .regularExpression) != nil
    }
}

/// Stable in-memory key for one TIGER boundary.
///
/// Place type is included because incorporated places and CDPs can share code
/// shapes across different TIGER layers.
nonisolated private struct TIGERBoundaryCacheKey: Hashable, Sendable {
    let stateFIPS: String
    let placeFIPS: String
    let type: PlaceInfo.PlaceType
}

/// Actor-isolated session cache for TIGER boundaries.
///
/// A user can receive multiple location updates in the same place. Caching the
/// GeoJSON avoids repeating the same TIGERweb query during one app session.
private actor TIGERBoundaryCache {
    private var boundaries: [TIGERBoundaryCacheKey: GeoJSONFeatureCollection] = [:]

    /// Returns a cached boundary for a stable Census place key.
    func boundary(for key: TIGERBoundaryCacheKey) -> GeoJSONFeatureCollection? {
        boundaries[key]
    }

    /// Stores a TIGERweb boundary for reuse across nearby coordinates in the same city.
    func store(_ boundary: GeoJSONFeatureCollection, for key: TIGERBoundaryCacheKey) {
        boundaries[key] = boundary
    }
}
