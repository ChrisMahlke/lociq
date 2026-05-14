//
//  WebMercatorProjection.swift
//  Lociq
//
//  Projects longitude/latitude coordinates into normalized Web Mercator space.
//
//  The boundary preview is not a map, but it needs map-like orientation. Web
//  Mercator produces a north-up coordinate system compatible with the common
//  visual expectations users have from Google Maps and Apple Maps.
//

import CoreGraphics
import Foundation

/// Utility projection matching the north-up orientation used by common web map tiles.
///
/// Coordinates are returned in normalized world space, where x and y are
/// approximately in the range `0...1`. The boundary path builder later scales
/// those normalized points into a SwiftUI frame.
enum WebMercatorProjection {
    /// Finds the normalized Web Mercator bounds for a collection of exterior rings.
    ///
    /// Invalid coordinates are skipped rather than failing the entire boundary.
    /// Returning `nil` means no coordinate in the supplied rings could be
    /// projected.
    ///
    /// - Parameter rings: Exterior rings in GeoJSON `[longitude, latitude]` order.
    /// - Returns: Projected bounding rectangle in normalized world coordinates.
    nonisolated static func projectedBounds(for rings: [[[Double]]]) -> CGRect? {
        var minX = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var minY = CGFloat.infinity
        var maxY = -CGFloat.infinity
        var didProjectAnyPoint = false

        for ring in rings {
            for coordinate in ring where coordinate.count >= 2 {
                guard let projectedPoint = worldPoint(longitude: coordinate[0], latitude: coordinate[1]) else {
                    continue
                }
                minX = min(minX, projectedPoint.x)
                maxX = max(maxX, projectedPoint.x)
                minY = min(minY, projectedPoint.y)
                maxY = max(maxY, projectedPoint.y)
                didProjectAnyPoint = true
            }
        }

        guard didProjectAnyPoint else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Converts a coordinate into normalized Web Mercator world coordinates.
    ///
    /// Latitude is clamped to the Web Mercator practical limit because the
    /// projection approaches infinity near the poles. U.S. Census place data
    /// will not normally hit those limits, but clamping keeps the helper safe.
    ///
    /// - Parameters:
    ///   - longitude: WGS84 longitude in degrees.
    ///   - latitude: WGS84 latitude in degrees.
    /// - Returns: Normalized Web Mercator point, or `nil` for non-finite input.
    nonisolated static func worldPoint(longitude: Double, latitude: Double) -> CGPoint? {
        guard longitude.isFinite, latitude.isFinite else { return nil }
        let clampedLatitude = min(max(latitude, -85.05112878), 85.05112878)
        let latitudeRadians = clampedLatitude * .pi / 180
        let sinLatitude = sin(latitudeRadians)
        return CGPoint(
            x: (longitude + 180) / 360,
            y: 0.5 - log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * .pi)
        )
    }
}
