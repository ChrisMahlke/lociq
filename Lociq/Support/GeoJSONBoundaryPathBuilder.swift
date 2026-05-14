//
//  GeoJSONBoundaryPathBuilder.swift
//  Lociq
//
//  Projects GeoJSON boundaries into north-up Web Mercator SwiftUI paths.
//
//  The boundary preview is intentionally not a map. It does not render tiles,
//  labels, roads, or any interactive map layers. It only needs a correctly
//  oriented outline that can be drawn in a very small SwiftUI frame.
//
//  The conversion pipeline is:
//
//  1. Extract exterior GeoJSON rings.
//  2. Project longitude and latitude into Web Mercator world coordinates.
//  3. Compute projected bounds for the geometry that should control fitting.
//  4. Scale those bounds into the available SwiftUI rectangle.
//  5. Build a `Path` from the projected rings.
//
//  Web Mercator is used so the preview has the same north-up orientation users
//  expect from common web maps. The app still avoids map UI. Projection is only
//  used to make the outline orientation feel familiar and geographically sane.
//

import CoreLocation
import SwiftUI

/// Stores a projected boundary path and the transform needed to project related coordinates.
///
/// `GeoJSONBoundaryProjection` is the reusable result produced by
/// `GeoJSONBoundaryPathBuilder`. The `path` is what SwiftUI strokes on screen.
/// The remaining private values preserve the same projection transform so other
/// geographic values, such as the user's approximate coordinate, can be placed
/// into the exact same drawing space.
///
/// This is important because the boundary outline and the location dot must use
/// one shared coordinate system. If they were projected independently, the dot
/// could drift away from its real position inside the outline.
nonisolated struct GeoJSONBoundaryProjection {
    /// The final SwiftUI path fitted into the requested drawing rectangle.
    let path: Path

    /// The center of the actually drawn projected path inside the drawing rectangle.
    ///
    /// This is based on the projected path bounds, not simply the center of the
    /// full view rectangle. The connector animation uses this point so the line
    /// starts at the visual center of the boundary shape.
    let center: CGPoint

    /// The rectangle that defines the output drawing coordinate space.
    private let rect: CGRect

    /// The minimum projected Web Mercator x value used as the transform origin.
    private let minProjectedX: CGFloat

    /// The minimum projected Web Mercator y value used as the transform origin.
    private let minProjectedY: CGFloat

    /// Horizontal offset that centers the scaled projection inside `rect`.
    private let xOffset: CGFloat

    /// Vertical offset that centers the scaled projection inside `rect`.
    private let yOffset: CGFloat

    /// Scale factor from projected Web Mercator units into view points.
    private let scale: CGFloat

    /// Creates a reusable projected boundary value for one boundary and drawing rectangle.
    ///
    /// - Parameters:
    ///   - path: The fitted SwiftUI path created from all drawable rings.
    ///   - bounds: The bounds of the actual fitted path after projection.
    ///   - rect: The drawing rectangle used by the SwiftUI boundary view.
    ///   - minProjectedX: The projected x origin used during path construction.
    ///   - minProjectedY: The projected y origin used during path construction.
    ///   - xOffset: Horizontal centering offset applied to projected points.
    ///   - yOffset: Vertical centering offset applied to projected points.
    ///   - scale: The projected-unit to view-point scale factor.
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
    ///
    /// This is used for the approximate location dot. It applies the same
    /// transform that was used to build the boundary path:
    ///
    /// 1. Convert longitude and latitude to Web Mercator world coordinates.
    /// 2. Subtract the projected fitting origin.
    /// 3. Apply the stored scale.
    /// 4. Apply the centering offsets.
    ///
    /// The final containment check allows a tiny tolerance around the drawing
    /// rectangle. That tolerance avoids hiding a dot because of fractional
    /// projection or stroke-width differences near an edge, while still
    /// preventing obviously out-of-frame coordinates from rendering.
    ///
    /// - Parameter coordinate: A geographic coordinate in WGS84 longitude and latitude.
    /// - Returns: The point in SwiftUI drawing coordinates, or `nil` when the
    ///   coordinate cannot be projected or falls outside the drawable area.
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

/// Builds SwiftUI drawing primitives from GeoJSON place boundaries.
///
/// This type keeps geographic conversion out of SwiftUI views. Views ask for a
/// projected path or a projected point. They do not know how GeoJSON nesting,
/// Web Mercator bounds, fitting, or small-place scaling work.
enum GeoJSONBoundaryPathBuilder {
    /// Builds a reusable projection for the supplied boundary and drawing rectangle.
    ///
    /// The returned projection includes both the SwiftUI `Path` and the
    /// transform needed to place related coordinates in the same space. The
    /// method can optionally fit one boundary using another boundary's bounds.
    /// That is useful when a smaller geography needs to be drawn inside a
    /// larger geography without rescaling independently.
    ///
    /// - Parameters:
    ///   - boundary: The GeoJSON boundary that should be drawn.
    ///   - rect: The SwiftUI drawing rectangle.
    ///   - fittingBoundary: Optional geometry whose bounds should control the
    ///     scale and centering. When `nil`, `boundary` controls its own fitting.
    /// - Returns: A projected path and transform, or `nil` when no drawable
    ///   geometry can be produced.
    nonisolated static func projection(
        for boundary: GeoJSONFeatureCollection,
        in rect: CGRect,
        fittingTo fittingBoundary: GeoJSONFeatureCollection? = nil
    ) -> GeoJSONBoundaryProjection? {
        // Extract only exterior rings. Interior holes are intentionally ignored
        // by `GeoJSONBoundaryRings` because this preview is stroked and tiny.
        let rings = GeoJSONBoundaryRings.exteriorRings(from: boundary)
        guard !rings.isEmpty else { return nil }

        // If a separate fitting boundary is supplied, use its exterior rings to
        // compute scale and offsets. The drawn rings still come from `boundary`.
        let fittingRings = fittingBoundary.map(GeoJSONBoundaryRings.exteriorRings(from:))
        let boundsRings = fittingRings?.isEmpty == false ? fittingRings ?? rings : rings

        // Bounds are computed in projected space. Longitude and latitude degrees
        // are not uniform distances, so fitting in raw geographic coordinates
        // would distort the outline and can rotate the perceived geography.
        guard let projectedBounds = WebMercatorProjection.projectedBounds(for: boundsRings) else { return nil }
        let projectedWidth = projectedBounds.width
        let projectedHeight = projectedBounds.height
        guard projectedWidth > 0, projectedHeight > 0 else { return nil }

        // Fit the projected boundary into the available rectangle while keeping
        // its aspect ratio. `drawingScale` intentionally leaves breathing room
        // so very small or very elongated places do not touch the preview edges.
        let scale = min(rect.width / projectedWidth, rect.height / projectedHeight) * drawingScale(for: projectedBounds)
        let drawingWidth = projectedWidth * scale
        let drawingHeight = projectedHeight * scale

        // Center the scaled projected bounds inside the target rectangle.
        let xOffset = rect.midX - drawingWidth / 2
        let yOffset = rect.midY - drawingHeight / 2

        var path = Path()
        var minX = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var minY = CGFloat.infinity
        var maxY = -CGFloat.infinity
        var didProjectAnyRing = false

        for ring in rings {
            // Build an intermediate array for the ring so invalid coordinates
            // can be skipped before the path is mutated.
            var projectedRing: [CGPoint] = []
            projectedRing.reserveCapacity(ring.count)

            for coordinate in ring where coordinate.count >= 2 {
                // GeoJSON coordinate order is longitude, latitude.
                guard let projectedPoint = WebMercatorProjection.worldPoint(longitude: coordinate[0], latitude: coordinate[1]) else {
                    continue
                }

                // Convert projected world coordinates into the local SwiftUI
                // drawing space using the same origin, scale, and offset used
                // by the final projection object.
                let point = CGPoint(
                    x: xOffset + (projectedPoint.x - projectedBounds.minX) * scale,
                    y: yOffset + (projectedPoint.y - projectedBounds.minY) * scale
                )

                // Track the actual drawn bounds. These can differ from the
                // fitting bounds when `fittingBoundary` is supplied.
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
                projectedRing.append(point)
            }

            if projectedRing.count > 2 {
                // The preview strokes each exterior ring as a closed outline.
                // Closing the subpath makes the shape robust even if the source
                // ring does not repeat the first coordinate as its final point.
                path.move(to: projectedRing[0])
                for point in projectedRing.dropFirst() {
                    path.addLine(to: point)
                }
                path.closeSubpath()
                didProjectAnyRing = true
            }
        }

        guard didProjectAnyRing else { return nil }

        // Preserve the transform values so caller code can project the user's
        // coordinate into the same view space without recomputing or diverging.
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
    ///
    /// This convenience method is useful when callers only need to stroke the
    /// boundary and do not need the reusable coordinate projection.
    ///
    /// - Parameters:
    ///   - boundary: The GeoJSON boundary to draw.
    ///   - rect: The SwiftUI drawing rectangle.
    ///   - fittingBoundary: Optional geometry whose bounds should control scale
    ///     and centering.
    /// - Returns: A fitted path, or `nil` when projection fails.
    nonisolated static func path(
        for boundary: GeoJSONFeatureCollection,
        in rect: CGRect,
        fittingTo fittingBoundary: GeoJSONFeatureCollection? = nil
    ) -> Path? {
        projection(for: boundary, in: rect, fittingTo: fittingBoundary)?.path
    }

    /// Returns the projected center of a boundary path, falling back to the provided rectangle center.
    ///
    /// The connector line should start from the visual center of the geography,
    /// not from the center of the whole app screen. This method projects the
    /// boundary and returns that geometry center. When no boundary is available,
    /// the rectangle center is the safest neutral fallback.
    ///
    /// - Parameters:
    ///   - boundary: Optional GeoJSON boundary.
    ///   - fallbackRect: The rectangle whose center should be used if the
    ///     boundary cannot be projected.
    /// - Returns: A point in local drawing coordinates.
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
    ///
    /// This convenience method is used when a caller has a boundary and wants
    /// to place one coordinate, such as the user's approximate location, within
    /// that boundary's drawing frame.
    ///
    /// - Parameters:
    ///   - coordinate: A WGS84 geographic coordinate.
    ///   - rect: The SwiftUI drawing rectangle.
    ///   - boundary: The boundary that controls projection and fitting.
    /// - Returns: A point in local drawing coordinates, or `nil` when either
    ///   the boundary or coordinate cannot be projected.
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

    /// Chooses a restrained drawing scale so very small or elongated places keep breathing room.
    ///
    /// Fitting every boundary to the absolute maximum rectangle can look harsh
    /// in a minimalist UI. Very elongated cities can become edge-to-edge lines,
    /// while very small places can look artificially oversized. This heuristic
    /// keeps the preview visually quiet by reducing scale for those cases.
    ///
    /// The inputs are projected Web Mercator bounds, not screen-space bounds.
    /// The returned value is a multiplier applied after aspect-fit scaling.
    ///
    /// - Parameter projectedBounds: The Web Mercator bounds used for fitting.
    /// - Returns: A scale multiplier in the range used by the boundary preview.
    nonisolated private static func drawingScale(for projectedBounds: CGRect) -> CGFloat {
        let width = max(projectedBounds.width, 0.000_001)
        let height = max(projectedBounds.height, 0.000_001)
        let aspectRatio = max(width / height, height / width)
        let area = width * height

        if aspectRatio > 4 {
            // Extremely elongated places need the most margin so the outline
            // does not read as a hard rule across the preview.
            return 0.78
        }
        if area < 0.000_000_4 {
            // Tiny projected areas often look better with extra quiet space
            // around them instead of filling the entire boundary frame.
            return 0.80
        }
        if aspectRatio > 2.4 {
            // Moderately elongated places get a smaller reduction.
            return 0.84
        }
        return 0.90
    }

}
