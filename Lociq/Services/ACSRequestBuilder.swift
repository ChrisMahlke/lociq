//
//  ACSRequestBuilder.swift
//  Lociq
//
//  Builds ACS API requests from semantic query components.
//

import Foundation

/// Builds ACS API URLs for one dataset year.
struct ACSRequestBuilder: Sendable {
    private let censusApiKey: String
    private let acsYear: Int
    private let basePath = "https://api.census.gov/data"

    /// Creates a request builder for an ACS dataset year and optional API key.
    init(censusApiKey: String, acsYear: Int) {
        self.censusApiKey = censusApiKey
        self.acsYear = acsYear
    }

    /// Builds one ACS 5-year URL for a variable chunk and geography query.
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
