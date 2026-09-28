//
//  GeoJSONBoundaryPathBuilderTests.swift
//  LociqTests
//
//  Verifies boundary projection, fitting, holes, and marker placement.
//
//  These tests protect the small but important geometry behind the glyph. The
//  preview is not a map, but it still needs north-up orientation, honest holes,
//  a recognizable main part, and a marker sized to real accuracy.
//

import CoreLocation
import CoreGraphics
import SwiftUI
import Testing
@testable import Lociq

@MainActor
/// Tests for glyph construction, placement, containment, and marker style.
struct GeoJSONBoundaryPathBuilderTests {
    private let rect = CGRect(x: 0, y: 0, width: 120, height: 120)

    /// Projected coordinates preserve north-up Web Mercator orientation.
    @Test func projectedPointsUseNorthUpWebMercatorOrientation() throws {
        let placement = try #require(GeoJSONBoundaryPathBuilder.glyph(for: squareBoundary(), focus: nil)).placement(in: rect)

        let north = try #require(placement.point(for: CLLocationCoordinate2D(latitude: 0.75, longitude: 0.5)))
        let south = try #require(placement.point(for: CLLocationCoordinate2D(latitude: 0.25, longitude: 0.5)))
        #expect(north.y < south.y)
    }

    /// The center coordinate projects near the center of the fitted boundary.
    @Test func projectedPointStaysCenteredForMiddleCoordinate() throws {
        let placement = try #require(GeoJSONBoundaryPathBuilder.glyph(for: squareBoundary(), focus: nil)).placement(in: rect)
        let point = try #require(placement.point(for: CLLocationCoordinate2D(latitude: 0.5, longitude: 0.5)))

        #expect(abs(point.x - rect.midX) < 1)
        #expect(abs(point.y - rect.midY) < 1)
    }

    /// GIS-003: an enclave stays unfilled with the even-odd rule.
    @Test func evenOddPathLeavesHoleUnfilled() throws {
        let boundary = collection(.polygon([
            ring(minLon: 0, minLat: 0, maxLon: 1, maxLat: 1),
            ring(minLon: 0.4, minLat: 0.4, maxLon: 0.6, maxLat: 0.6)
        ]))
        let placement = try #require(GeoJSONBoundaryPathBuilder.glyph(for: boundary, focus: nil)).placement(in: rect)
        let holeCenter = try #require(placement.point(for: CLLocationCoordinate2D(latitude: 0.5, longitude: 0.5)))
        let solidPoint = try #require(placement.point(for: CLLocationCoordinate2D(latitude: 0.2, longitude: 0.2)))

        #expect(placement.path.contains(holeCenter, eoFill: true) == false)
        #expect(placement.path.contains(solidPoint, eoFill: true))
    }

    /// GIS-003: a distant island does not shrink the main part, and the connector starts inside it.
    @Test func fitUsesMainPart() throws {
        // A 10-km main part and a 1-km island about 40 km east.
        let main = ring(minLon: -71.20, minLat: 42.30, maxLon: -71.08, maxLat: 42.39)
        let island = ring(minLon: -70.70, minLat: 42.33, maxLon: -70.688, maxLat: 42.339)
        let boundary = collection(.multiPolygon([[main], [island]]))
        let glyph = try #require(GeoJSONBoundaryPathBuilder.glyph(for: boundary, focus: nil))
        let placement = glyph.placement(in: rect)

        let mainWest = try #require(placement.point(for: CLLocationCoordinate2D(latitude: 42.345, longitude: -71.20)))
        let mainEast = try #require(placement.point(for: CLLocationCoordinate2D(latitude: 42.345, longitude: -71.08)))
        let drawnWidth = glyph.unitSize.width * placement.fitScale
        #expect((mainEast.x - mainWest.x) / drawnWidth >= 0.8)
        #expect(placement.point(for: CLLocationCoordinate2D(latitude: 42.335, longitude: -70.694)) == nil)
        #expect(placement.path.contains(placement.anchor, eoFill: true))
    }

    /// The part containing the user is the one fitted.
    @Test func focusPartIsTheOneContainingTheUser() throws {
        let main = ring(minLon: -71.20, minLat: 42.30, maxLon: -71.08, maxLat: 42.39)
        let island = ring(minLon: -70.70, minLat: 42.33, maxLon: -70.688, maxLat: 42.339)
        let boundary = collection(.multiPolygon([[main], [island]]))
        let focus = CLLocationCoordinate2D(latitude: 42.335, longitude: -70.694)
        let placement = try #require(GeoJSONBoundaryPathBuilder.glyph(for: boundary, focus: focus)).placement(in: rect)

        #expect(placement.point(for: focus) != nil)
        #expect(placement.point(for: CLLocationCoordinate2D(latitude: 42.345, longitude: -71.14)) == nil)
    }

    /// GIS-005: meters convert to points with the Web Mercator scale at the fix's latitude.
    @Test func metersToPointsMatchesWebMercatorScale() throws {
        let boundary = collection(.polygon([ring(minLon: -71.12, minLat: 42.36, maxLon: -71.08, maxLat: 42.39)]))
        let placement = try #require(GeoJSONBoundaryPathBuilder.glyph(for: boundary, focus: nil)).placement(in: rect)

        let west = try #require(placement.point(for: CLLocationCoordinate2D(latitude: 42.375, longitude: -71.12)))
        let east = try #require(placement.point(for: CLLocationCoordinate2D(latitude: 42.375, longitude: -71.08)))
        let widthMeters = CLLocation(latitude: 42.375, longitude: -71.12).distance(from: CLLocation(latitude: 42.375, longitude: -71.08))
        let pointsPerMeter = (east.x - west.x) / widthMeters

        let converted = placement.points(forMeters: 1_000, atLatitude: 42.375)
        #expect(abs(converted - pointsPerMeter * 1_000) / converted < 0.01)
    }

    /// GIS-005 / GIS-011: approximate fixes never get a crisp dot; invalid ones get none.
    @Test func markerStyleFollowsRealAccuracy() {
        let size = CGSize(width: 120, height: 120)
        #expect(LocationMarkerStyle.make(accuracyMeters: 50, isApproximate: false, glyphSize: size) { $0 * 0.01 } == .precise)
        #expect(LocationMarkerStyle.make(accuracyMeters: 50, isApproximate: true, glyphSize: size) { $0 * 0.01 } == .area(radius: LocationMarkerStyle.preciseRadiusLimit))
        #expect(LocationMarkerStyle.make(accuracyMeters: 3_000, isApproximate: true, glyphSize: size) { $0 * 0.01 } == .area(radius: 30))
        #expect(LocationMarkerStyle.make(accuracyMeters: 20_000, isApproximate: true, glyphSize: size) { $0 * 0.01 } == .hidden)
        #expect(LocationMarkerStyle.make(accuracyMeters: -1, isApproximate: false, glyphSize: size) { CGFloat($0) } == .hidden)
    }

    /// Containment reports inside/outside and the distance to the nearest edge.
    @Test func containmentReportsInsideAndEdgeDistance() throws {
        let boundary = collection(.polygon([
            ring(minLon: -71.12, minLat: 42.36, maxLon: -71.08, maxLat: 42.39),
            ring(minLon: -71.105, minLat: 42.37, maxLon: -71.095, maxLat: 42.38)
        ]))

        let inside = try #require(BoundaryContainment.test(CLLocationCoordinate2D(latitude: 42.365, longitude: -71.10), in: boundary))
        #expect(inside.isInside)
        #expect(abs(inside.edgeDistanceMeters - 553) < 20)

        let inHole = try #require(BoundaryContainment.test(CLLocationCoordinate2D(latitude: 42.375, longitude: -71.10), in: boundary))
        #expect(inHole.isInside == false)

        let outside = try #require(BoundaryContainment.test(CLLocationCoordinate2D(latitude: 42.40, longitude: -71.10), in: boundary))
        #expect(outside.isInside == false)
    }

    // MARK: - Fixtures

    private func squareBoundary() -> GeoJSONFeatureCollection {
        collection(.polygon([ring(minLon: 0, minLat: 0, maxLon: 1, maxLat: 1)]))
    }

    private func ring(minLon: Double, minLat: Double, maxLon: Double, maxLat: Double) -> [[Double]] {
        [[minLon, minLat], [maxLon, minLat], [maxLon, maxLat], [minLon, maxLat], [minLon, minLat]]
    }

    private func collection(_ geometry: GeoJSONGeometry) -> GeoJSONFeatureCollection {
        GeoJSONFeatureCollection(
            type: "FeatureCollection",
            features: [GeoJSONFeature(type: "Feature", properties: nil, geometry: geometry)]
        )
    }
}
