//
//  ACSRequestBuilder.swift
//  Lociq
//
//  Builds ACS API requests from semantic query components.
//
//  URL construction is isolated so the demographics client can work in terms of
//  variables and geography queries rather than string-concatenating Census URLs.
//

import Foundation

/// Builds ACS API URLs for one dataset year.
///
/// The builder only knows how to construct the request. It does not perform
/// networking and it does not know how variables map into domain fields.
struct ACSRequestBuilder: Sendable {
    /// Optional Census API key. Empty keys are omitted from the query string.
    private let censusApiKey: String

    /// ACS dataset year used in the URL path.
    private let acsYear: Int

    /// Root Census API path for tabular data.
    private let basePath = "https://api.census.gov/data"

    /// Creates a request builder for an ACS dataset year and optional API key.
    init(censusApiKey: String, acsYear: Int) {
        self.censusApiKey = censusApiKey
        self.acsYear = acsYear
    }

    /// Builds one ACS 5-year URL for a variable chunk and geography query.
    ///
    /// - Parameters:
    ///   - variables: ACS variable codes for the `get` parameter.
    ///   - forQuery: Census `for` geography expression, for example `place:11000`.
    ///   - inQuery: Optional Census `in` geography expression, for example `state:25`.
    /// - Returns: A valid ACS request URL.
    /// - Throws: `CensusServiceError.invalidURL` when URL components cannot
    ///   represent the requested query.
    func makeURL(variables: [String], forQuery: String, inQuery: String?) throws -> URL {
        let baseURL = "\(basePath)/\(acsYear)/acs/acs5"
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
        return url
    }
}
