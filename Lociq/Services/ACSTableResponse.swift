//
//  ACSTableResponse.swift
//  Lociq
//
//  Decodes ACS tabular JSON into variable-keyed row values.
//
//  ACS returns arrays instead of keyed objects. The first row is a header, and
//  each later row contains values for one geography. LOC IQ requests one place
//  at a time, so the first data row is the only row consumed.
//

import Foundation

/// Represents the Census ACS table response shape returned as `[header, row]`.
///
/// This type validates the shape before the mapper sees the data. That keeps
/// parsing errors close to transport concerns and lets the mapper assume it has
/// a consistent key-value dictionary.
struct ACSTableResponse: Sendable {
    /// Header row containing ACS variable names and geography columns.
    let header: [String]

    /// First result row containing raw string values for the requested place.
    let row: [String]

    /// Decodes and validates the first ACS result row from raw response data.
    ///
    /// - Parameter data: Raw JSON data returned by the ACS API.
    /// - Throws: `CensusServiceError.decodeFailed` when the table is missing a
    ///   data row or when header and row lengths differ.
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
    ///
    /// Geography columns such as `state` and `place` are preserved in the
    /// dictionary, although the demographic mapper mostly consumes ACS variables
    /// plus `NAME`.
    func valuesByKey() -> [String: String] {
        Dictionary(uniqueKeysWithValues: zip(header, row))
    }
}
