//
//  TIGERBoundaryClient.swift
//  Lociq
//
//  Fetches city and place boundary GeoJSON from Census TIGERweb.
//

import Foundation

struct TIGERBoundaryClient: Sendable {
    private let httpClient: CensusHTTPClient
    private let requestBuilder = TIGERRequestBuilder()
    private let incorporatedPlacesLayerId = "28"
    private let cdpLayerId = "30"
    private let boundaryCache = TIGERBoundaryCache()

    /// Creates a TIGERweb boundary client with an injectable HTTP transport.
    init(httpClient: CensusHTTPClient) {
        self.httpClient = httpClient
    }

    /// Fetches a GeoJSON boundary for the supplied incorporated place or CDP.
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
    private func isValid(value: String, regex: String) -> Bool {
        value.range(of: regex, options: .regularExpression) != nil
    }
}

nonisolated private struct TIGERBoundaryCacheKey: Hashable, Sendable {
    let stateFIPS: String
    let placeFIPS: String
    let type: PlaceInfo.PlaceType
}

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
