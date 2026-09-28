//
//  ComplicationSnapshotBuilder.swift
//  Lociq
//
//  Builds the complication record from what the watch app shows.
//
//  Only a definite answer about where the wearer is becomes a record: the
//  current city, or a place without city data. The outline is simplified for
//  complication sizes, so the widget reads a few kilobytes instead of the
//  cached profile and its full boundary.
//

import CoreGraphics
import Foundation
import SwiftUI

extension ComplicationSnapshot {
    /// Most outline points kept; outlines are simplified until they fit.
    static let maximumOutlinePoints = 400

    /// The record for what the screen shows, or `nil` when the screen gives
    /// no definite answer about where the user is.
    ///
    /// - Parameters:
    ///   - viewState: What the screen shows.
    ///   - glyph: The displayed city's outline, when built.
    ///   - confirmedAt: When the screen showed it.
    ///   - locale: Locale for the compact population.
    init?(viewState: LocationProfileViewState, glyph: BoundaryGlyph?, confirmedAt: Date, locale: Locale = .current) {
        let snapshot = viewState.snapshot
        switch viewState.placeAnswer {
        case .city:
            guard snapshot.hasDemographicData else { return nil }
            let outline = glyph.map(Self.simplifiedOutline) ?? []
            self.init(
                kind: .city,
                title: snapshot.market,
                shortTitle: DemographicValueFormatter.titleWithoutState(snapshot.market),
                subtitle: "",
                population: snapshot.metrics.first { $0.resolvedKind == .population }?.primaryValue,
                compactPopulation: snapshot.populationCount.map { DemographicValueFormatter.compactCount($0, locale: locale) },
                outline: outline,
                outlineSize: outline.isEmpty ? .zero : (glyph?.unitSize ?? .zero),
                confirmedAt: confirmedAt
            )
        case .noCity:
            self.init(
                kind: .message,
                title: snapshot.market,
                shortTitle: snapshot.market,
                subtitle: snapshot.statusLine,
                population: nil,
                compactPopulation: nil,
                outline: [],
                outlineSize: .zero,
                confirmedAt: confirmedAt
            )
        case .unknown:
            return nil
        }
    }

    /// The glyph's rings, simplified until they fit `maximumOutlinePoints`,
    /// with rings too small to see at complication sizes dropped.
    static func simplifiedOutline(_ glyph: BoundaryGlyph) -> [[CGPoint]] {
        let rings = rings(of: glyph.unitPath)
        var tolerance: CGFloat = 0.002
        var simplified = simplify(rings, tolerance: tolerance)
        while simplified.reduce(0, { $0 + $1.count }) > maximumOutlinePoints, tolerance < 0.05 {
            tolerance *= 2
            simplified = simplify(rings, tolerance: tolerance)
        }
        return simplified
    }

    /// Splits a path into closed rings of points.
    static func rings(of path: Path) -> [[CGPoint]] {
        var rings: [[CGPoint]] = []
        var current: [CGPoint] = []
        func finishRing() {
            if current.count >= 3 { rings.append(current) }
            current = []
        }
        path.forEach { element in
            switch element {
            case .move(let point):
                finishRing()
                current = [point]
            case .line(let point), .quadCurve(let point, _), .curve(let point, _, _):
                current.append(point)
            case .closeSubpath:
                finishRing()
            }
        }
        finishRing()
        return rings
    }

    /// Simplifies each ring, dropping rings smaller than a few tolerances,
    /// and rounds coordinates to keep the record small.
    static func simplify(_ rings: [[CGPoint]], tolerance: CGFloat) -> [[CGPoint]] {
        rings.compactMap { ring in
            let xs = ring.map(\.x)
            let ys = ring.map(\.y)
            let extent = max((xs.max() ?? 0) - (xs.min() ?? 0), (ys.max() ?? 0) - (ys.min() ?? 0))
            guard extent >= tolerance * 4 else { return nil }
            let points = douglasPeucker(ring, tolerance: tolerance)
            guard points.count >= 3 else { return nil }
            return points.map { CGPoint(x: ($0.x * 10_000).rounded() / 10_000, y: ($0.y * 10_000).rounded() / 10_000) }
        }
    }

    /// Ramer–Douglas–Peucker simplification of a polyline, without recursion.
    ///
    /// Keeps the first and last points, and every point farther than
    /// `tolerance` from the simplified line through its neighbors.
    static func douglasPeucker(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var spans = [(start: 0, end: points.count - 1)]
        while let span = spans.popLast() {
            guard span.end > span.start + 1 else { continue }
            var farthest = span.start
            var farthestDistance: CGFloat = 0
            for index in (span.start + 1)..<span.end {
                let distance = Self.distance(from: points[index], toSegment: points[span.start], points[span.end])
                if distance > farthestDistance {
                    farthestDistance = distance
                    farthest = index
                }
            }
            if farthestDistance > tolerance {
                keep[farthest] = true
                spans.append((span.start, farthest))
                spans.append((farthest, span.end))
            }
        }
        return points.indices.filter { keep[$0] }.map { points[$0] }
    }

    /// Distance from a point to a segment; to the endpoint when the segment is a point.
    private static func distance(from point: CGPoint, toSegment start: CGPoint, _ end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }
        let t = min(max(((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared, 0), 1)
        return hypot(point.x - (start.x + t * dx), point.y - (start.y + t * dy))
    }
}
