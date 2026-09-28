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
nonisolated struct ACSTableResponse: Sendable {
    /// Header row containing ACS variable names and geography columns.
    let header: [String]

    /// First result row containing raw values for the requested place.
    ///
    /// Census documents `null` cells ("no data available for the requested
    /// geography"), and annotation columns are `null` for ordinary estimates,
    /// so a missing cell is kept as `nil` instead of failing the whole table.
    let row: [String?]

    /// Decodes and validates the first ACS result row from raw response data.
    ///
    /// - Parameter data: Raw JSON data returned by the ACS API.
    /// - Throws: `CensusServiceError.decodeFailed` when the table is missing a
    ///   data row or when header and row lengths differ.
    init(data: Data) throws {
        let rows: [[String?]]
        do {
            rows = try JSONDecoder().decode([[String?]].self, from: data)
        } catch {
            throw CensusServiceError.decodeFailed("Unexpected ACS response shape")
        }
        guard rows.count >= 2 else {
            throw CensusServiceError.decodeFailed("Unexpected ACS response shape")
        }

        header = rows[0].map { $0 ?? "" }
        row = rows[1]

        guard header.count == row.count else {
            throw CensusServiceError.decodeFailed("Header/row length mismatch")
        }
    }

    /// Returns the first ACS result row keyed by ACS variable code.
    ///
    /// Null cells are omitted, which the mapper treats as unavailable. A
    /// repeated column keeps its first value rather than trapping.
    func valuesByKey() -> [String: String] {
        let pairs = zip(header, row).compactMap { key, value in
            value.map { (key, $0) }
        }
        return Dictionary(pairs, uniquingKeysWith: { first, _ in first })
    }
}
