//
//  ACSDemographicsClient.swift
//  Lociq
//
//  Fetches city-level ACS demographics from the U.S. Census API.
//
//  ACS requests are table oriented. The client asks for named variable codes,
//  receives a header row plus a value row, then delegates semantic conversion
//  to `ACSDemographicsMapper`. The client owns HTTP concerns and request
//  chunking. It does not know how a variable should appear in the UI.
//

import Foundation

/// Loads ACS demographic estimates for one resolved Census place.
///
/// The ACS API limits how many variables can be requested at once. LOC IQ's
/// city profile needs more variables than fit comfortably in a single request,
/// so this client splits variables into chunks, fetches those chunks
/// concurrently, then merges the returned value dictionaries.
struct ACSDemographicsClient: Sendable {
    /// URL construction dependency for the configured ACS year and API key.
    private let requestBuilder: ACSRequestBuilder

    /// Shared HTTP transport with retry, timeout, and decode behavior.
    private let httpClient: CensusHTTPClient

    /// Creates a Census ACS client for a specific dataset year and HTTP transport.
    init(censusApiKey: String, acsYear: Int, httpClient: CensusHTTPClient) {
        requestBuilder = ACSRequestBuilder(censusApiKey: censusApiKey, acsYear: acsYear)
        self.httpClient = httpClient
    }

    /// Fetches city/place-level ACS demographics for an incorporated place or census-designated place.
    ///
    /// ACS place queries require a two-digit state FIPS and five-digit place
    /// FIPS. The method validates those identifiers before constructing a URL
    /// so malformed values do not become ambiguous network failures.
    ///
    /// - Parameter place: Resolved Census place metadata from the geocoder.
    /// - Returns: Normalized app-domain demographics for the place.
    /// - Throws: `CensusServiceError.noDemographicsFound` when the place cannot
    ///   be queried, or a transport/decode error from the Census HTTP client.
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
    ///
    /// The geography query is split into the `for` and optional `in` components
    /// used by the Census API. For a city or CDP this is typically
    /// `for=place:xxxxx` and `in=state:xx`.
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
    ///
    /// Chunk requests run in parallel because ACS variable chunks are
    /// independent. Merging favors the first value for a duplicate key. Duplicate
    /// keys are not expected in the catalog, but this makes the merge stable if
    /// a future variable list accidentally repeats a code.
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
    ///
    /// This is the smallest network unit in the ACS pipeline. The response
    /// remains raw string data here so sentinel handling and numeric conversion
    /// stay isolated in `ACSDemographicsMapper`.
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
    ///
    /// The ACS API can reject oversized `get=` parameter lists. Keeping chunking
    /// local to the client makes the variable catalog independent from request
    /// transport limits.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }

        return stride(from: 0, to: count, by: size).map { startIndex in
            Array(self[startIndex..<Swift.min(startIndex + size, count)])
        }
    }
}
