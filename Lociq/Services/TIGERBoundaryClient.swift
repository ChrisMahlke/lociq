import Foundation

final class TIGERBoundaryClient: @unchecked Sendable {
    private typealias ServiceError = CensusZipDemographicsService.ServiceError

    private let httpClient: CensusHTTPClient
    private let incorporatedPlacesLayerId = "28"
    private let cdpLayerId = "30"
    private let tigerwebMapServerBaseURL = "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_Current/MapServer"

    nonisolated init(httpClient: CensusHTTPClient) {
        self.httpClient = httpClient
    }

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

        let layerId = place.type == .censusDesignatedPlace ? cdpLayerId : incorporatedPlacesLayerId
        return try? await fetchBoundaryGeoJSON(
            layerId: layerId,
            whereClause: "STATE='\(state)' AND PLACE='\(placeFIPS)'",
            outFields: "STATE,PLACE,GEOID,NAME"
        )
    }

    private func fetchBoundaryGeoJSON(layerId: String, whereClause: String, outFields: String) async throws -> GeoJSONFeatureCollection {
        var components = URLComponents(string: "\(tigerwebMapServerBaseURL)/\(layerId)/query")
        components?.queryItems = [
            .init(name: "where", value: whereClause),
            .init(name: "outFields", value: outFields),
            .init(name: "returnGeometry", value: "true"),
            .init(name: "outSR", value: "4326"),
            .init(name: "f", value: "geojson")
        ]

        guard let url = components?.url else { throw ServiceError.invalidURL }

        let data = try await httpClient.get(url)
        let featureCollection = try httpClient.decode(GeoJSONFeatureCollection.self, from: data)

        guard !featureCollection.features.isEmpty else {
            throw ServiceError.noBoundaryFound
        }

        return featureCollection
    }

    private func isValid(value: String, regex: String) -> Bool {
        value.range(of: regex, options: .regularExpression) != nil
    }
}
