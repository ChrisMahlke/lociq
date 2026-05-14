//
//  GeoJSONModels.swift
//  Lociq
//
//  Defines the minimal GeoJSON transport models needed for TIGER boundary drawing.
//

import Foundation

/// GeoJSON feature collection returned by TIGERweb boundary requests.
struct GeoJSONFeatureCollection: Codable, Sendable {
    let type: String
    let features: [GeoJSONFeature]
}

/// One GeoJSON feature with string-like properties and optional geometry.
struct GeoJSONFeature: Codable, Sendable {
    let type: String
    let properties: [String: String?]?
    let geometry: GeoJSONGeometry?
}

/// Supported GeoJSON geometry payloads used by the boundary renderer.
enum GeoJSONGeometry: Codable, Sendable {
    case polygon([[[Double]]])
    case multiPolygon([[[[Double]]]])
    case other(String)

    private enum CodingKeys: String, CodingKey { case type, coordinates }

    /// Decodes supported GeoJSON geometry while preserving unsupported geometry types by name.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "Polygon":
            self = .polygon(try container.decode([[[Double]]].self, forKey: .coordinates))
        case "MultiPolygon":
            self = .multiPolygon(try container.decode([[[[Double]]]].self, forKey: .coordinates))
        default:
            self = .other(type)
        }
    }

    /// Encodes supported GeoJSON geometry back into standard GeoJSON shape.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .polygon(let coordinates):
            try container.encode("Polygon", forKey: .type)
            try container.encode(coordinates, forKey: .coordinates)
        case .multiPolygon(let coordinates):
            try container.encode("MultiPolygon", forKey: .type)
            try container.encode(coordinates, forKey: .coordinates)
        case .other(let type):
            try container.encode(type, forKey: .type)
        }
    }
}
