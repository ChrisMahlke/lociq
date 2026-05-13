import CoreLocation
import CoreGraphics
import Testing
@testable import Lociq

struct GeoJSONBoundaryPathBuilderTests {
    /// Verifies projected coordinates preserve north-up Web Mercator orientation.
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
