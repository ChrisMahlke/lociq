import Foundation

final class CensusHTTPClient: @unchecked Sendable {
    private typealias ServiceError = CensusZipDemographicsService.ServiceError

    private let session: URLSession

    nonisolated init(session: URLSession) {
        self.session = session
    }

    func get(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.requestFailed(status: -1, bodySnippet: "Non-HTTP response")
        }

        guard (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
            throw ServiceError.requestFailed(status: http.statusCode, bodySnippet: String(snippet))
        }

        return data
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ServiceError.decodeFailed(error.localizedDescription)
        }
    }
}
