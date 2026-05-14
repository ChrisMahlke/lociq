//
//  TIGERRequestBuilder.swift
//  Lociq
//
//  Builds TIGERweb boundary query requests.
//

import Foundation

/// Builds TIGERweb GeoJSON query URLs.
struct TIGERRequestBuilder: Sendable {
    private let mapServerBaseURL = "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_Current/MapServer"

    /// Builds a TIGERweb layer query URL for a strict where clause and output field list.
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
