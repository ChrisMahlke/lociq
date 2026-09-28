//
//  CensusDataParsingTests.swift
//  LociqTests
//
//  Verifies ACS mapping math and tolerant decoding of Census responses.
//
//  The mapper is where Census table universes become displayed percentages, so
//  each derived value is pinned here. The decoding tests cover documented
//  Census values that used to fail a whole response.
//

import CoreLocation
import Foundation
import Testing
@testable import Lociq

@MainActor
/// Tests for `ACSDemographicsMapper`, `ACSTableResponse`, and GeoJSON property decoding.
struct CensusDataParsingTests {
    // MARK: - Mapper (GIS-002, CODE-009 #5–6)

    /// GIS-002: average commute divides by workers who did not work from home.
    @Test func averageCommuteExcludesWorkFromHome() throws {
        let demographics = try ACSDemographicsMapper(
            valuesByKey: [
                "B01003_001E": "100000",
                "B08013_001E": "1000000",
                "B08301_001E": "50000",
                "B08301_021E": "10000"
            ],
            fallbackName: "Test"
        ).makeDemographics()

        #expect(demographics.mobility.averageCommuteMinutes == 25.0)
        #expect(demographics.mobility.workersWfhPct == 20.0)
    }

    /// Percentages use their ACS table universes, and zero denominators give nil.
    @Test func percentagesUseTableUniverses() throws {
        var values = [
            "B01003_001E": "1000",
            "B01001_001E": "1000",
            "B01001_003E": "100",
            "B01001_027E": "100",
            "B25003_002E": "300",
            "B25003_003E": "100",
            "B25002_001E": "500",
            "B25002_003E": "100",
            "B15003_001E": "800",
            "B15003_022E": "200",
            "B15003_023E": "100",
            "B15003_024E": "50",
            "B15003_025E": "50",
            "B08301_001E": "0",
            "B08301_010E": "0"
        ]
        let demographics = try ACSDemographicsMapper(valuesByKey: values, fallbackName: "Test").makeDemographics()

        #expect(demographics.age.under18Pct == 20.0)
        #expect(demographics.housing.ownerOccupiedPct == 75.0)
        #expect(demographics.housing.vacancyRatePct == 20.0)
        #expect(demographics.education.bachelorsOrHigherPct == 50.0)
        #expect(demographics.mobility.transitCommutersPct == nil)

        values["B01003_001E"] = "-666666666"
        #expect(throws: CensusServiceError.noDemographicsFound) {
            try ACSDemographicsMapper(valuesByKey: values, fallbackName: "Test").makeDemographics()
        }
    }

    /// GIS-012: a top-coded median uses the annotated bound, not the coded estimate.
    @Test func topCodedMedianUsesAnnotationBound() throws {
        let demographics = try ACSDemographicsMapper(
            valuesByKey: [
                "B01003_001E": "7000",
                "B19013_001E": "250001",
                "B19013_001EA": "250,000+",
                "B25077_001E": "2000001",
                "B25077_001EA": "2,000,000+",
                "B25064_001E": "2476"
            ],
            fallbackName: "Test"
        ).makeDemographics()

        #expect(demographics.income.medianHousehold == 250_000)
        #expect(demographics.income.medianHouseholdBound == .atLeast)
        #expect(demographics.housing.medianHomeValue == 2_000_000)
        #expect(demographics.housing.medianGrossRent == 2_476)
        #expect(demographics.housing.medianGrossRentBound == nil)
        #expect(ACSValueNormalizer.medianBound("-") == nil)
        #expect(ACSValueNormalizer.medianBound("(X)") == nil)
        #expect(ACSValueNormalizer.medianBound("2,500-")?.bound == .atMost)
    }

    /// GIS-012: without tenure, households are occupied units, never all units.
    @Test func householdsFallbackExcludesVacantUnits() throws {
        let demographics = try ACSDemographicsMapper(
            valuesByKey: ["B01003_001E": "2", "B25002_001E": "8", "B25002_003E": "6"],
            fallbackName: "Monowi village, Nebraska"
        ).makeDemographics()

        #expect(DemographicValueFormatter.households(from: demographics) == 2)
    }

    // MARK: - Decoding (CODE-006)

    /// A null ACS cell is unavailable, not fatal to the whole table.
    @Test func nullACSCellIsUnavailableNotFatal() throws {
        let data = Data(#"[["NAME","B01003_001E","B19013_001E","B19013_001EA","state","place"],["Test city, State","1200",null,null,"25","11000"]]"#.utf8)
        let values = try ACSTableResponse(data: data).valuesByKey()

        #expect(values["B01003_001E"] == "1200")
        #expect(values["B19013_001E"] == nil)
        let demographics = try ACSDemographicsMapper(valuesByKey: values, fallbackName: "Test").makeDemographics()
        #expect(DemographicValueFormatter.currency(demographics.income.medianHousehold) == "--")
    }

    /// A repeated column keeps its first value instead of trapping.
    @Test func duplicateHeaderKeepsFirstValue() throws {
        let data = Data(#"[["NAME","B01003_001E","B01003_001E"],["Test","10","20"]]"#.utf8)
        #expect(try ACSTableResponse(data: data).valuesByKey()["B01003_001E"] == "10")
    }

    /// A malformed table is a decode failure, not a crash.
    @Test func malformedTableIsDecodeFailure() {
        #expect(throws: CensusServiceError.self) {
            try ACSTableResponse(data: Data(#"{"error":"unknown variable"}"#.utf8))
        }
    }

    /// Numeric GeoJSON properties keep the feature and its geometry.
    @Test func numericGeoJSONPropertiesKeepGeometry() throws {
        let json = #"{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"GEOID":"2511000","AREALAND":16760000,"FUNCSTAT":null,"FLAG":true},"geometry":{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,0]]]}}]}"#
        let collection = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: Data(json.utf8))

        #expect(collection.features.first?.geometry != nil)
        #expect(collection.landAreaSquareMeters == 16_760_000)
        #expect(collection.geoid == "2511000")
    }

    /// Properties cached by earlier builds (strings and nulls) still decode and re-encode.
    @Test func legacyStringPropertiesRoundTrip() throws {
        let json = #"{"type":"Feature","properties":{"NAME":"Cambridge city","INTPTLAT":"+42.3760428","INTPTLON":"-071.1186798","EMPTY":null},"geometry":null}"#
        let feature = try JSONDecoder().decode(GeoJSONFeature.self, from: Data(json.utf8))
        let reencoded = try JSONDecoder().decode(GeoJSONFeature.self, from: JSONEncoder().encode(feature))

        #expect(reencoded.properties?["NAME"] == .string("Cambridge city"))
        #expect(reencoded.properties?["EMPTY"] == .null)
        let collection = GeoJSONFeatureCollection(type: "FeatureCollection", features: [feature])
        let point = try #require(collection.internalPoint)
        #expect(abs(point.latitude - 42.3760428) < 1e-9)
        #expect(abs(point.longitude - -71.1186798) < 1e-9)
    }
}
