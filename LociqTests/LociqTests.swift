//
//  LociqTests.swift
//  LociqTests
//
//  Verifies snapshot formatting, display values, names, and cache decoding behavior.
//
//  These tests cover small pure transformations that should remain stable even
//  as service and UI code changes. Number formatting is pinned to en_US so the
//  results do not depend on the simulator's region.
//

import CoreLocation
import Foundation
import Testing
@testable import Lociq

@MainActor
/// Core formatting, snapshot, and cache compatibility tests.
struct LociqTests {
    private static let enUS = Locale(identifier: "en_US")

    // MARK: - Formatting

    /// Compact numeric and currency formatting.
    @Test func formatsNumberAndCurrencyValues() async throws {
        #expect(DemographicValueFormatter.number(12345, locale: Self.enUS) == "12,345")
        #expect(DemographicValueFormatter.currency(987654, locale: Self.enUS) == "$987,654")
    }

    /// Unavailable numeric values render as the minimal unavailable marker.
    @Test func formatsUnavailableValuesMinimally() async throws {
        #expect(DemographicValueFormatter.number(nil) == "--")
        #expect(DemographicValueFormatter.currency(nil) == "--")
        #expect(DemographicValueFormatter.percent(nil) == "--")
    }

    /// Percent and minute values are rounded to keep the UI compact.
    @Test func formatsPercentAndMinutes() async throws {
        #expect(DemographicValueFormatter.percent(64.7) == "65%")
        #expect(DemographicValueFormatter.minutes(27.2) == "27 MIN")
    }

    /// GIS-012: medians in an open-ended interval keep their Census annotation.
    @Test func topCodedMediansKeepTheirAnnotation() async throws {
        #expect(DemographicValueFormatter.currency(250_000, bound: .atLeast, locale: Self.enUS) == "$250,000+")
        #expect(DemographicValueFormatter.currency(2_500, bound: .atMost, locale: Self.enUS) == "$2,500-")
    }

    // MARK: - Density (GIS-001)

    /// Density uses Census land area and two significant figures.
    @Test func densityUsesLandAreaAndRoundsToTwoFigures() async throws {
        let density = try #require(
            CityDensityCalculator.peoplePerSquareMile(population: 830_000, landAreaSquareMeters: 120_913_549)
        )
        #expect(abs(density - 17_779) / 17_779 < 0.01)
        #expect(CityDensityCalculator.formatted(density, locale: Self.enUS) == "18,000 / SQ MI")
        #expect(CityDensityCalculator.peoplePerSquareMile(population: 830_000, landAreaSquareMeters: nil) == nil)
    }

    /// A tiny population over a large area never renders as zero.
    @Test func densityNeverRendersZero() async throws {
        let density = try #require(
            CityDensityCalculator.peoplePerSquareMile(population: 1, landAreaSquareMeters: 6.4 * CityDensityCalculator.squareMetersPerSquareMile)
        )
        #expect(CityDensityCalculator.formatted(density, locale: Self.enUS) == "<1 / SQ MI")
        #expect(CityDensityCalculator.peoplePerSquareMile(population: 0, landAreaSquareMeters: 1_000) == nil)
    }

    /// Snapshots compute density from the boundary's land area, and older boundaries show none.
    @Test func snapshotDensityComesFromLandArea() async throws {
        let withArea = DemographicSnapshot(profile: Self.cambridgeProfile(landArea: "16567881"), demographics: Self.cambridgeDemographics())
        let density = try #require(withArea.densityPerSquareMile)
        #expect(abs(density - 118_214 / (16_567_881 / CityDensityCalculator.squareMetersPerSquareMile)) < 1)

        let withoutArea = DemographicSnapshot(profile: Self.cambridgeProfile(landArea: nil), demographics: Self.cambridgeDemographics())
        #expect(withoutArea.densityPerSquareMile == nil)
    }

    // MARK: - Snapshot

    /// Snapshots use city/place-level demographics, typed metrics, and the state.
    @Test func cityProfileSnapshotUsesPlaceLevelDemographics() async throws {
        let snapshot = DemographicSnapshot(profile: Self.cambridgeProfile(), demographics: Self.cambridgeDemographics())

        #expect(snapshot.market == "CAMBRIDGE, MA")
        #expect(snapshot.statusLine == "")
        #expect(snapshot.metrics.map(\.kind) == [.population, .income, .households, .ownerOccupied, .education])
        #expect(snapshot.metrics.first?.count == 118_214)
        #expect(snapshot.metrics.first?.detail == "MEDIAN AGE 30.8")
        #expect(snapshot.detailSections.map { $0.title } == ["AGE", "HOUSING", "MOBILITY"])
        #expect(snapshot.dataVintage == CensusDataVintage.current.identifier)
    }

    /// VIS-005: the owner metric names the renter share, and both come from one rounded value.
    @Test func ownerAndRenterSharesAlwaysSumTo100() async throws {
        let snapshot = DemographicSnapshot(profile: Self.cambridgeProfile(), demographics: Self.cambridgeDemographics())
        let owner = try #require(snapshot.metrics.first { $0.kind == .ownerOccupied })

        #expect(owner.primaryValue == "35%")
        #expect(owner.detail == "65% RENTERS")
        #expect(owner.barFraction == 0.35)
    }

    /// UX-010: share text has no dangling separators and names the source period.
    @Test func shareTextIsCleanAndNamesVintage() async throws {
        let snapshot = DemographicSnapshot(profile: Self.cambridgeProfile(), demographics: Self.cambridgeDemographics())
        let text = try #require(snapshot.shareText)

        #expect(!text.contains("— \n"))
        #expect(!text.hasSuffix("— "))
        #expect(text.contains("CAMBRIDGE, MA"))
        #expect(text.contains("U.S. Census Bureau ACS \(CensusDataVintage.current.periodLabel) 5-year estimates"))
        #expect(text.contains("OWNER OCCUPIED: 35% — 65% RENTERS"))
        #expect(text.contains("DENSITY:"))
    }

    /// UX-004 / GIS-007: every failure has a heading and a different plain-language line.
    @Test func statusSnapshotsExplainEveryFailure() async throws {
        let failures: [CityProfileLoadFailure] = [
            .networkUnavailable, .timedOut, .serviceUnavailable, .cityUnavailable,
            .outsideCoverage, .demographicsUnavailable, .censusKeyMissing
        ]
        var lines = Set<String>()
        for failure in failures {
            let snapshot = DemographicSnapshot.unavailable(failure)
            #expect(!snapshot.market.isEmpty)
            #expect(!snapshot.statusLine.isEmpty)
            #expect(snapshot.market != snapshot.statusLine)
            #expect(!snapshot.statusLine.contains("ACS") && !snapshot.market.contains("ACS"))
            #expect(!snapshot.statusLine.contains("CENSUS KEY") && !snapshot.market.contains("CENSUS KEY"))
            lines.insert(snapshot.statusLine)
        }
        #expect(lines.count == failures.count)

        let outside = DemographicSnapshot.unavailable(.cityUnavailable, placeTitle: nil, countyTitle: "Middlesex County, MA")
        #expect(outside.market == "OUTSIDE CITY LIMITS")
        #expect(outside.statusLine == "MIDDLESEX COUNTY, MA")
        #expect(DemographicSnapshot.unavailable(.outsideCoverage).market == "OUTSIDE U.S. COVERAGE")
    }

    // MARK: - Names (GIS-009)

    /// Titles use Census base names, the "(balance)" table, and the state.
    @Test func placeNamesUseBaseNamesAndState() async throws {
        let cases: [(PlaceInfo, String)] = [
            (PlaceInfo(name: "Juneau city and borough", baseName: "Juneau", stateFIPS: "02", placeFIPS: "36400", type: .incorporatedPlace), "JUNEAU, AK"),
            (PlaceInfo(name: "Indianapolis city (balance)", baseName: "Indianapolis city (balance)", stateFIPS: "18", placeFIPS: "36003", type: .incorporatedPlace), "INDIANAPOLIS, IN"),
            (PlaceInfo(name: "Nashville-Davidson metropolitan government (balance)", baseName: "Nashville-Davidson metropolitan government (balance)", stateFIPS: "47", placeFIPS: "52006", type: .incorporatedPlace), "NASHVILLE, TN"),
            (PlaceInfo(name: "Louisville/Jefferson County metro government (balance)", baseName: "Louisville/Jefferson County metro government (balance)", stateFIPS: "21", placeFIPS: "48006", type: .incorporatedPlace), "LOUISVILLE, KY"),
            (PlaceInfo(name: "Anchorage municipality", baseName: "Anchorage", stateFIPS: "02", placeFIPS: "03000", type: .incorporatedPlace), "ANCHORAGE, AK"),
            (PlaceInfo(name: "Monowi village", baseName: "Monowi", stateFIPS: "31", placeFIPS: "32550", type: .incorporatedPlace), "MONOWI, NE"),
            (PlaceInfo(name: "San Juan zona urbana", baseName: "San Juan", stateFIPS: "72", placeFIPS: "76770", type: .censusDesignatedPlace), "SAN JUAN, PR")
        ]
        for (place, expected) in cases {
            #expect(DemographicValueFormatter.placeTitle(for: place).uppercased() == expected)
        }
    }

    /// Without a base name, only a trailing legal descriptor is removed.
    @Test func descriptorRemovalNeverMangles() async throws {
        #expect(DemographicValueFormatter.cleanGeographyName("Juneau city and borough") == "Juneau")
        #expect(DemographicValueFormatter.cleanGeographyName("Indianapolis city (balance)") == "Indianapolis")
        #expect(DemographicValueFormatter.cleanGeographyName("Town and Country city") == "Town and Country")
        #expect(DemographicValueFormatter.cleanGeographyName("Carson City") == "Carson City")
        #expect(DemographicValueFormatter.cleanGeographyName("Cambridge city, Massachusetts") == "Cambridge, Massachusetts")
    }

    // MARK: - Cache compatibility (CODE-001)

    /// Legacy cached profiles without newer optional fields still decode.
    @Test func cachedCityProfileDecodesCacheWithoutHorizontalAccuracy() async throws {
        let data = try #require(Self.legacyPayload(metricsJSON: """
            [{"title": "POPULATION", "primaryValue": "118,214", "detail": "MEDIAN AGE 30.8"}]
            """).data(using: .utf8))
        let profile = try JSONDecoder().decode(CachedCityProfile.self, from: data)

        #expect(profile.snapshot.market == "CAMBRIDGE")
        #expect(profile.horizontalAccuracy == nil)
        #expect(profile.coordinate.latitude == 42.3736)
        #expect(profile.coordinate.longitude == -71.1056)
        #expect(profile.resolvedPlaceGeoid == "2511000")
        #expect(profile.isCurrent(for: .current) == false)
    }

    /// A payload written by builds up to 1.3.0 (RENTERS metric set) renders the current layout.
    @Test func decodes1_3_0CachePayload() async throws {
        let data = try #require(Self.legacyPayload(metricsJSON: """
            [
              {"title": "POPULATION", "primaryValue": "118,214", "detail": "MEDIAN AGE 30.8"},
              {"title": "HOUSEHOLDS", "primaryValue": "51,000", "detail": "OCCUPIED HOMES"},
              {"title": "INCOME", "primaryValue": "$121,539", "detail": "MEDIAN HOUSEHOLD"},
              {"title": "RENTERS", "primaryValue": "65%", "detail": "35% OWNER OCCUPIED"},
              {"title": "EDUCATION", "primaryValue": "81%", "detail": "BACHELOR'S OR HIGHER"}
            ]
            """).data(using: .utf8))
        let profile = try JSONDecoder().decode(CachedCityProfile.self, from: data).normalizedForDisplay()
        let metrics = profile.snapshot.metrics

        #expect(metrics.map(\.resolvedKind) == [.population, .income, .households, .ownerOccupied, .education])
        let owner = try #require(metrics.first { $0.resolvedKind == .ownerOccupied })
        #expect(owner.primaryValue == "35%")
        #expect(owner.detail == "65% RENTERS")
        #expect(owner.barFraction == 0.35)
        #expect(metrics.last?.barFraction == 0.81)
    }

    /// The current schema round-trips losslessly.
    @Test func currentSchemaRoundTrips() async throws {
        let original = CachedCityProfile(
            snapshot: DemographicSnapshot(profile: Self.cambridgeProfile(), demographics: Self.cambridgeDemographics()),
            boundary: Self.sampleBoundary(landArea: "16567881"),
            latitude: 42.3736,
            longitude: -71.1056,
            horizontalAccuracy: 65,
            cachedAt: Date(timeIntervalSinceReferenceDate: 1_000),
            placeGeoid: "2511000",
            isApproximate: true
        )
        let decoded = try JSONDecoder().decode(CachedCityProfile.self, from: JSONEncoder().encode(original))

        #expect(decoded.snapshot.metrics.map(\.kind) == original.snapshot.metrics.map(\.kind))
        #expect(decoded.snapshot.densityPerSquareMile == original.snapshot.densityPerSquareMile)
        #expect(decoded.placeGeoid == "2511000")
        #expect(decoded.isApproximate == true)
        #expect(decoded.formatVersion == CachedCityProfile.currentFormatVersion)
        #expect(decoded.boundary?.landAreaSquareMeters == 16_567_881)
        #expect(decoded.isCurrent(for: .current))
    }
}

// MARK: - Fixtures

extension LociqTests {
    /// A Cambridge demographic fixture.
    nonisolated static func cambridgeDemographics() -> Demographics {
        Demographics(
            name: "Cambridge city, Massachusetts",
            population: PopulationDemographics(total: 118_214),
            income: IncomeDemographics(medianHousehold: 121_539),
            age: AgeDemographics(median: 30.8, under18Pct: 12.0, age18To34Pct: 43.0, age35To64Pct: 32.0, age65PlusPct: 13.0),
            housing: HousingDemographics(
                medianHomeValue: 940_000,
                medianGrossRent: 2_475,
                ownerOccupied: 18_000,
                renterOccupied: 33_000,
                ownerOccupiedPct: 35.3,
                totalUnits: 54_000,
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
            )
        )
    }

    /// A resolved Cambridge profile with an optional land area on its boundary.
    static func cambridgeProfile(landArea: String? = "16567881") -> ResolvedCityProfile {
        ResolvedCityProfile(
            geography: CityGeographyProfile(
                county: CountyInfo(name: "Middlesex County", stateFIPS: "25", countyFIPS: "017", geoid: "25017"),
                place: PlaceInfo(
                    name: "Cambridge city",
                    baseName: "Cambridge",
                    stateFIPS: "25",
                    placeFIPS: "11000",
                    type: .incorporatedPlace
                )
            ),
            boundarySet: CityBoundarySet(city: sampleBoundary(landArea: landArea)),
            demographics: CityDemographicsBundle(place: cambridgeDemographics())
        )
    }

    /// A rectangular boundary fixture with optional land area.
    static func sampleBoundary(landArea: String?) -> GeoJSONFeatureCollection {
        var properties: [String: GeoJSONPropertyValue] = ["GEOID": .string("2511000")]
        if let landArea { properties["AREALAND"] = .string(landArea) }
        return GeoJSONFeatureCollection(
            type: "FeatureCollection",
            features: [
                GeoJSONFeature(
                    type: "Feature",
                    properties: properties,
                    geometry: .polygon([
                        [[-71.12, 42.36], [-71.08, 42.36], [-71.08, 42.39], [-71.12, 42.39], [-71.12, 42.36]]
                    ])
                )
            ]
        )
    }

    /// A `lociq.lastCityProfile.v1` payload as written by earlier builds.
    static func legacyPayload(metricsJSON: String) -> String {
        """
        {
          "snapshot": {
            "market": "CAMBRIDGE",
            "dateLabel": "",
            "cadence": "",
            "mode": "DEMOGRAPHICS",
            "confidence": 0.84,
            "hasDemographicData": true,
            "metrics": \(metricsJSON),
            "detailSections": [
              {"title": "HOUSING", "rows": [{"label": "VACANCY", "value": "6%"}]}
            ]
          },
          "boundary": {
            "type": "FeatureCollection",
            "features": [
              {
                "type": "Feature",
                "properties": {"STATE": "25", "PLACE": "11000", "GEOID": "2511000", "NAME": "Cambridge city"},
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
    }
}
