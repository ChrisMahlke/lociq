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
/// projection layer expects longitude and latitude coordinates.
struct TIGERRequestBuilder: Sendable {
    /// Current TIGERweb map service root used for place layers.
    private let mapServerBaseURL = "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_Current/MapServer"

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
            .init(name: "f", value: "geojson")
        ]

        guard let url = components?.url else { throw CensusServiceError.invalidURL }
        return url
    }
}
