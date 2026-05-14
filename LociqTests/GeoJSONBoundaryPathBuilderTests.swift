//
//  GeoJSONBoundaryPathBuilderTests.swift
//  LociqTests
//
//  Verifies boundary projection and coordinate placement behavior.
//
//  These tests protect the small but important projection assumptions behind
//  the geography glyph. The preview is not a map, but it still needs north-up
//  orientation and consistent coordinate placement.
//

import CoreLocation
import CoreGraphics
import Testing
@testable import Lociq

/// Tests for Web Mercator projection and point placement in boundary previews.
struct GeoJSONBoundaryPathBuilderTests {
    /// Verifies projected coordinates preserve north-up Web Mercator orientation.
    ///
    /// In screen coordinates, smaller y values are visually higher. A northern
    /// coordinate should therefore project above a southern coordinate.
    @Test func projectedPointsUseNorthUpWebMercatorOrientation() {
        let boundary = squareBoundary()
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)

        let northPoint = GeoJSONBoundaryPathBuilder.point(
            for: CLLocationCoordinate2D(latitude: 0.75, longitude: 0.5),
            in: rect,
            fittingTo: boundary
        )
        let southPoint = GeoJSONBoundaryPathBuilder.point(
            for: CLLocationCoordinate2D(latitude: 0.25, longitude: 0.5),
            in: rect,
            fittingTo: boundary
        )

        #expect(northPoint != nil)
        #expect(southPoint != nil)
        #expect(northPoint!.y < southPoint!.y)
    }

    /// Verifies the center coordinate projects near the center of the fitted boundary.
    ///
    /// The square fixture gives a simple geometry where the geographic midpoint
    /// should land near the drawing rectangle's center after fitting.
    @Test func projectedPointStaysCenteredForMiddleCoordinate() {
        let boundary = squareBoundary()
        let rect = CGRect(x: 0, y: 0, width: 120, height: 120)

        let point = GeoJSONBoundaryPathBuilder.point(
            for: CLLocationCoordinate2D(latitude: 0.5, longitude: 0.5),
            in: rect,
            fittingTo: boundary
        )

        #expect(point != nil)
        #expect(abs(point!.x - rect.midX) < 1)
        #expect(abs(point!.y - rect.midY) < 1)
    }

    /// Creates a square GeoJSON boundary fixture.
    ///
    /// Coordinates are intentionally simple and in GeoJSON longitude-latitude
    /// order so projection expectations are easy to reason about.
    private func squareBoundary() -> GeoJSONFeatureCollection {
        GeoJSONFeatureCollection(
            type: "FeatureCollection",
            features: [
                GeoJSONFeature(
                    type: "Feature",
                    properties: nil,
                    geometry: .polygon([
                        [
                            [0, 0],
                            [1, 0],
                            [1, 1],
                            [0, 1],
                            [0, 0]
                        ]
                    ])
                )
            ]
        )
    }
}
