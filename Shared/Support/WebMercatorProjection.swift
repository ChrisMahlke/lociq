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
nonisolated enum WebMercatorProjection {
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
