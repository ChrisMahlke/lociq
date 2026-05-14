//
//  GeoJSONBoundaryPathBuilder.swift
//  Lociq
//
//  Projects GeoJSON boundaries into north-up Web Mercator SwiftUI paths.
//

import CoreLocation
import SwiftUI

nonisolated struct GeoJSONBoundaryProjection {
    let path: Path
    let center: CGPoint
    private let rect: CGRect
    private let minProjectedX: CGFloat
    private let minProjectedY: CGFloat
    private let xOffset: CGFloat
    private let yOffset: CGFloat
    private let scale: CGFloat

    /// Creates a reusable projected boundary value for one boundary and drawing rectangle.
    init(
        path: Path,
        bounds: CGRect,
        rect: CGRect,
        minProjectedX: CGFloat,
        minProjectedY: CGFloat,
        xOffset: CGFloat,
        yOffset: CGFloat,
        scale: CGFloat
    ) {
        self.path = path
        self.center = CGPoint(x: bounds.midX, y: bounds.midY)
        self.rect = rect
        self.minProjectedX = minProjectedX
        self.minProjectedY = minProjectedY
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.scale = scale
    }

    /// Projects a geographic coordinate into this projection's drawing space.
    func point(for coordinate: CLLocationCoordinate2D) -> CGPoint? {
        guard
            let projectedPoint = WebMercatorProjection.worldPoint(
                longitude: coordinate.longitude,
                latitude: coordinate.latitude
            )
        else {
            return nil
        }

        let point = CGPoint(
            x: xOffset + (projectedPoint.x - minProjectedX) * scale,
            y: yOffset + (projectedPoint.y - minProjectedY) * scale
        )
        return rect.insetBy(dx: -2, dy: -2).contains(point) ? point : nil
    }
}

enum GeoJSONBoundaryPathBuilder {
    nonisolated private static let drawingScale: CGFloat = 0.92

    /// Builds a reusable projection for the supplied boundary and drawing rectangle.
    nonisolated static func projection(
        for boundary: GeoJSONFeatureCollection,
        in rect: CGRect,
        fittingTo fittingBoundary: GeoJSONFeatureCollection? = nil
    ) -> GeoJSONBoundaryProjection? {
        let rings = GeoJSONBoundaryRings.exteriorRings(from: boundary)
        guard !rings.isEmpty else { return nil }

        let fittingRings = fittingBoundary.map(GeoJSONBoundaryRings.exteriorRings(from:))
        let boundsRings = fittingRings?.isEmpty == false ? fittingRings ?? rings : rings

        guard let projectedBounds = WebMercatorProjection.projectedBounds(for: boundsRings) else { return nil }
        let projectedWidth = projectedBounds.width
        let projectedHeight = projectedBounds.height
        guard projectedWidth > 0, projectedHeight > 0 else { return nil }

        let scale = min(rect.width / projectedWidth, rect.height / projectedHeight) * drawingScale
        let drawingWidth = projectedWidth * scale
        let drawingHeight = projectedHeight * scale
        let xOffset = rect.midX - drawingWidth / 2
        let yOffset = rect.midY - drawingHeight / 2

        var path = Path()
        var minX = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var minY = CGFloat.infinity
        var maxY = -CGFloat.infinity
        var didProjectAnyRing = false

        for ring in rings {
            var projectedRing: [CGPoint] = []
            projectedRing.reserveCapacity(ring.count)

            for coordinate in ring where coordinate.count >= 2 {
                guard let projectedPoint = WebMercatorProjection.worldPoint(longitude: coordinate[0], latitude: coordinate[1]) else {
                    continue
                }

                let point = CGPoint(
                    x: xOffset + (projectedPoint.x - projectedBounds.minX) * scale,
                    y: yOffset + (projectedPoint.y - projectedBounds.minY) * scale
                )
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
                projectedRing.append(point)
            }

            if projectedRing.count > 2 {
                path.move(to: projectedRing[0])
                for point in projectedRing.dropFirst() {
                    path.addLine(to: point)
                }
                path.closeSubpath()
                didProjectAnyRing = true
            }
        }

        guard didProjectAnyRing else { return nil }

        return GeoJSONBoundaryProjection(
            path: path,
            bounds: CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY),
            rect: rect,
            minProjectedX: projectedBounds.minX,
            minProjectedY: projectedBounds.minY,
            xOffset: xOffset,
            yOffset: yOffset,
            scale: scale
        )
    }

    /// Builds a SwiftUI path for the supplied GeoJSON boundary using Web Mercator orientation.
    nonisolated static func path(
        for boundary: GeoJSONFeatureCollection,
        in rect: CGRect,
        fittingTo fittingBoundary: GeoJSONFeatureCollection? = nil
    ) -> Path? {
        projection(for: boundary, in: rect, fittingTo: fittingBoundary)?.path
    }

    /// Returns the projected center of a boundary path, falling back to the provided rectangle center.
    nonisolated static func center(for boundary: GeoJSONFeatureCollection?, fallbackRect: CGRect) -> CGPoint {
        guard
            let boundary,
            let projection = projection(
                for: boundary,
                in: CGRect(origin: .zero, size: fallbackRect.size)
            )
        else {
            return CGPoint(x: fallbackRect.width / 2, y: fallbackRect.height / 2)
        }

        return projection.center
    }

    /// Projects a geographic coordinate into the same drawing space as the fitted boundary.
    nonisolated static func point(
        for coordinate: CLLocationCoordinate2D,
        in rect: CGRect,
        fittingTo boundary: GeoJSONFeatureCollection
    ) -> CGPoint? {
        guard
            let projection = projection(for: boundary, in: rect)
        else {
            return nil
        }

        return projection.point(for: coordinate)
    }

}
