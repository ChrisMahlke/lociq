//
//  WebMercatorProjection.swift
//  Lociq
//
//  Projects longitude/latitude coordinates into normalized Web Mercator space.
//

import CoreGraphics
import Foundation

/// Utility projection matching the north-up orientation used by Google Maps and Web Mercator map tiles.
enum WebMercatorProjection {
    /// Finds the normalized Web Mercator bounds for a collection of exterior rings.
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
