//
//  GeoJSONBoundaryPathBuilder.swift
//  Lociq
//
//  Projects GeoJSON boundaries into north-up Web Mercator SwiftUI glyphs.
//
//  The boundary preview is intentionally not a map. It does not render tiles,
//  labels, roads, or any interactive map layers. It only needs a correctly
//  oriented outline that can be drawn in a very small SwiftUI frame.
//
//  The conversion pipeline is:
//
//  1. Extract polygons, with their holes.
//  2. Project longitude and latitude into Web Mercator world coordinates.
//  3. Choose the part to fit: the one containing the user, else the largest.
//     Other parts are drawn only when they sit close to it, so a distant
//     island does not shrink the city to a dot.
//  4. Normalize the fitted parts into unit space, once, off the main actor.
//  5. Scale the unit path into the view's frame with one affine transform.
//
//  Web Mercator is used so the preview has the same north-up orientation users
//  expect from common web maps. The app still avoids map UI. Projection is only
//  used to make the outline orientation feel familiar and geographically sane.
//

import CoreLocation
import SwiftUI

/// A boundary outline normalized into unit space, ready to scale into any frame.
///
/// Building a glyph walks every vertex and runs the projection math, so it is
/// done once per boundary and location, off the main actor. Drawing only
/// applies an affine transform to `unitPath`.
nonisolated struct BoundaryGlyph: Sendable {
    /// Outline of the drawn parts, holes included, in unit space.
    let unitPath: Path

    /// Size of the unit-space drawing. The longer side is 1.
    let unitSize: CGSize

    /// Connector start in unit space: an interior point of the fitted part.
    let unitAnchor: CGPoint

    /// Web Mercator origin of the fitted bounds.
    let projectedOrigin: CGPoint

    /// Multiplier from Web Mercator units to unit space.
    let unitScale: CGFloat

    /// Breathing-room multiplier applied when fitting into a frame.
    let drawingScale: CGFloat

    /// Places the glyph, centered and aspect-fit, inside a drawing rectangle.
    func placement(in rect: CGRect) -> BoundaryGlyphPlacement {
        let fitScale = min(rect.width / unitSize.width, rect.height / unitSize.height) * drawingScale
        let transform = CGAffineTransform(
            a: fitScale,
            b: 0,
            c: 0,
            d: fitScale,
            tx: rect.midX - unitSize.width * fitScale / 2,
            ty: rect.midY - unitSize.height * fitScale / 2
        )
        return BoundaryGlyphPlacement(glyph: self, rect: rect, transform: transform, fitScale: fitScale)
    }
}

/// A glyph placed in one drawing rectangle, with helpers to place related points.
///
/// The outline and the location marker use this one transform, so the marker
/// can never drift from its position inside the outline.
nonisolated struct BoundaryGlyphPlacement {
    /// The glyph being placed.
    let glyph: BoundaryGlyph

    /// Drawing rectangle.
    let rect: CGRect

    /// Transform from unit space into the drawing rectangle.
    let transform: CGAffineTransform

    /// Points per unit-space unit.
    let fitScale: CGFloat

    /// The fitted outline in drawing coordinates.
    var path: Path {
        glyph.unitPath.applying(transform)
    }

    /// Connector start in drawing coordinates.
    var anchor: CGPoint {
        glyph.unitAnchor.applying(transform)
    }

    /// Projects a geographic coordinate into drawing coordinates.
    ///
    /// Returns `nil` when the coordinate cannot be projected or falls outside
    /// the drawing rectangle (with a 2-pt tolerance for fractional edges).
    func point(for coordinate: CLLocationCoordinate2D) -> CGPoint? {
        guard let world = WebMercatorProjection.worldPoint(longitude: coordinate.longitude, latitude: coordinate.latitude) else {
            return nil
        }
        let unit = CGPoint(
            x: (world.x - glyph.projectedOrigin.x) * glyph.unitScale,
            y: (world.y - glyph.projectedOrigin.y) * glyph.unitScale
        )
        let point = unit.applying(transform)
        return rect.insetBy(dx: -2, dy: -2).contains(point) ? point : nil
    }

    /// Converts a ground distance at a latitude into drawing points.
    ///
    /// One meter on the ground spans `1 / (2π · 6,378,137 · cos φ)` of the
    /// normalized Web Mercator world, which is then scaled like the outline.
    func points(forMeters meters: Double, atLatitude latitude: Double) -> CGFloat {
        let cosine = cos(min(max(latitude, -85), 85) * .pi / 180)
        let worldUnits = meters / (2 * .pi * 6_378_137 * cosine)
        return CGFloat(worldUnits) * glyph.unitScale * fitScale
    }
}

/// Builds boundary glyphs from GeoJSON place boundaries.
///
/// This type keeps geographic conversion out of SwiftUI views. Views ask for a
/// placed glyph. They do not know how GeoJSON nesting, Web Mercator bounds,
/// fitting, or small-place scaling work.
nonisolated enum GeoJSONBoundaryPathBuilder {
    /// Typical glyph size used to decide which holes are too small to see.
    static let nominalGlyphSize: CGFloat = 140

    /// Holes smaller than this many points at the nominal size are not drawn.
    static let minimumVisibleHoleSize: CGFloat = 1.5

    /// Other parts are drawn only if they fit within this multiple of the fitted part's frame.
    static let nearbyPartWindow: CGFloat = 1.5

    /// Builds a glyph for a boundary, fitted to the part that matters.
    ///
    /// - Parameters:
    ///   - boundary: The GeoJSON boundary to draw.
    ///   - focus: The user's coordinate. The part containing it is fitted;
    ///     without one, or when it is outside every part, the largest part is.
    /// - Returns: A unit-space glyph, or `nil` when no drawable geometry exists.
    static func glyph(for boundary: GeoJSONFeatureCollection, focus: CLLocationCoordinate2D?) -> BoundaryGlyph? {
        let parts = GeoJSONBoundaryRings.polygons(from: boundary).compactMap(ProjectedPolygon.init)
        guard let largestIndex = parts.indices.max(by: { parts[$0].area < parts[$1].area }) else { return nil }

        let focusPoint = focus.flatMap {
            WebMercatorProjection.worldPoint(longitude: $0.longitude, latitude: $0.latitude)
        }
        let focusIndex = focusPoint.flatMap { point in parts.firstIndex { $0.contains(point) } } ?? largestIndex
        let focusPart = parts[focusIndex]

        // Keep parts that sit close to the fitted part; drop distant ones.
        let window = focusPart.bounds.insetBy(
            dx: -focusPart.bounds.width * (nearbyPartWindow - 1) / 2,
            dy: -focusPart.bounds.height * (nearbyPartWindow - 1) / 2
        )
        let drawnParts = parts.indices
            .filter { $0 == focusIndex || window.contains(parts[$0].bounds) }
            .map { parts[$0] }
        let fitBounds = drawnParts.map(\.bounds).reduce(CGRect.null) { $0.union($1) }
        guard fitBounds.width > 0, fitBounds.height > 0 else { return nil }

        let unitScale = 1 / max(fitBounds.width, fitBounds.height)
        func unitPoint(_ point: CGPoint) -> CGPoint {
            CGPoint(x: (point.x - fitBounds.minX) * unitScale, y: (point.y - fitBounds.minY) * unitScale)
        }

        var path = Path()
        for part in drawnParts {
            add(part.exterior.points, to: &path, mapping: unitPoint)
            for hole in part.holes {
                let visibleSize = max(hole.bounds.width, hole.bounds.height) * unitScale * nominalGlyphSize
                guard visibleSize >= minimumVisibleHoleSize else { continue }
                add(hole.points, to: &path, mapping: unitPoint)
            }
        }

        return BoundaryGlyph(
            unitPath: path,
            unitSize: CGSize(width: fitBounds.width * unitScale, height: fitBounds.height * unitScale),
            unitAnchor: unitPoint(interiorAnchor(for: focusPart, boundary: boundary)),
            projectedOrigin: fitBounds.origin,
            unitScale: unitScale,
            drawingScale: drawingScale(for: fitBounds)
        )
    }

    /// Appends one closed ring to a path.
    private static func add(_ points: [CGPoint], to path: inout Path, mapping: (CGPoint) -> CGPoint) {
        guard let first = points.first else { return }
        path.move(to: mapping(first))
        for point in points.dropFirst() {
            path.addLine(to: mapping(point))
        }
        path.closeSubpath()
    }

    /// Chooses the connector start: a point inside the fitted part.
    ///
    /// Prefers the Census internal point (`INTPTLAT`/`INTPTLON`), which is
    /// guaranteed to be inside the place, when it falls in the fitted part.
    /// Otherwise uses the part's centroid if inside, else its bounds center.
    private static func interiorAnchor(for part: ProjectedPolygon, boundary: GeoJSONFeatureCollection) -> CGPoint {
        if let internalPoint = boundary.internalPoint,
           let projected = WebMercatorProjection.worldPoint(longitude: internalPoint.longitude, latitude: internalPoint.latitude),
           part.contains(projected) {
            return projected
        }
        let centroid = part.exterior.centroid
        if part.contains(centroid) { return centroid }
        return CGPoint(x: part.bounds.midX, y: part.bounds.midY)
    }

    /// Chooses a restrained drawing scale so very small or elongated places keep breathing room.
    ///
    /// Fitting every boundary to the absolute maximum rectangle can look harsh
    /// in a minimalist UI. Very elongated cities can become edge-to-edge lines,
    /// while very small places can look artificially oversized. The inputs are
    /// projected Web Mercator bounds; the result multiplies the aspect-fit scale.
    private static func drawingScale(for projectedBounds: CGRect) -> CGFloat {
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
            // Tiny projected areas look better with extra quiet space around
            // them instead of filling the entire boundary frame.
            return 0.80
        }
        if aspectRatio > 2.4 {
            // Moderately elongated places get a smaller reduction.
            return 0.84
        }
        return 0.90
    }
}

// MARK: - Projected geometry

/// A polygon projected into Web Mercator world coordinates.
nonisolated private struct ProjectedPolygon {
    let exterior: ProjectedRing
    let holes: [ProjectedRing]

    init?(_ polygon: BoundaryPolygon) {
        guard let exterior = ProjectedRing(polygon.exterior) else { return nil }
        self.exterior = exterior
        holes = polygon.holes.compactMap(ProjectedRing.init)
    }

    var bounds: CGRect { exterior.bounds }

    /// Land-and-water area of the part in projected units, holes excluded.
    var area: CGFloat {
        abs(exterior.signedArea) - holes.reduce(0) { $0 + abs($1.signedArea) }
    }

    /// Even-odd containment: inside the exterior and outside every hole.
    func contains(_ point: CGPoint) -> Bool {
        exterior.contains(point) && !holes.contains { $0.contains(point) }
    }
}

/// One ring projected into Web Mercator world coordinates.
nonisolated private struct ProjectedRing {
    let points: [CGPoint]
    let bounds: CGRect

    init?(_ coordinates: [[Double]]) {
        var points: [CGPoint] = []
        points.reserveCapacity(coordinates.count)
        for coordinate in coordinates where coordinate.count >= 2 {
            // GeoJSON coordinate order is longitude, latitude.
            if let point = WebMercatorProjection.worldPoint(longitude: coordinate[0], latitude: coordinate[1]) {
                points.append(point)
            }
        }
        guard points.count > 2 else { return nil }
        self.points = points
        var bounds = CGRect.null
        for point in points {
            bounds = bounds.union(CGRect(origin: point, size: .zero))
        }
        self.bounds = bounds
    }

    /// Shoelace area; the sign depends on winding order.
    var signedArea: CGFloat {
        var sum: CGFloat = 0
        for index in points.indices {
            let current = points[index]
            let next = points[(index + 1) % points.count]
            sum += current.x * next.y - next.x * current.y
        }
        return sum / 2
    }

    /// Area-weighted centroid, falling back to the bounds center for degenerate rings.
    var centroid: CGPoint {
        let area = signedArea
        guard abs(area) > .ulpOfOne else { return CGPoint(x: bounds.midX, y: bounds.midY) }
        var x: CGFloat = 0
        var y: CGFloat = 0
        for index in points.indices {
            let current = points[index]
            let next = points[(index + 1) % points.count]
            let cross = current.x * next.y - next.x * current.y
            x += (current.x + next.x) * cross
            y += (current.y + next.y) * cross
        }
        return CGPoint(x: x / (6 * area), y: y / (6 * area))
    }

    /// Ray-casting point-in-ring test.
    func contains(_ point: CGPoint) -> Bool {
        guard bounds.contains(point) else { return false }
        var inside = false
        var previous = points[points.count - 1]
        for current in points {
            if (current.y > point.y) != (previous.y > point.y) {
                let crossingX = (previous.x - current.x) * (point.y - current.y) / (previous.y - current.y) + current.x
                if point.x < crossingX { inside.toggle() }
            }
            previous = current
        }
        return inside
    }
}

// MARK: - Containment in meters

/// Answers whether a location fix is still inside a place's boundary.
///
/// Used to skip reloading when the user has not left the place shown. Math is
/// done in a local equirectangular frame around the fix, which is accurate to
/// well under a meter at city scale.
nonisolated enum BoundaryContainment {
    /// Result of testing one coordinate against a boundary.
    struct Result: Equatable, Sendable {
        /// True when the coordinate is inside the boundary (holes excluded).
        let isInside: Bool

        /// Distance in meters to the nearest boundary edge, holes included.
        let edgeDistanceMeters: Double
    }

    /// Tests a coordinate against every polygon of a boundary.
    ///
    /// - Returns: `nil` when the boundary has no usable polygons.
    static func test(_ coordinate: CLLocationCoordinate2D, in boundary: GeoJSONFeatureCollection) -> Result? {
        let polygons = GeoJSONBoundaryRings.polygons(from: boundary)
        guard !polygons.isEmpty else { return nil }

        let metersPerDegreeLongitude = 111_320 * cos(coordinate.latitude * .pi / 180)
        let metersPerDegreeLatitude = 110_574.0
        func local(_ pair: [Double]) -> (x: Double, y: Double) {
            ((pair[0] - coordinate.longitude) * metersPerDegreeLongitude, (pair[1] - coordinate.latitude) * metersPerDegreeLatitude)
        }

        var isInside = false
        var nearest = Double.infinity
        for polygon in polygons {
            let exterior = polygon.exterior.filter { $0.count >= 2 }.map(local)
            let holes = polygon.holes.map { $0.filter { $0.count >= 2 }.map(local) }
            if ringContainsOrigin(exterior) && !holes.contains(where: ringContainsOrigin) {
                isInside = true
            }
            for ring in [exterior] + holes {
                nearest = min(nearest, distanceFromOrigin(toRing: ring))
            }
        }
        return Result(isInside: isInside, edgeDistanceMeters: nearest)
    }

    /// Ray-casting test for the origin of the local frame.
    private static func ringContainsOrigin(_ ring: [(x: Double, y: Double)]) -> Bool {
        guard ring.count > 2 else { return false }
        var inside = false
        var previous = ring[ring.count - 1]
        for current in ring {
            if (current.y > 0) != (previous.y > 0) {
                let crossingX = (previous.x - current.x) * (0 - current.y) / (previous.y - current.y) + current.x
                if 0 < crossingX { inside.toggle() }
            }
            previous = current
        }
        return inside
    }

    /// Shortest distance from the origin to any segment of a closed ring.
    private static func distanceFromOrigin(toRing ring: [(x: Double, y: Double)]) -> Double {
        guard ring.count > 1 else { return .infinity }
        var nearest = Double.infinity
        var previous = ring[ring.count - 1]
        for current in ring {
            let dx = current.x - previous.x
            let dy = current.y - previous.y
            let lengthSquared = dx * dx + dy * dy
            let t = lengthSquared > 0 ? min(max(-(previous.x * dx + previous.y * dy) / lengthSquared, 0), 1) : 0
            let px = previous.x + t * dx
            let py = previous.y + t * dy
            nearest = min(nearest, (px * px + py * py).squareRoot())
            previous = current
        }
        return nearest
    }
}
