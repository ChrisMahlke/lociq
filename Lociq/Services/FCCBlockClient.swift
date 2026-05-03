import Foundation

final class FCCBlockClient: @unchecked Sendable {
    private typealias ServiceError = CensusZipDemographicsService.ServiceError

    private let httpClient: CensusHTTPClient

    nonisolated init(httpClient: CensusHTTPClient) {
        self.httpClient = httpClient
    }

    func fetchBlockFIPS(latitude: Double, longitude: Double) async throws -> String {
        var components = URLComponents(string: AppStrings.Network.fccCensusURL)
        components?.queryItems = [
            .init(name: AppStrings.QueryItems.latitude, value: String(latitude)),
            .init(name: AppStrings.QueryItems.longitude, value: String(longitude)),
            .init(name: AppStrings.QueryItems.responseFormat, value: AppStrings.Network.jsonFormat)
        ]

        guard let url = components?.url else { throw ServiceError.invalidURL }

        let data = try await httpClient.get(url)
        let decoded = try httpClient.decode(FCCBlockResponse.self, from: data)

        guard let fips = decoded.Block?.fips, !fips.isEmpty else {
            throw ServiceError.noBoundaryFound
        }

        return fips
    }
}
