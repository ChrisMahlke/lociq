//
//  GeoJSONBoundaryRings.swift
//  Lociq
//
//  Extracts drawable exterior rings from GeoJSON boundary geometry.
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
//  LOC IQ renders the boundary as a small minimalist outline, not as a full
//  cartographic surface. For that purpose the renderer only needs exterior
//  rings. Interior rings are intentionally ignored because holes are rarely
//  legible at the tiny preview size and would add visual noise.
//

import Foundation

/// Provides ring extraction helpers for the boundary preview renderer.
///
/// The TIGER GeoJSON response can contain different geometry shapes depending
/// on the place. A simple city is commonly a `Polygon`, while cities with
/// disconnected pieces or islands can arrive as a `MultiPolygon`. This helper
/// normalizes both forms into a flat list of drawable exterior rings.
///
/// Each returned ring is an array of coordinate pairs in GeoJSON order:
/// longitude first, latitude second. Projection and scaling happen later in
/// `GeoJSONBoundaryPathBuilder`, so this type deliberately avoids doing any
/// coordinate math.
enum GeoJSONBoundaryRings {
    /// Extracts all drawable exterior rings from a feature collection.
    ///
    /// The feature collection can contain multiple features. Each feature may
    /// or may not have geometry. This method skips missing geometry, expands
    /// supported geometries into exterior rings, and removes invalid rings that
    /// cannot form a closed polygon outline.
    ///
    /// GeoJSON rings usually repeat the first coordinate at the end to close
    /// the shape, but the renderer should still receive at least three points.
    /// Rings with fewer points cannot describe an area, so they are discarded.
    ///
    /// - Parameter boundary: The decoded GeoJSON feature collection returned
    ///   by the TIGER boundary service.
    /// - Returns: A flat list of exterior rings ready for projection.
    nonisolated static func exteriorRings(from boundary: GeoJSONFeatureCollection) -> [[[Double]]] {
        boundary.features
            .compactMap(\.geometry)
            .flatMap(exteriorRings(from:))
            .filter { $0.count > 2 }
    }

    /// Extracts exterior rings from one supported GeoJSON geometry value.
    ///
    /// The extraction follows the GeoJSON polygon coordinate convention:
    ///
    /// * For `Polygon`, `rings.first` is the exterior boundary.
    /// * For `MultiPolygon`, each polygon's `first` ring is its exterior.
    /// * Unsupported geometry types do not contribute drawable boundaries.
    ///
    /// The method does not validate winding order. Boundary rendering uses a
    /// stroked path rather than filled polygon area, so clockwise versus
    /// counterclockwise winding is not significant here.
    ///
    /// - Parameter geometry: A decoded GeoJSON geometry value.
    /// - Returns: Exterior rings extracted from the geometry, or an empty array
    ///   when the geometry cannot be drawn by the boundary preview.
    nonisolated private static func exteriorRings(from geometry: GeoJSONGeometry) -> [[[Double]]] {
        switch geometry {
        case .polygon(let rings):
            // In GeoJSON, the first polygon ring is the exterior boundary.
            // Later rings describe holes and are intentionally omitted.
            return rings.first.map { [$0] } ?? []
        case .multiPolygon(let polygons):
            // A multipolygon is a collection of polygons. Preserve one exterior
            // ring per polygon so disconnected city pieces remain drawable.
            return polygons.compactMap(\.first)
        case .other:
            // Points, lines, and other unsupported geometry cannot produce the
            // closed city outline that the minimalist preview expects.
            return []
        }
    }
}
