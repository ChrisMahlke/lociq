//
//  ACSDemographicsClient.swift
//  Lociq
//
//  Fetches city-level ACS demographics from the U.S. Census API.
//

import Foundation

final class ACSDemographicsClient: @unchecked Sendable {
    private enum Constants {
        static let acsBasePath = "https://api.census.gov/data"
    }

    private let censusApiKey: String
    private let acsYear: Int
    private let httpClient: CensusHTTPClient

    /// Creates a Census ACS client for a specific dataset year and HTTP transport.
    nonisolated init(censusApiKey: String, acsYear: Int, httpClient: CensusHTTPClient) {
        self.censusApiKey = censusApiKey
        self.acsYear = acsYear
        self.httpClient = httpClient
    }

    /// Fetches city/place-level ACS demographics for an incorporated place or census-designated place.
    func fetchDemographics(place: PlaceInfo) async throws -> Demographics {
        guard
            let state = place.stateFIPS,
            let placeFIPS = place.placeFIPS,
            state.count == 2,
            placeFIPS.count == 5
        else {
            throw CensusServiceError.noDemographicsFound
        }

        return try await fetchACSDemographics(
            forQuery: "place:\(placeFIPS)",
            inQuery: "state:\(state)",
            fallbackName: place.name
        )
    }

    /// Fetches and normalizes ACS values for one geography query.
    private func fetchACSDemographics(
        forQuery: String,
        inQuery: String?,
        fallbackName: String
    ) async throws -> Demographics {
        let valuesByKey = try await fetchACSValues(forQuery: forQuery, inQuery: inQuery)

        return try ACSDemographicsMapper(
            valuesByKey: valuesByKey,
            fallbackName: fallbackName
        ).makeDemographics()
    }

    /// Fetches all requested ACS variables in API-sized chunks and merges the result rows.
    private func fetchACSValues(forQuery: String, inQuery: String?) async throws -> [String: String] {
        let chunks = ACSDemographicsVariableCatalog.extendedVariables.chunked(
            into: ACSDemographicsVariableCatalog.maxVariablesPerRequest
        )

        return try await withThrowingTaskGroup(of: [String: String].self) { group in
            for variables in chunks {
                group.addTask { [self] in
                    try await fetchACSValues(
                        variables: variables,
                        forQuery: forQuery,
                        inQuery: inQuery
                    )
                }
            }

            var mergedValues: [String: String] = [:]
            for try await values in group {
                mergedValues.merge(values) { existing, _ in existing }
            }

            guard !mergedValues.isEmpty else {
                throw CensusServiceError.noDemographicsFound
            }

            return mergedValues
        }
    }

    /// Fetches one chunk of ACS variables and returns values keyed by variable code.
    private func fetchACSValues(
        variables: [String],
        forQuery: String,
        inQuery: String?
    ) async throws -> [String: String] {
        let baseURL = "\(Constants.acsBasePath)/\(acsYear)/acs/acs5"
        var components = URLComponents(string: baseURL)
        var queryItems: [URLQueryItem] = [
            .init(name: "get", value: variables.joined(separator: ",")),
            .init(name: "for", value: forQuery)
        ]

        if let inQuery {
            queryItems.append(.init(name: "in", value: inQuery))
        }

        if !censusApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(.init(name: "key", value: censusApiKey))
        }

        components?.queryItems = queryItems
        guard let url = components?.url else { throw CensusServiceError.invalidURL }

        let data = try await httpClient.get(url)

        guard
            let top = try JSONSerialization.jsonObject(with: data) as? [[String]],
            top.count >= 2
        else {
            throw CensusServiceError.decodeFailed("Unexpected ACS response shape")
        }

        let header = top[0]
        let row = top[1]
        guard header.count == row.count else {
            throw CensusServiceError.decodeFailed("Header/row length mismatch")
        }

        return Dictionary(uniqueKeysWithValues: zip(header, row))
    }

}

private extension Array {
    /// Splits an array into contiguous chunks no larger than the supplied size.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }

        return stride(from: 0, to: count, by: size).map { startIndex in
            Array(self[startIndex..<Swift.min(startIndex + size, count)])
        }
    }
}
