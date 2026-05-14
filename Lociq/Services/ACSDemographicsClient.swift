//
//  ACSDemographicsClient.swift
//  Lociq
//
//  Fetches city-level ACS demographics from the U.S. Census API.
//

import Foundation

struct ACSDemographicsClient: Sendable {
    private let requestBuilder: ACSRequestBuilder
    private let httpClient: CensusHTTPClient

    /// Creates a Census ACS client for a specific dataset year and HTTP transport.
    init(censusApiKey: String, acsYear: Int, httpClient: CensusHTTPClient) {
        requestBuilder = ACSRequestBuilder(censusApiKey: censusApiKey, acsYear: acsYear)
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
        let url = try requestBuilder.makeURL(variables: variables, forQuery: forQuery, inQuery: inQuery)
        let data = try await httpClient.get(url)
        return try ACSTableResponse(data: data).valuesByKey()
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
