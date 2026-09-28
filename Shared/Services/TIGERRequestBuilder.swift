//
//  TIGERRequestBuilder.swift
//  Lociq
//
//  Builds TIGERweb boundary query requests.
//
//  TIGERweb requests are ArcGIS REST layer queries. This builder keeps the URL
//  shape in one place so the boundary client can focus on layer selection,
//  validation, and caching.
//

import Foundation

/// Builds TIGERweb GeoJSON query URLs.
///
/// The builder requests WGS84 output geometry (`outSR=4326`) because the app's
/// projection layer expects longitude and latitude coordinates. It targets the
/// generalized boundary service for the configured data vintage: those outlines
/// are clipped to the shoreline, match the ACS release's geography, carry
/// `AREALAND` for density, and are several times smaller than legal boundaries.
nonisolated struct TIGERRequestBuilder: Sendable {
    /// TIGERweb map service root used for place layers.
    private let mapServerBaseURL: String

    /// Creates a request builder for one data vintage's generalized boundary service.
    init(vintage: CensusDataVintage = .current) {
        mapServerBaseURL = "https://tigerweb.geo.census.gov/arcgis/rest/services/\(vintage.boundaryServicePath)/MapServer"
    }

    /// Builds a TIGERweb layer query URL for a strict where clause and output field list.
    ///
    /// - Parameters:
    ///   - layerId: TIGERweb layer id, such as incorporated places or CDPs.
    ///   - whereClause: ArcGIS REST where clause built from validated FIPS codes.
    ///   - outFields: Comma-separated attributes to include in GeoJSON properties.
    /// - Returns: A URL that asks TIGERweb for GeoJSON geometry.
    /// - Throws: `CensusServiceError.invalidURL` if URL construction fails.
    func makeBoundaryURL(layerId: String, whereClause: String, outFields: String) throws -> URL {
        var components = URLComponents(string: "\(mapServerBaseURL)/\(layerId)/query")
        components?.queryItems = [
            .init(name: "where", value: whereClause),
            .init(name: "outFields", value: outFields),
            .init(name: "returnGeometry", value: "true"),
            .init(name: "outSR", value: "4326"),
            // Five decimal places (about 1 m) is far finer than the glyph can show.
            .init(name: "geometryPrecision", value: "5"),
            .init(name: "f", value: "geojson")
        ]

        guard let url = components?.url else { throw CensusServiceError.invalidURL }
        return url
    }
}
