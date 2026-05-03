import Foundation

final class TIGERBoundaryClient: @unchecked Sendable {
    private typealias ServiceError = CensusZipDemographicsService.ServiceError

    private let httpClient: CensusHTTPClient
    private let zctaLayerId = "2"
    private let tractLayerId = "8"
    private let blockLayerId = "12"
    private let tigerwebMapServerBaseURL = "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_Current/MapServer"

    nonisolated init(httpClient: CensusHTTPClient) {
        self.httpClient = httpClient
    }

    func fetchZCTABoundaryGeoJSON(zcta: String) async throws -> GeoJSONFeatureCollection {
        guard isValid(value: zcta, regex: AppStrings.Validation.zipRegex) else {
            throw ServiceError.noBoundaryFound
        }

        return try await fetchBoundaryGeoJSON(
            layerId: zctaLayerId,
            whereClause: "ZCTA5='\(zcta)'",
            outFields: "ZCTA5,GEOID,NAME"
        )
    }

    func fetchTractBoundary(tractGeoid: String?) async -> GeoJSONFeatureCollection? {
        guard let tractGeoid, isValid(value: tractGeoid, regex: AppStrings.Validation.tractRegex) else {
            return nil
        }

        return try? await fetchBoundaryGeoJSON(
            layerId: tractLayerId,
            whereClause: "GEOID='\(tractGeoid)'",
            outFields: "GEOID,NAME"
        )
    }

    func fetchBlockBoundary(blockFIPS: String?) async -> GeoJSONFeatureCollection? {
        guard
            let blockFIPS,
            blockFIPS.count == 15,
            isValid(value: blockFIPS, regex: AppStrings.Validation.blockRegex)
        else {
            return nil
        }

        return try? await fetchBoundaryGeoJSON(
            layerId: blockLayerId,
            whereClause: "GEOID='\(blockFIPS)'",
            outFields: "GEOID,NAME"
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
