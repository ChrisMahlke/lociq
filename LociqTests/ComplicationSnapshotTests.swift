//
//  ComplicationSnapshotTests.swift
//  LociqTests
//
//  Verifies the record the Apple Watch app leaves for its complications.
//
//  Complications cannot check where the wearer is, so only a definite answer
//  becomes a record, it carries no coordinates, and it always says when it
//  was true.
//

import CoreGraphics
import CoreLocation
import Foundation
import SwiftUI
import Testing
@testable import Lociq

@MainActor
/// Tests for `ComplicationSnapshot`, its builder, its store, and `SpokenText`.
struct ComplicationSnapshotTests {
    private static let enUS = Locale(identifier: "en_US")

    /// Only the current city, or a place without city data, is a definite answer.
    @Test func placeAnswerIsDefiniteOnlyForCurrentCityOrNoCity() {
        let profile = LocationProfileViewModelTests.cachedProfile()
        func answer(_ state: LocationProfileViewModel.State) -> PlaceAnswer {
            LocationProfileViewStateMapper.make(from: state, debugCoordinate: nil).placeAnswer
        }

        #expect(answer(.loaded(profile, status: .current)) == .city)
        #expect(answer(.loaded(profile, status: .lastKnownArea)) == .unknown)
        #expect(answer(.loaded(profile, status: .notCurrentLocation)) == .unknown)
        #expect(answer(.loaded(profile, status: .locationOff(restricted: false))) == .unknown)
        #expect(answer(.refreshing(profile, context: .sameArea)) == .unknown)
        #expect(answer(.profileUnavailable(LocationProfileViewModelTests.unavailable(.cityUnavailable))) == .noCity)
        #expect(answer(.profileUnavailable(LocationProfileViewModelTests.unavailable(.outsideCoverage))) == .noCity)
        #expect(answer(.profileUnavailable(LocationProfileViewModelTests.unavailable(.networkUnavailable))) == .unknown)
        #expect(answer(.locationUnavailable(.denied)) == .unknown)
        #expect(answer(.loading) == .unknown)
    }

    /// The current city becomes a city record with a simplified outline.
    @Test func currentCityBecomesACityRecord() throws {
        let profile = LocationProfileViewModelTests.cachedProfile()
        let viewState = LocationProfileViewStateMapper.make(from: .loaded(profile, status: .current), debugCoordinate: nil)
        let boundary = try #require(profile.boundary)
        let glyph = try #require(GeoJSONBoundaryPathBuilder.glyph(for: boundary, focus: profile.markerCoordinate))
        let confirmedAt = Date(timeIntervalSinceReferenceDate: 800_000_000)

        let record = try #require(ComplicationSnapshot(viewState: viewState, glyph: glyph, confirmedAt: confirmedAt, locale: Self.enUS))

        #expect(record.kind == .city)
        #expect(record.title == "CAMBRIDGE, MA")
        #expect(record.shortTitle == "CAMBRIDGE")
        #expect(record.population == "118,214")
        #expect(record.compactPopulation == "118K")
        #expect(!record.outline.isEmpty)
        #expect(record.outlineSize == glyph.unitSize)
        #expect(record.confirmedAt == confirmedAt)
    }

    /// Outside city limits becomes a message record that names the county.
    @Test func outsideCityLimitsBecomesAMessageRecord() throws {
        let unavailable = LocationProfileViewModelTests.unavailable(.cityUnavailable, countyTitle: "Eureka County, NV")
        let viewState = LocationProfileViewStateMapper.make(from: .profileUnavailable(unavailable), debugCoordinate: nil)

        let record = try #require(ComplicationSnapshot(viewState: viewState, glyph: nil, confirmedAt: Date()))

        #expect(record.kind == .message)
        #expect(record.title == "OUTSIDE CITY LIMITS")
        #expect(record.subtitle == "EUREKA COUNTY, NV")
        #expect(record.outline.isEmpty)
        #expect(record.population == nil)
    }

    /// A saved city that may not be the wearer's place writes no record.
    @Test func uncertainPlaceWritesNoRecord() {
        let profile = LocationProfileViewModelTests.cachedProfile()
        let statuses: [ProfileStatus] = [.lastLocation, .lastKnownArea, .notCurrentLocation, .locationOff(restricted: false)]
        for status in statuses {
            let viewState = LocationProfileViewStateMapper.make(from: .loaded(profile, status: status), debugCoordinate: nil)
            #expect(ComplicationSnapshot(viewState: viewState, glyph: nil, confirmedAt: Date()) == nil, "\(status)")
        }
    }

    /// Simplification keeps the outline's extent and far fewer points.
    @Test func outlineSimplificationKeepsExtentWithFewerPoints() {
        let circle = (0..<2_000).map { index -> CGPoint in
            let angle = Double(index) / 2_000 * 2 * .pi
            return CGPoint(x: 0.5 + 0.5 * cos(angle), y: 0.5 + 0.5 * sin(angle))
        }
        var path = Path()
        path.addLines(circle)
        path.closeSubpath()

        let rings = ComplicationSnapshot.rings(of: path)
        #expect(rings.count == 1)
        #expect(rings.first?.count == 2_000)

        let points = ComplicationSnapshot.simplify(rings, tolerance: 0.002).flatMap { $0 }
        #expect(points.count > 16)
        #expect(points.count < 200)
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        #expect(abs((xs.max() ?? 0) - 1) < 0.01)
        #expect(abs(xs.min() ?? 1) < 0.01)
        #expect(abs((ys.max() ?? 0) - 1) < 0.01)
        #expect(abs(ys.min() ?? 1) < 0.01)
    }

    /// Rings too small to see at complication sizes are dropped.
    @Test func tinyRingsAreDropped() {
        let island = [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.101, y: 0.1), CGPoint(x: 0.1, y: 0.101)]
        #expect(ComplicationSnapshot.simplify([island], tolerance: 0.002).isEmpty)
    }

    /// A record survives a write and a read.
    @Test func storeRoundTripsARecord() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lociq-complication-\(UUID().uuidString)", isDirectory: true)
        let store = ComplicationSnapshotStore(directory: directory)
        let record = Self.record(confirmedAt: Date(timeIntervalSinceReferenceDate: 800_000_000))

        #expect(store.load() == nil)
        #expect(store.save(record))
        #expect(store.load() == record)
    }

    /// "AS OF" gives the time that day and the date after it.
    @Test func asOfLabelShowsTimeThenDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let confirmed = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 9, minute: 41)))
        let evening = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 21)))
        let nextMorning = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 8)))
        let record = Self.record(confirmedAt: confirmed)

        // Formatters may put a narrow no-break space before AM.
        func label(now: Date) -> String {
            record.asOfLabel(now: now, calendar: calendar, locale: Self.enUS).replacingOccurrences(of: "\u{202F}", with: " ")
        }
        #expect(label(now: evening) == "AS OF 9:41 AM")
        #expect(label(now: nextMorning) == "AS OF SEP 27")
        #expect(record.isConfirmed(onSameDayAs: evening, calendar: calendar))
        #expect(record.isConfirmed(onSameDayAs: nextMorning, calendar: calendar) == false)
    }

    /// VoiceOver text keeps state codes and AM or PM uppercase.
    @Test func spokenTitlesKeepCodesUppercase() {
        #expect(SpokenText.title("SAN FRANCISCO, CA") == "San Francisco, CA")
        #expect(SpokenText.title("EUREKA COUNTY, NV") == "Eureka County, NV")
        #expect(SpokenText.title("AS OF 9:41 AM") == "As Of 9:41 AM")
        #expect(SpokenText.title("OUTSIDE CITY LIMITS") == "Outside City Limits")
        #expect(SpokenText.title("") == "")
    }

    private static func record(confirmedAt: Date) -> ComplicationSnapshot {
        ComplicationSnapshot(
            kind: .city,
            title: "CAMBRIDGE, MA",
            shortTitle: "CAMBRIDGE",
            subtitle: "",
            population: "118,214",
            compactPopulation: "118K",
            outline: [[CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0.5, y: 1)]],
            outlineSize: CGSize(width: 1, height: 1),
            confirmedAt: confirmedAt
        )
    }
}
