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
//  Persisted with cached profiles: add optional fields only.
//

import CoreLocation
import Foundation

/// GeoJSON feature collection returned by TIGERweb boundary requests.
///
/// The app treats this as a transport model. Projection, ring extraction, and
/// drawing are handled by support types so this model stays close to the JSON
/// response shape.
nonisolated struct GeoJSONFeatureCollection: Codable, Sendable {
    /// GeoJSON collection type, usually `"FeatureCollection"`.
    let type: String

    /// Features returned by TIGERweb for the requested Census place.
    let features: [GeoJSONFeature]

    /// First non-empty string value for a property across all features.
    func property(_ key: String) -> String? {
        features.lazy.compactMap { $0.properties?[key]?.stringValue }.first { !$0.isEmpty }
    }

    /// Census place GEOID (state FIPS + place FIPS), when present.
    var geoid: String? {
        property("GEOID")
    }

    /// Census land area in square meters (`AREALAND`), when present.
    var landAreaSquareMeters: Double? {
        property("AREALAND").flatMap(Double.init).flatMap { $0 > 0 ? $0 : nil }
    }

    /// Census internal point (`INTPTLAT`/`INTPTLON`), which lies inside the place.
    var internalPoint: CLLocationCoordinate2D? {
        guard
            let latitude = property("INTPTLAT").flatMap(Double.init),
            let longitude = property("INTPTLON").flatMap(Double.init),
            CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// One GeoJSON feature with scalar properties and optional geometry.
///
/// TIGERweb properties are not used for layout. They carry the identifiers and
/// land area the app needs, and are retained so cached boundaries stay faithful
/// to the response.
nonisolated struct GeoJSONFeature: Codable, Sendable {
    /// GeoJSON feature type, usually `"Feature"`.
    let type: String

    /// Optional TIGERweb attributes such as GEOID, NAME, and AREALAND.
    ///
    /// Values are decoded tolerantly: TIGERweb services return some attributes
    /// as strings in one release and as numbers in another.
    let properties: [String: GeoJSONPropertyValue]?

    /// Optional polygonal geometry to project and draw.
    let geometry: GeoJSONGeometry?
}

/// One scalar GeoJSON property value.
///
/// Profiles cached by earlier builds stored every property as a string or null,
/// and those payloads decode into `.string` and `.null` unchanged.
nonisolated enum GeoJSONPropertyValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    /// Decodes a string, number, boolean, or null without failing the whole feature.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else {
            // Nested arrays or objects are not used by the app.
            self = .null
        }
    }

    /// Encodes the value back into its JSON scalar form.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    /// String form of the value; whole numbers render without a fraction.
    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            guard value.isFinite else { return nil }
            if value == value.rounded(), abs(value) < 1e15 {
                return String(Int64(value))
            }
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .null:
            return nil
        }
    }
}

/// Supported GeoJSON geometry payloads used by the boundary renderer.
///
/// Only polygonal geometry can produce the minimalist city outline. Unsupported
/// geometry is represented by name so decoding does not fail when TIGERweb
/// returns an unexpected type.
nonisolated enum GeoJSONGeometry: Codable, Sendable {
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
