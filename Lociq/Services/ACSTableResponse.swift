//
//  ACSTableResponse.swift
//  Lociq
//
//  Decodes ACS tabular JSON into variable-keyed row values.
//

import Foundation

/// Represents the Census ACS table response shape returned as `[header, row]`.
struct ACSTableResponse: Sendable {
    let header: [String]
    let row: [String]

    /// Decodes and validates the first ACS result row from raw response data.
    init(data: Data) throws {
        let rows = try JSONDecoder().decode([[String]].self, from: data)
        guard rows.count >= 2 else {
            throw CensusServiceError.decodeFailed("Unexpected ACS response shape")
        }

        header = rows[0]
        row = rows[1]

        guard header.count == row.count else {
            throw CensusServiceError.decodeFailed("Header/row length mismatch")
        }
    }

    /// Returns the first ACS result row keyed by ACS variable code.
    func valuesByKey() -> [String: String] {
        Dictionary(uniqueKeysWithValues: zip(header, row))
    }
}
