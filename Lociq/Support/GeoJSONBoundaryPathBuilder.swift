//
//  GeoJSONBoundaryPathBuilder.swift
//  Lociq
//
//  Projects GeoJSON boundaries into north-up Web Mercator SwiftUI paths.
//

import CoreLocation
import SwiftUI

enum GeoJSONBoundaryPathBuilder {
    /// Builds a SwiftUI path for the supplied GeoJSON boundary using Web Mercator orientation.
    nonisolated static func path(
        for boundary: GeoJSONFeatureCollection,
        in rect: CGRect,
        fittingTo fittingBoundary: GeoJSONFeatureCollection? = nil
    ) -> Path? {
        guard let projectedBoundary = projectedBoundary(for: boundary, in: rect, fittingTo: fittingBoundary) else {
            return nil
        }

        var path = Path()
        for ring in projectedBoundary.rings {
            var didMove = false
            for point in ring {
                if didMove {
                    path.addLine(to: point)
                } else {
                    path.move(to: point)
                    didMove = true
                }
            }
            path.closeSubpath()
        }

        return path
    }

    /// Returns the projected center of a boundary path, falling back to the provided rectangle center.
    nonisolated static func center(for boundary: GeoJSONFeatureCollection?, fallbackRect: CGRect) -> CGPoint {
        guard
            let boundary,
            let projectedBoundary = projectedBoundary(
                for: boundary,
                in: CGRect(origin: .zero, size: fallbackRect.size)
            )
        else {
            return CGPoint(x: fallbackRect.width / 2, y: fallbackRect.height / 2)
        }

        return CGPoint(x: projectedBoundary.bounds.midX, y: projectedBoundary.bounds.midY)
    }

    /// Projects a geographic coordinate into the same drawing space as the fitted boundary.
    nonisolated static func point(
        for coordinate: CLLocationCoordinate2D,
        in rect: CGRect,
        fittingTo boundary: GeoJSONFeatureCollection
    ) -> CGPoint? {
        guard
            let projectedBoundary = projectedBoundary(for: boundary, in: rect),
            let projectedPoint = googleMapsWorldPoint(
                longitude: coordinate.longitude,
                latitude: coordinate.latitude
            )
        else {
            return nil
        }

        let x = projectedBoundary.xOffset + (projectedPoint.x - projectedBoundary.minProjectedX) * projectedBoundary.scale
        let y = projectedBoundary.yOffset + (projectedPoint.y - projectedBoundary.minProjectedY) * projectedBoundary.scale
        let point = CGPoint(x: x, y: y)
        return rect.insetBy(dx: -2, dy: -2).contains(point) ? point : nil
    }

    /// Projects GeoJSON rings into a rectangle while preserving the north-up Web Mercator shape.
    nonisolated private static func projectedBoundary(
        for boundary: GeoJSONFeatureCollection,
        in rect: CGRect,
        fittingTo fittingBoundary: GeoJSONFeatureCollection? = nil
    ) -> ProjectedBoundary? {
        let rings = boundary.features
            .compactMap(\.geometry)
            .flatMap(exteriorRings(from:))
            .filter { $0.count > 2 }

        guard !rings.isEmpty else { return nil }

        let fittingRings = fittingBoundary?.features
            .compactMap(\.geometry)
            .flatMap(exteriorRings(from:))
            .filter { $0.count > 2 }
        let boundsRings = fittingRings?.isEmpty == false ? fittingRings ?? rings : rings

        let points = rings.flatMap { ring in
            ring.compactMap { coordinate -> CGPoint? in
                guard coordinate.count >= 2 else { return nil }
                return googleMapsWorldPoint(longitude: coordinate[0], latitude: coordinate[1])
            }
        }
        let boundsPoints = boundsRings.flatMap { ring in
            ring.compactMap { coordinate -> CGPoint? in
                guard coordinate.count >= 2 else { return nil }
                return googleMapsWorldPoint(longitude: coordinate[0], latitude: coordinate[1])
            }
        }

        guard
            !points.isEmpty,
            let minProjectedX = boundsPoints.map(\.x).min(),
            let maxProjectedX = boundsPoints.map(\.x).max(),
            let minProjectedY = boundsPoints.map(\.y).min(),
            let maxProjectedY = boundsPoints.map(\.y).max(),
            maxProjectedX > minProjectedX,
            maxProjectedY > minProjectedY
        else {
            return nil
        }

        let projectedWidth = maxProjectedX - minProjectedX
        let projectedHeight = maxProjectedY - minProjectedY
        let scale = min(rect.width / projectedWidth, rect.height / projectedHeight) * 0.92
        let drawingWidth = projectedWidth * scale
        let drawingHeight = projectedHeight * scale
        let xOffset = rect.midX - drawingWidth / 2
        let yOffset = rect.midY - drawingHeight / 2

        var projectedRings: [[CGPoint]] = []
        for ring in rings {
            var projectedRing: [CGPoint] = []
            for coordinate in ring where coordinate.count >= 2 {
                guard let projectedPoint = googleMapsWorldPoint(longitude: coordinate[0], latitude: coordinate[1]) else {
                    continue
                }
                let x = xOffset + (projectedPoint.x - minProjectedX) * scale
                let y = yOffset + (projectedPoint.y - minProjectedY) * scale
                projectedRing.append(CGPoint(x: x, y: y))
            }
            if projectedRing.count > 2 {
                projectedRings.append(projectedRing)
            }
        }

        guard !projectedRings.isEmpty else { return nil }
        let allProjectedPoints = projectedRings.flatMap { $0 }
        guard
            let minX = allProjectedPoints.map(\.x).min(),
            let maxX = allProjectedPoints.map(\.x).max(),
            let minY = allProjectedPoints.map(\.y).min(),
            let maxY = allProjectedPoints.map(\.y).max()
        else {
            return nil
        }

        return ProjectedBoundary(
            rings: projectedRings,
            bounds: CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY),
            minProjectedX: minProjectedX,
            minProjectedY: minProjectedY,
            xOffset: xOffset,
            yOffset: yOffset,
            scale: scale
        )
    }

    private struct ProjectedBoundary {
        let rings: [[CGPoint]]
        let bounds: CGRect
        let minProjectedX: CGFloat
        let minProjectedY: CGFloat
        let xOffset: CGFloat
        let yOffset: CGFloat
        let scale: CGFloat
    }

    /// Converts a coordinate into normalized Web Mercator world coordinates.
    nonisolated private static func googleMapsWorldPoint(longitude: Double, latitude: Double) -> CGPoint? {
        guard longitude.isFinite, latitude.isFinite else { return nil }
        let clampedLatitude = min(max(latitude, -85.05112878), 85.05112878)
        let latitudeRadians = clampedLatitude * .pi / 180
        let sinLatitude = sin(latitudeRadians)
        return CGPoint(
            x: (longitude + 180) / 360,
            y: 0.5 - log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * .pi)
        )
    }

    /// Extracts exterior polygon rings from supported GeoJSON geometry types.
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
