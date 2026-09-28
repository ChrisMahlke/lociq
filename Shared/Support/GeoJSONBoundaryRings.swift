//
//  GeoJSONBoundaryRings.swift
//  Lociq
//
//  Extracts polygons, with their holes, from GeoJSON boundary geometry.
//
//  GeoJSON polygon coordinates are represented as nested arrays:
//
//  Polygon:
//      [
//          exteriorRing,
//          interiorHoleRing,
//          interiorHoleRing
//      ]
//
//  MultiPolygon:
//      [
//          [exteriorRing, interiorHoleRing],
//          [exteriorRing, interiorHoleRing]
//      ]
//
//  Holes matter even in a small glyph. A hole is usually another place entirely
//  surrounded by the city (San Fernando inside Los Angeles, Beech Grove inside
//  Indianapolis). The glyph fills with the even-odd rule, so keeping holes lets
//  those enclaves read as outside the city instead of being painted over.
//

import Foundation

/// One polygon of a boundary: an exterior ring plus zero or more holes.
///
/// Rings are arrays of coordinate pairs in GeoJSON order: longitude first,
/// latitude second.
nonisolated struct BoundaryPolygon: Sendable {
    /// Exterior ring.
    let exterior: [[Double]]

    /// Interior rings (holes), such as enclaves belonging to other places.
    let holes: [[[Double]]]
}

/// Provides polygon extraction helpers for the boundary renderer and containment checks.
///
/// A simple city is commonly a `Polygon`, while cities with disconnected pieces
/// or islands arrive as a `MultiPolygon`. This helper normalizes both forms into
/// a flat list of polygons. Projection happens later in
/// `GeoJSONBoundaryPathBuilder`, so this type does no coordinate math.
nonisolated enum GeoJSONBoundaryRings {
    /// Extracts every polygon, with its holes, from a feature collection.
    ///
    /// Features without geometry and rings with fewer than three points are
    /// skipped because they cannot describe an area.
    static func polygons(from boundary: GeoJSONFeatureCollection) -> [BoundaryPolygon] {
        boundary.features
            .compactMap(\.geometry)
            .flatMap(polygons(from:))
    }

    /// Extracts polygons from one supported GeoJSON geometry value.
    private static func polygons(from geometry: GeoJSONGeometry) -> [BoundaryPolygon] {
        switch geometry {
        case .polygon(let rings):
            return polygon(from: rings).map { [$0] } ?? []
        case .multiPolygon(let polygons):
            return polygons.compactMap(polygon(from:))
        case .other:
            // Points, lines, and other geometry cannot describe a place outline.
            return []
        }
    }

    /// Builds one polygon from GeoJSON rings, where the first ring is the exterior.
    private static func polygon(from rings: [[[Double]]]) -> BoundaryPolygon? {
        guard let exterior = rings.first, exterior.count > 2 else { return nil }
        return BoundaryPolygon(exterior: exterior, holes: rings.dropFirst().filter { $0.count > 2 })
    }
}
