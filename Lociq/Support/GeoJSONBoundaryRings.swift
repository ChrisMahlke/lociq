//
//  GeoJSONBoundaryRings.swift
//  Lociq
//
//  Extracts drawable exterior rings from GeoJSON boundary geometry.
//

import Foundation

/// Extracts the exterior polygon rings the boundary renderer can draw.
enum GeoJSONBoundaryRings {
    /// Extracts exterior polygon rings from supported GeoJSON geometry types.
    nonisolated static func exteriorRings(from boundary: GeoJSONFeatureCollection) -> [[[Double]]] {
        boundary.features
            .compactMap(\.geometry)
            .flatMap(exteriorRings(from:))
            .filter { $0.count > 2 }
    }

    /// Extracts exterior polygon rings from one supported GeoJSON geometry.
    nonisolated private static func exteriorRings(from geometry: GeoJSONGeometry) -> [[[Double]]] {
        switch geometry {
        case .polygon(let rings):
            return rings.first.map { [$0] } ?? []
        case .multiPolygon(let polygons):
            return polygons.compactMap(\.first)
        case .other:
            return []
        }
    }
}
