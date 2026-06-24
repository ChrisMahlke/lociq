//
//  LociqTests.swift
//  LociqTests
//
//  Verifies snapshot formatting, display values, and cache decoding behavior.
//
//  These tests cover small pure transformations that should remain stable even
//  as service and UI code changes.
//

import CoreLocation
import Foundation
import Testing
@testable import Lociq

@MainActor
/// Core formatting, snapshot, and cache compatibility tests.
struct LociqTests {
    /// Verifies compact numeric and currency formatting.
    ///
    /// These values protect the display contract used by summary metrics.
    @Test func formatsNumberAndCurrencyValues() async throws {
        #expect(DemographicValueFormatter.number(12345) == "12,345")
        #expect(DemographicValueFormatter.currency(987654) == "$987,654")
    }

    /// Verifies unavailable numeric values render as the minimal unavailable marker.
    ///
    /// The marker is intentionally shared across number, currency, and percent
    /// formatting.
    @Test func formatsUnavailableValuesMinimally() async throws {
        #expect(DemographicValueFormatter.number(nil) == "--")
        #expect(DemographicValueFormatter.currency(nil) == "--")
        #expect(DemographicValueFormatter.percent(nil) == "--")
    }

    /// Verifies percent and duration formatting.
    ///
    /// Percent and minute values are rounded to keep the UI compact.
    @Test func formatsPercentAndMinutes() async throws {
        #expect(DemographicValueFormatter.percent(64.7) == "65%")
        #expect(DemographicValueFormatter.minutes(27.2) == "27 MIN")
    }

    /// Verifies snapshots use city/place-level demographics and no longer expose ZIP or tract labels.
    ///
    /// This protects a product decision: the displayed place name and metrics
    /// should refer to the city or CDP profile, not tract or block-group data.
    @Test func cityProfileSnapshotUsesPlaceLevelDemographics() async throws {
        let demographics = Self.cambridgeDemographics()
        let profile = ResolvedCityProfile(
            geography: CityGeographyProfile(
                county: CountyInfo(
                    name: "Middlesex County",
                    stateFIPS: "25",
                    countyFIPS: "017",
                    geoid: "25017"
                ),
                place: PlaceInfo(
                    name: "Cambridge city, Massachusetts",
                    stateFIPS: "25",
                    placeFIPS: "11000",
                    type: .incorporatedPlace
                )
            ),
            boundarySet: CityBoundarySet(city: Self.sampleBoundary()),
            demographics: CityDemographicsBundle(
                place: demographics
            )
        )

        let snapshot = DemographicSnapshot(profile: profile, demographics: demographics)

        #expect(snapshot.market == "CAMBRIDGE, MASSACHUSETTS")
        #expect(snapshot.dateLabel == "")
        #expect(snapshot.metrics.first?.title == "POPULATION")
        #expect(snapshot.metrics.first?.primaryValue == "118,214")
        #expect(snapshot.metrics.first?.detail == "MEDIAN AGE 30.8")
        #expect(snapshot.detailSections.map { $0.title } == ["AGE", "HOUSING", "MOBILITY"])
    }

    /// Verifies legacy cached profiles without newer optional fields still decode.
    ///
    /// The cache schema has evolved. This test ensures older installations can
    /// still launch with their last saved profile.
    @Test func cachedCityProfileDecodesCacheWithoutHorizontalAccuracy() async throws {
        let legacyCacheJSON = """
        {
          "snapshot": {
            "market": "CAMBRIDGE, MASSACHUSETTS",
            "dateLabel": "",
            "cadence": "",
            "mode": "DEMOGRAPHICS",
            "confidence": 0.84,
            "hasDemographicData": true,
            "metrics": [
              {
                "title": "POPULATION",
                "primaryValue": "118,214",
                "detail": "MEDIAN AGE 30.8"
              }
            ],
            "detailSections": []
          },
          "boundary": {
            "type": "FeatureCollection",
            "features": [
              {
                "type": "Feature",
                "properties": {},
                "geometry": {
                  "type": "Polygon",
                  "coordinates": [[[-71.12, 42.36], [-71.08, 42.36], [-71.08, 42.39], [-71.12, 42.39], [-71.12, 42.36]]]
                }
              }
            ]
          },
          "latitude": 42.3736,
          "longitude": -71.1056
        }
        """

        let data = try #require(legacyCacheJSON.data(using: .utf8))
        let profile = try JSONDecoder().decode(CachedCityProfile.self, from: data)

        #expect(profile.snapshot.market == "CAMBRIDGE, MASSACHUSETTS")
        #expect(profile.horizontalAccuracy == nil)
        #expect(profile.coordinate.latitude == 42.3736)
        #expect(profile.coordinate.longitude == -71.1056)
    }
}

private extension LociqTests {
    /// Creates a Cambridge demographic fixture.
    ///
    /// The fixture contains enough fields to populate both summary metrics and
    /// all detail sections.
    static func cambridgeDemographics() -> Demographics {
        Demographics(
            name: "Cambridge city, Massachusetts",
            population: PopulationDemographics(total: 118_214),
            income: IncomeDemographics(medianHousehold: 121_539),
            age: AgeDemographics(
                median: 30.8,
                under18Pct: 12.0,
                age18To34Pct: 43.0,
                age35To64Pct: 32.0,
                age65PlusPct: 13.0
            ),
            housing: HousingDemographics(
                units: 54_000,
                medianHomeValue: 940_000,
                medianGrossRent: 2_475,
                averageHouseholdSize: 2.1,
                ownerOccupied: 18_000,
                renterOccupied: 33_000,
                ownerOccupiedPct: 35.3,
                renterOccupiedPct: 64.7,
                vacantUnits: 3_000,
                vacancyRatePct: 5.6
            ),
            education: EducationDemographics(bachelorsOrHigherPct: 81.0),
            mobility: MobilityDemographics(
                workersTotal: 72_000,
                workersWfh: 19_000,
                workersWfhPct: 26.4,
                transitCommuters: 18_500,
                transitCommutersPct: 25.7,
                averageCommuteMinutes: 27.2
            ),
            poverty: PovertyDemographics(
                universe: 112_000,
                below: 13_500,
                ratePct: 12.1
            ),
            raceEthnicity: RaceEthnicityDemographics(
                whiteAlone: 74_000,
                blackAlone: 10_000,
                asianAlone: 20_000,
                hispanicOrLatino: 9_000
            )
        )
    }

    /// Creates a simple GeoJSON boundary fixture.
    ///
    /// The fixture is valid but intentionally rectangular so tests focus on
    /// cache and snapshot behavior rather than boundary geometry complexity.
    static func sampleBoundary() -> GeoJSONFeatureCollection {
        GeoJSONFeatureCollection(
            type: "FeatureCollection",
            features: [
                GeoJSONFeature(
                    type: "Feature",
                    properties: [:],
                    geometry: .polygon([
                        [
                            [-71.12, 42.36],
                            [-71.08, 42.36],
                            [-71.08, 42.39],
                            [-71.12, 42.39],
                            [-71.12, 42.36]
                        ]
                    ])
                )
            ]
        )
    }
}
