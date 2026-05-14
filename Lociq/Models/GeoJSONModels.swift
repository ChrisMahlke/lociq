//
//  GeoJSONModels.swift
//  Lociq
//
//  Defines the minimal GeoJSON transport models needed for TIGER boundary drawing.
//
//  These models intentionally cover only the GeoJSON surface that LOC IQ needs:
//  feature collections with polygon and multipolygon geometry. TIGERweb can
//  return more geometry types, but unsupported types are preserved as `.other`
//  so decoding remains robust while the renderer can ignore them.
//

import Foundation

/// GeoJSON feature collection returned by TIGERweb boundary requests.
///
/// The app treats this as a transport model. Projection, ring extraction, and
/// drawing are handled by support types so this model stays close to the JSON
/// response shape.
struct GeoJSONFeatureCollection: Codable, Sendable {
    /// GeoJSON collection type, usually `"FeatureCollection"`.
    let type: String

    /// Features returned by TIGERweb for the requested Census place.
    let features: [GeoJSONFeature]
}

/// One GeoJSON feature with string-like properties and optional geometry.
///
/// TIGERweb properties are not used for layout, but they are retained so cached
/// boundaries remain faithful to the response and future diagnostics can inspect
/// Census identifiers when needed.
struct GeoJSONFeature: Codable, Sendable {
    /// GeoJSON feature type, usually `"Feature"`.
    let type: String

    /// Optional TIGERweb attributes such as state, place, GEOID, and name.
    let properties: [String: String?]?

    /// Optional polygonal geometry to project and draw.
    let geometry: GeoJSONGeometry?
}

/// Supported GeoJSON geometry payloads used by the boundary renderer.
///
/// Only polygonal geometry can produce the minimalist city outline. Unsupported
/// geometry is represented by name so decoding does not fail when TIGERweb
/// returns an unexpected type.
enum GeoJSONGeometry: Codable, Sendable {
    /// A single polygon represented as rings of `[longitude, latitude]` pairs.
    case polygon([[[Double]]])

    /// Multiple polygons, each represented as rings of coordinate pairs.
    case multiPolygon([[[[Double]]]])

    /// Any unsupported GeoJSON geometry type name.
    case other(String)

    private enum CodingKeys: String, CodingKey { case type, coordinates }

    /// Decodes supported GeoJSON geometry while preserving unsupported geometry types by name.
    ///
    /// The custom decoder is necessary because the `coordinates` nesting depth
    /// depends on the geometry `type` field.
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
    ///
    /// Encoding is used by the cache path. Unsupported geometries only encode
    /// their type because they were never drawable by the app.
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
