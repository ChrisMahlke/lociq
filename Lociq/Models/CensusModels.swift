//
//  CensusModels.swift
//  Lociq
//
//  Shared domain models for census metrics, geographic boundaries, and lookup responses.
//

import Foundation

/// UI-facing metrics used by dashboard and chart components.
struct CensusMetrics: Decodable {
    /// Point in a time series with calendar year and value.
    struct YearValue: Codable { let year: String; let value: Int }

    /// Label/value pair for charted percentage breakdowns.
    struct LabeledPercent: Codable { let label: String; let percent: Double }

    let population: Int?
    let medianIncome: Int?
    let medianAge: Double?
    let households: Int?

    let populationTrend: [YearValue]?
    let ageBuckets: [LabeledPercent]?
    let educationLevels: [LabeledPercent]?
    let householdIncome: [LabeledPercent]?
}

/// Indicates the geography level used to source the active metrics payload.
enum MetricsSource { case zcta, tract, sample }

/// Result from FCC API containing resolved census identifiers for a point.
struct FCCBlockResponse: Decodable {
    struct Block: Decodable {
        let fips: String
    }

    struct County: Decodable {
        let name: String?
        let fips: String?
    }

    struct State: Decodable {
        let code: String?
    }

    let Block: Block?
    let County: County?
    let State: State?
}

/// Decodes either string or integer-valued attributes from ArcGIS responses.
enum StringOrInt: Decodable {
    case string(String)
    case int(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else {
            throw DecodingError.typeMismatch(
                StringOrInt.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected String or Int")
            )
        }
    }

    /// Returns a string representation for mixed-type attribute values.
    var asString: String {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        }
    }
}

// GeoJSON + neighborhood lookup + demographics models are defined in
// `Services/CensusZipDemographicsService.swift` and shared across the app.
