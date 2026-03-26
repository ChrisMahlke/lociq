//
//  CensusZipDemographicsService.swift
//
//  Drop-in utility for:
//   lat/lon -> ZCTA (zip-like) + county + tract + place/incorporation
//         -> ZCTA boundary (GeoJSON) + boundary metrics + ACS demographics
//         -> plain-English insights (no extra network calls)
//
//  Notes:
//   - ZIPs are represented as ZCTAs (Census ZIP approximations).
//   - “City”/place is a Census “Place” polygon containing the point.
//   - Tract is a great “neighborhood-ish” unit; ZCTA is convenient but coarser.
//   - Boundary metrics are approximate and for UX only.
//
//  Created by Chris Mahlke on 3/4/26.
//

import Foundation
import CoreLocation

// MARK: - Public Models

public struct ZipLookupResult: Sendable {
    public let zcta: String                      // 5-digit ZCTA, e.g. "94025"
    public let county: CountyInfo?               // County name + FIPS
    public let tract: TractInfo?                 // Tract GEOID etc.
    public let place: PlaceInfo?                 // Place containing the point (if available)
    public let isIncorporatedPlace: Bool         // inside incorporated city limits?
    public let boundary: GeoJSONFeatureCollection
    public let boundaryMetrics: BoundaryMetrics? // derived metrics from boundary geometry
    public let demographics: Demographics        // richer ACS stats
    public let insights: [Insight]               // plain-English insights (no extra network calls)

    public init(
        zcta: String,
        county: CountyInfo?,
        tract: TractInfo?,
        place: PlaceInfo?,
        isIncorporatedPlace: Bool,
        boundary: GeoJSONFeatureCollection,
        boundaryMetrics: BoundaryMetrics?,
        demographics: Demographics,
        insights: [Insight]
    ) {
        self.zcta = zcta
        self.county = county
        self.tract = tract
        self.place = place
        self.isIncorporatedPlace = isIncorporatedPlace
        self.boundary = boundary
        self.boundaryMetrics = boundaryMetrics
        self.demographics = demographics
        self.insights = insights
    }
}

public struct NeighborhoodBoundarySet: Sendable {
    public let zip: GeoJSONFeatureCollection
    public let tract: GeoJSONFeatureCollection?
    public let block: GeoJSONFeatureCollection?

    public init(zip: GeoJSONFeatureCollection, tract: GeoJSONFeatureCollection?, block: GeoJSONFeatureCollection?) {
        self.zip = zip
        self.tract = tract
        self.block = block
    }
}

public enum NeighborhoodScale: Sendable {
    case zip
    case tract
}

public struct CountyInfo: Sendable {
    public let name: String
    public let stateFIPS: String?
    public let countyFIPS: String?
    public let geoid: String?

    public init(name: String, stateFIPS: String?, countyFIPS: String?, geoid: String?) {
        self.name = name
        self.stateFIPS = stateFIPS
        self.countyFIPS = countyFIPS
        self.geoid = geoid
    }
}

public struct TractInfo: Sendable {
    public let name: String?
    public let geoid: String?      // typically 11 digits: SSCCCTTTTTT
    public let stateFIPS: String?
    public let countyFIPS: String?
    public let tractCode: String?  // TTTTTT

    public init(name: String?, geoid: String?, stateFIPS: String?, countyFIPS: String?, tractCode: String?) {
        self.name = name
        self.geoid = geoid
        self.stateFIPS = stateFIPS
        self.countyFIPS = countyFIPS
        self.tractCode = tractCode
    }
}

/// Census “Place” info (city/town-ish). Not a USPS city name tied to a ZIP; it’s the Place polygon containing the coordinate.
public struct PlaceInfo: Sendable {
    public enum PlaceType: String, Sendable {
        case incorporatedPlace
        case censusDesignatedPlace
        case unknown
    }

    public let name: String
    public let stateFIPS: String?
    public let placeFIPS: String?
    public let type: PlaceType

    public init(name: String, stateFIPS: String?, placeFIPS: String?, type: PlaceType) {
        self.name = name
        self.stateFIPS = stateFIPS
        self.placeFIPS = placeFIPS
        self.type = type
    }
}

/// Derived from GeoJSON geometry.
public struct BoundaryMetrics: Sendable {
    public let centroid: CLLocationCoordinate2D?
    public let bbox: BoundingBox?
    public let areaKm2Approx: Double?
    public let perimeterKmApprox: Double?

    public init(
        centroid: CLLocationCoordinate2D?,
        bbox: BoundingBox?,
        areaKm2Approx: Double?,
        perimeterKmApprox: Double?
    ) {
        self.centroid = centroid
        self.bbox = bbox
        self.areaKm2Approx = areaKm2Approx
        self.perimeterKmApprox = perimeterKmApprox
    }
}

public struct BoundingBox: Sendable {
    public let minLat: Double
    public let minLon: Double
    public let maxLat: Double
    public let maxLon: Double
}

public struct Demographics: Sendable {
    public let name: String

    // Core
    public let population: Int?
    public let medianHouseholdIncome: Int?
    public let medianAge: Double?
    public let housingUnits: Int?

    // “Sticky” stats
    public let medianHomeValue: Int?          // B25077_001E
    public let medianGrossRent: Int?          // B25064_001E
    public let averageHouseholdSize: Double?  // B25010_001E

    // Owner/renter (counts and pct)
    public let ownerOccupied: Int?            // B25003_002E
    public let renterOccupied: Int?           // B25003_003E
    public let ownerOccupiedPct: Double?
    public let renterOccupiedPct: Double?

    // Work from home (counts and pct)
    public let workersTotal: Int?             // B08301_001E
    public let workersWfh: Int?               // B08301_021E (Worked at home)
    public let workersWfhPct: Double?

    // Poverty (counts and pct)
    public let povertyUniverse: Int?          // B17001_001E
    public let povertyBelow: Int?             // B17001_002E
    public let povertyRatePct: Double?

    // Example race counts (you can extend freely)
    public let whiteAlone: Int?               // B02001_002E
    public let blackAlone: Int?               // B02001_003E
    public let asianAlone: Int?               // B02001_005E
    public let hispanicOrLatino: Int?         // B03003_003E

    public init(
        name: String,
        population: Int?,
        medianHouseholdIncome: Int?,
        medianAge: Double?,
        housingUnits: Int?,
        medianHomeValue: Int?,
        medianGrossRent: Int?,
        averageHouseholdSize: Double?,
        ownerOccupied: Int?,
        renterOccupied: Int?,
        ownerOccupiedPct: Double?,
        renterOccupiedPct: Double?,
        workersTotal: Int?,
        workersWfh: Int?,
        workersWfhPct: Double?,
        povertyUniverse: Int?,
        povertyBelow: Int?,
        povertyRatePct: Double?,
        whiteAlone: Int?,
        blackAlone: Int?,
        asianAlone: Int?,
        hispanicOrLatino: Int?
    ) {
        self.name = name
        self.population = population
        self.medianHouseholdIncome = medianHouseholdIncome
        self.medianAge = medianAge
        self.housingUnits = housingUnits

        self.medianHomeValue = medianHomeValue
        self.medianGrossRent = medianGrossRent
        self.averageHouseholdSize = averageHouseholdSize

        self.ownerOccupied = ownerOccupied
        self.renterOccupied = renterOccupied
        self.ownerOccupiedPct = ownerOccupiedPct
        self.renterOccupiedPct = renterOccupiedPct

        self.workersTotal = workersTotal
        self.workersWfh = workersWfh
        self.workersWfhPct = workersWfhPct

        self.povertyUniverse = povertyUniverse
        self.povertyBelow = povertyBelow
        self.povertyRatePct = povertyRatePct

        self.whiteAlone = whiteAlone
        self.blackAlone = blackAlone
        self.asianAlone = asianAlone
        self.hispanicOrLatino = hispanicOrLatino
    }
}

// MARK: - Insights (plain-English, no extra network calls)

public struct Insight: Sendable {
    public enum Severity: String, Sendable {
        case neutral
        case positive
        case caution
    }

    public enum Category: String, Sendable {
        case housing
        case affordability
        case mobility
        case demographics
        case governance
        case geography
    }

    public let category: Category
    public let severity: Severity
    public let title: String
    public let detail: String

    public init(category: Category, severity: Severity, title: String, detail: String) {
        self.category = category
        self.severity = severity
        self.title = title
        self.detail = detail
    }
}

// MARK: - GeoJSON Models (minimal but practical)

public struct GeoJSONFeatureCollection: Codable, Sendable {
    public let type: String
    public let features: [GeoJSONFeature]
}

public struct GeoJSONFeature: Codable, Sendable {
    public let type: String
    public let properties: [String: String?]?
    public let geometry: GeoJSONGeometry?
}

public enum GeoJSONGeometry: Codable, Sendable {
    case polygon([[[Double]]])         // [ring][[lon,lat]]
    case multiPolygon([[[[Double]]]])  // [poly][ring][[lon,lat]]
    case other(String)

    private enum CodingKeys: String, CodingKey { case type, coordinates }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)

        switch type {
        case "Polygon":
            let coords = try c.decode([[[Double]]].self, forKey: .coordinates)
            self = .polygon(coords)
        case "MultiPolygon":
            let coords = try c.decode([[[[Double]]]].self, forKey: .coordinates)
            self = .multiPolygon(coords)
        default:
            self = .other(type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .polygon(let coords):
            try c.encode("Polygon", forKey: .type)
            try c.encode(coords, forKey: .coordinates)
        case .multiPolygon(let coords):
            try c.encode("MultiPolygon", forKey: .type)
            try c.encode(coords, forKey: .coordinates)
        case .other(let type):
            try c.encode(type, forKey: .type)
        }
    }
}

// MARK: - Service

public final class CensusZipDemographicsService: @unchecked Sendable {

    public enum ServiceError: Error, LocalizedError {
        case invalidURL
        case requestFailed(status: Int, bodySnippet: String)
        case decodeFailed(String)
        case noZCTAFound
        case noBoundaryFound
        case noDemographicsFound

        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .requestFailed(let status, let body): return "HTTP \(status): \(body)"
            case .decodeFailed(let msg): return "Decode failed: \(msg)"
            case .noZCTAFound: return "No ZCTA found for coordinate"
            case .noBoundaryFound: return "No boundary found for ZCTA"
            case .noDemographicsFound: return "No demographics returned for ZCTA"
            }
        }
    }

    private let censusApiKey: String
    private let session: URLSession

    /// ACS 5-year endpoints follow: https://api.census.gov/data/{YEAR}/acs/acs5
    private let acsYear: Int

    /// Geocoder benchmark/vintage (kept as canonical "Current" flavors).
    private let geocoderBenchmark = "Public_AR_Current"
    private let geocoderVintage = "Current_Current"

    /// TIGERweb layer ids (tigerWMS_Current) used by the geocoder "layers" param.
    /// From current TIGERweb listing: https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_Current/MapServer
    ///  - 2  = 2020 Census ZIP Code Tabulation Areas
    ///  - 8  = Census Tracts
    ///  - 82 = Counties
    ///  - 28 = Incorporated Places
    ///  - 30 = Census Designated Places
    private let zctaLayerId = "2"
    private let tractLayerId = "8"
    private let countyLayerId = "82"
    private let incorporatedPlacesLayerId = "28"
    private let cdpLayerId = "30"
    private let blockLayerId = "12"

    /// Reusable endpoint roots to avoid duplicated hard-coded URLs.
    private let geocoderCoordinatesURL = "https://geocoding.geo.census.gov/geocoder/geographies/coordinates"
    private let tigerwebMapServerBaseURL = "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_Current/MapServer"

    public init(censusApiKey: String, acsYear: Int = 2024, session: URLSession = .shared) {
        self.censusApiKey = censusApiKey
        self.acsYear = acsYear
        self.session = session
    }

    // MARK: - Public API

    /// Main entry point:
    /// lat/lon -> ZCTA + county + tract + place/incorporation -> boundary + ACS -> insights
    public func fetchZipBundle(latitude: Double, longitude: Double) async throws -> ZipLookupResult {
        let geo = try await fetchGeographiesFromCoordinate(latitude: latitude, longitude: longitude)

        async let boundaryTask = fetchZCTABoundaryGeoJSON(zcta: geo.zcta)
        async let demoTask = fetchACSDemographics(zcta: geo.zcta)

        let boundary = try await boundaryTask
        let demographics = try await demoTask
        let boundaryMetrics = BoundaryAnalyzer.metrics(from: boundary)

        let isIncorporated = (geo.place?.type == .incorporatedPlace)
        let insights = InsightEngine.makeInsights(
            zcta: geo.zcta,
            county: geo.county,
            tract: geo.tract,
            isIncorporatedPlace: isIncorporated,
            boundaryMetrics: boundaryMetrics,
            demographics: demographics
        )

        return ZipLookupResult(
            zcta: geo.zcta,
            county: geo.county,
            tract: geo.tract,
            place: geo.place,
            isIncorporatedPlace: isIncorporated,
            boundary: boundary,
            boundaryMetrics: boundaryMetrics,
            demographics: demographics,
            insights: insights
        )
    }

    public func fetchNeighborhoodBoundaries(
        latitude: Double,
        longitude: Double,
        tractGeoid: String?,
        zipBoundary: GeoJSONFeatureCollection
    ) async -> NeighborhoodBoundarySet {
        let blockFIPS = try? await fetchBlockFIPS(latitude: latitude, longitude: longitude)

        let tractGeoidFromBlock: String?
        if let blockFIPS, blockFIPS.count >= 11 {
            tractGeoidFromBlock = String(blockFIPS.prefix(11))
        } else {
            tractGeoidFromBlock = nil
        }
        let tractToUse = tractGeoidFromBlock ?? tractGeoid

        async let tractBoundaryTask: GeoJSONFeatureCollection? = fetchTractBoundary(tractGeoid: tractToUse)
        async let blockBoundaryTask: GeoJSONFeatureCollection? = fetchBlockBoundary(blockFIPS: blockFIPS)

        return await NeighborhoodBoundarySet(
            zip: zipBoundary,
            tract: tractBoundaryTask,
            block: blockBoundaryTask
        )
    }

    public func fetchDemographics(
        for scale: NeighborhoodScale,
        zcta: String,
        tractGeoid: String?,
        latitude: Double,
        longitude: Double
    ) async throws -> Demographics {
        switch scale {
        case .zip:
            return try await fetchACSDemographics(zcta: zcta)
        case .tract:
            let blockFIPS = try? await fetchBlockFIPS(latitude: latitude, longitude: longitude)
            let tractFromBlock: String?
            if let blockFIPS, blockFIPS.count >= 11 {
                tractFromBlock = String(blockFIPS.prefix(11))
            } else {
                tractFromBlock = nil
            }
            guard let tract = tractFromBlock ?? tractGeoid, tract.count >= 11 else {
                throw ServiceError.noDemographicsFound
            }
            return try await fetchACSDemographics(tractGeoid: tract)
        }
    }

    // MARK: - Step 1: lat/lon -> ZCTA + county + tract + place via Census Geocoder

    private struct GeographiesBundle: Sendable {
        let zcta: String
        let county: CountyInfo?
        let tract: TractInfo?
        let place: PlaceInfo?
    }

    private func fetchGeographiesFromCoordinate(latitude: Double, longitude: Double) async throws -> GeographiesBundle {
        var comps = URLComponents(string: geocoderCoordinatesURL)
        comps?.queryItems = [
            .init(name: "x", value: String(longitude)),
            .init(name: "y", value: String(latitude)),
            .init(name: "benchmark", value: geocoderBenchmark),
            .init(name: "vintage", value: geocoderVintage),
            .init(
                name: "layers",
                value: [
                    zctaLayerId,
                    countyLayerId,
                    tractLayerId,
                    incorporatedPlacesLayerId,
                    cdpLayerId
                ].joined(separator: ",")
            ),
            .init(name: "format", value: "json")
        ]
        guard let url = comps?.url else { throw ServiceError.invalidURL }

        let data = try await httpGET(url)
        let decoded = try decode(CensusGeocoderResponse.self, from: data)

        let zcta = try extractZCTA(from: decoded)
        let county = extractCountyInfo(from: decoded)
        let tract = extractTractInfo(from: decoded)
        let place = extractPlaceInfo(from: decoded)

        return GeographiesBundle(zcta: zcta, county: county, tract: tract, place: place)
    }

    private func extractZCTA(from decoded: CensusGeocoderResponse) throws -> String {
        let zctaKey = "2020 Census ZIP Code Tabulation Areas"
        if let v = decoded.result?.geographies?[zctaKey]?.first?.ZCTA5, v.count == 5 { return v }

        if let geos = decoded.result?.geographies {
            for (_, arr) in geos {
                if let found = arr.first?.ZCTA5, found.count == 5 { return found }
            }
        }
        throw ServiceError.noZCTAFound
    }

    private func extractCountyInfo(from decoded: CensusGeocoderResponse) -> CountyInfo? {
        guard let geos = decoded.result?.geographies else { return nil }
        let countyKey = "Counties"

        if let c = geos[countyKey]?.first {
            let name = c.NAME ?? c.BASENAME ?? "County"
            return CountyInfo(
                name: name,
                stateFIPS: c.STATE,
                countyFIPS: c.COUNTY,
                geoid: c.GEOID
            )
        }

        for (_, arr) in geos {
            if let first = arr.first, first.COUNTY != nil {
                let name = first.NAME ?? first.BASENAME ?? "County"
                return CountyInfo(name: name, stateFIPS: first.STATE, countyFIPS: first.COUNTY, geoid: first.GEOID)
            }
        }

        return nil
    }

    private func extractTractInfo(from decoded: CensusGeocoderResponse) -> TractInfo? {
        guard let geos = decoded.result?.geographies else { return nil }
        let tractKey = "Census Tracts"

        if let t = geos[tractKey]?.first {
            let name = t.NAME ?? t.BASENAME
            let geoid = t.GEOID
            let tractCode = t.TRACT ?? geoid.map { String($0.suffix(6)) }
            return TractInfo(
                name: name,
                geoid: geoid,
                stateFIPS: t.STATE,
                countyFIPS: t.COUNTY,
                tractCode: tractCode
            )
        }

        for (_, arr) in geos {
            if let first = arr.first {
                if let tract = first.TRACT {
                    return TractInfo(
                        name: first.NAME ?? first.BASENAME,
                        geoid: first.GEOID,
                        stateFIPS: first.STATE,
                        countyFIPS: first.COUNTY,
                        tractCode: tract
                    )
                }
                if let geoid = first.GEOID, geoid.count == 11 {
                    return TractInfo(
                        name: first.NAME ?? first.BASENAME,
                        geoid: geoid,
                        stateFIPS: first.STATE,
                        countyFIPS: first.COUNTY,
                        tractCode: String(geoid.suffix(6))
                    )
                }
            }
        }

        return nil
    }

    private func extractPlaceInfo(from decoded: CensusGeocoderResponse) -> PlaceInfo? {
        guard let geos = decoded.result?.geographies else { return nil }

        let incorporatedKey = "Incorporated Places"
        let cdpKey = "Census Designated Places"

        if let inc = geos[incorporatedKey]?.first, let name = (inc.NAME ?? inc.BASENAME), !name.isEmpty {
            return PlaceInfo(
                name: name,
                stateFIPS: inc.STATE,
                placeFIPS: inc.PLACE,
                type: .incorporatedPlace
            )
        }

        if let cdp = geos[cdpKey]?.first, let name = (cdp.NAME ?? cdp.BASENAME), !name.isEmpty {
            return PlaceInfo(
                name: name,
                stateFIPS: cdp.STATE,
                placeFIPS: cdp.PLACE,
                type: .censusDesignatedPlace
            )
        }

        for (_, arr) in geos {
            if let first = arr.first,
               let name = (first.NAME ?? first.BASENAME),
               !name.isEmpty,
               first.PLACE != nil {
                return PlaceInfo(
                    name: name,
                    stateFIPS: first.STATE,
                    placeFIPS: first.PLACE,
                    type: .unknown
                )
            }
        }

        return nil
    }

    // MARK: - Step 2: ZCTA boundary via TIGERweb (GeoJSON)

    private func fetchZCTABoundaryGeoJSON(zcta: String) async throws -> GeoJSONFeatureCollection {
        guard isValid(value: zcta, regex: AppStrings.Validation.zipRegex) else {
            throw ServiceError.noBoundaryFound
        }

        return try await fetchBoundaryGeoJSON(
            layerId: zctaLayerId,
            whereClause: "ZCTA5='\(zcta)'",
            outFields: "ZCTA5,GEOID,NAME"
        )
    }

    private func fetchTractBoundary(tractGeoid: String?) async -> GeoJSONFeatureCollection? {
        guard
            let tractGeoid,
            isValid(value: tractGeoid, regex: AppStrings.Validation.tractRegex)
        else { return nil }

        return try? await fetchBoundaryGeoJSON(layerId: tractLayerId, whereClause: "GEOID='\(tractGeoid)'", outFields: "GEOID,NAME")
    }


    private func fetchBlockBoundary(blockFIPS: String?) async -> GeoJSONFeatureCollection? {
        guard
            let blockFIPS,
            blockFIPS.count == 15,
            isValid(value: blockFIPS, regex: AppStrings.Validation.blockRegex)
        else {
            return nil
        }

        return try? await fetchBoundaryGeoJSON(layerId: blockLayerId, whereClause: "GEOID='\(blockFIPS)'", outFields: "GEOID,NAME")
    }

    private func fetchBlockFIPS(latitude: Double, longitude: Double) async throws -> String {
        var comps = URLComponents(string: AppStrings.Network.fccCensusURL)
        comps?.queryItems = [
            .init(name: AppStrings.QueryItems.latitude, value: String(latitude)),
            .init(name: AppStrings.QueryItems.longitude, value: String(longitude)),
            .init(name: AppStrings.QueryItems.responseFormat, value: AppStrings.Network.jsonFormat)
        ]

        guard let url = comps?.url else { throw ServiceError.invalidURL }

        let data = try await httpGET(url)
        let decoded = try decode(FCCBlockResponse.self, from: data)
        guard let fips = decoded.Block?.fips, !fips.isEmpty else { throw ServiceError.noBoundaryFound }
        return fips
    }

    private func fetchBoundaryGeoJSON(layerId: String, whereClause: String, outFields: String) async throws -> GeoJSONFeatureCollection {
        var comps = URLComponents(string: "\(tigerwebMapServerBaseURL)/\(layerId)/query")
        comps?.queryItems = [
            .init(name: "where", value: whereClause),
            .init(name: "outFields", value: outFields),
            .init(name: "returnGeometry", value: "true"),
            .init(name: "outSR", value: "4326"),
            .init(name: "f", value: "geojson")
        ]
        guard let url = comps?.url else { throw ServiceError.invalidURL }

        let data = try await httpGET(url)
        let fc = try decode(GeoJSONFeatureCollection.self, from: data)
        guard !fc.features.isEmpty else { throw ServiceError.noBoundaryFound }
        return fc
    }

    // MARK: - Step 3: Demographics via ACS 5-year (Census Data API)

    private func fetchACSDemographics(zcta: String) async throws -> Demographics {
        return try await fetchACSDemographics(
            forQuery: "zip code tabulation area:\(zcta)",
            inQuery: nil,
            fallbackName: "ZCTA \(zcta)",
            variables: acsExtendedVariables
        )
    }

    private func fetchACSDemographics(tractGeoid: String) async throws -> Demographics {
        let state = String(tractGeoid.prefix(2))
        let county = String(tractGeoid.dropFirst(2).prefix(3))
        let tract = String(tractGeoid.suffix(6))
        return try await fetchACSDemographics(
            forQuery: "tract:\(tract)",
            inQuery: "state:\(state)+county:\(county)",
            fallbackName: "Tract \(tractGeoid)",
            variables: acsExtendedVariables
        )
    }

    private var acsExtendedVariables: [String] {
        [
            "NAME",

            // Core
            "B01003_001E", // total population
            "B19013_001E", // median household income
            "B01002_001E", // median age
            "B25001_001E", // housing units

            // Housing & household
            "B25077_001E", // median home value
            "B25064_001E", // median gross rent
            "B25010_001E", // average household size
            "B25003_002E", // owner occupied
            "B25003_003E", // renter occupied

            // Work from home (Means of transportation to work)
            "B08301_001E", // total workers
            "B08301_021E", // worked at home

            // Poverty
            "B17001_001E", // poverty universe
            "B17001_002E", // below poverty

            // Race / ethnicity examples
            "B02001_002E", // white alone
            "B02001_003E", // black alone
            "B02001_005E", // asian alone
            "B03003_003E"  // Hispanic or Latino
        ]
    }

    private func fetchACSDemographics(forQuery: String, inQuery: String?, fallbackName: String, variables: [String]) async throws -> Demographics {
        let base = "https://api.census.gov/data/\(acsYear)/acs/acs5"
        let vars = variables.joined(separator: ",")

        var comps = URLComponents(string: base)
        var queryItems: [URLQueryItem] = [
            .init(name: "get", value: vars),
            .init(name: "for", value: forQuery)
        ]
        if let inQuery {
            queryItems.append(.init(name: "in", value: inQuery))
        }
        if !censusApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(.init(name: "key", value: censusApiKey))
        }
        comps?.queryItems = queryItems
        guard let url = comps?.url else { throw ServiceError.invalidURL }

        let data = try await httpGET(url)

        guard
            let top = try JSONSerialization.jsonObject(with: data) as? [[String]],
            top.count >= 2
        else { throw ServiceError.decodeFailed("Unexpected ACS response shape") }

        let header = top[0]
        let row = top[1]
        guard header.count == row.count else { throw ServiceError.decodeFailed("Header/row length mismatch") }

        var dict: [String: String] = [:]
        for (k, v) in zip(header, row) {
            dict[k] = v
        }

        let name = dict["NAME"] ?? fallbackName

        func intVal(_ key: String) -> Int? {
            guard let s = dict[key], let v = Int(s) else { return nil }
            return v
        }
        func doubleVal(_ key: String) -> Double? {
            guard let s = dict[key], let v = Double(s) else { return nil }
            return v
        }
        func pct(_ num: Int?, _ den: Int?) -> Double? {
            guard let n = num, let d = den, d > 0 else { return nil }
            return (Double(n) / Double(d)) * 100.0
        }

        if dict["B01003_001E"] == nil {
            throw ServiceError.noDemographicsFound
        }

        let owner = intVal("B25003_002E")
        let renter = intVal("B25003_003E")
        let occTotal: Int? = {
            guard let o = owner, let r = renter else { return nil }
            return o + r
        }()

        let workersTotal = intVal("B08301_001E")
        let workersWfh = intVal("B08301_021E")

        let povUniverse = intVal("B17001_001E")
        let povBelow = intVal("B17001_002E")

        return Demographics(
            name: name,
            population: intVal("B01003_001E"),
            medianHouseholdIncome: intVal("B19013_001E"),
            medianAge: doubleVal("B01002_001E"),
            housingUnits: intVal("B25001_001E"),
            medianHomeValue: intVal("B25077_001E"),
            medianGrossRent: intVal("B25064_001E"),
            averageHouseholdSize: doubleVal("B25010_001E"),
            ownerOccupied: owner,
            renterOccupied: renter,
            ownerOccupiedPct: pct(owner, occTotal),
            renterOccupiedPct: pct(renter, occTotal),
            workersTotal: workersTotal,
            workersWfh: workersWfh,
            workersWfhPct: pct(workersWfh, workersTotal),
            povertyUniverse: povUniverse,
            povertyBelow: povBelow,
            povertyRatePct: pct(povBelow, povUniverse),
            whiteAlone: intVal("B02001_002E"),
            blackAlone: intVal("B02001_003E"),
            asianAlone: intVal("B02001_005E"),
            hispanicOrLatino: intVal("B03003_003E")
        )
    }

    // MARK: - HTTP helpers

    private func httpGET(_ url: URL) async throws -> Data {
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse else {
            throw ServiceError.requestFailed(status: -1, bodySnippet: "Non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
            throw ServiceError.requestFailed(status: http.statusCode, bodySnippet: String(snippet))
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ServiceError.decodeFailed(error.localizedDescription)
        }
    }
}

// MARK: - Insight Engine (no extra network calls)

private enum InsightEngine {

    static func makeInsights(
        zcta: String,
        county: CountyInfo?,
        tract: TractInfo?,
        isIncorporatedPlace: Bool,
        boundaryMetrics: BoundaryMetrics?,
        demographics: Demographics
    ) -> [Insight] {
        var insights: [Insight] = []

        // Housing & affordability summary
        var housingDetails: [String] = []
        var housingSeverity: Insight.Severity = .neutral

        if let hv = demographics.medianHomeValue {
            housingDetails.append("Median home value: \(formatCurrency(hv))" + (hv >= 1_000_000 ? " (high)" : ""))
            if hv >= 1_000_000 {
                housingSeverity = .caution
            }
        }

        if let rent = demographics.medianGrossRent {
            housingDetails.append("Median gross rent: \(formatCurrency(rent))" + (rent >= 3000 ? " (high)" : ""))
            if rent >= 3000 {
                housingSeverity = .caution
            }
        }

        if let ownerPct = demographics.ownerOccupiedPct, let renterPct = demographics.renterOccupiedPct {
            let occupancyText = "\(formatPct(ownerPct)) owner-occupied, \(formatPct(renterPct)) renter-occupied"
            housingDetails.append(occupancyText)
            if housingSeverity != .caution, ownerPct >= 60 {
                housingSeverity = .positive
            }
        }

        if let ownerPct = demographics.ownerOccupiedPct, let hh = demographics.averageHouseholdSize {
            housingDetails.append("Homeownership at \(formatPct(ownerPct)) with average household size of \(formatNumber(hh, decimals: 1))")
        }

        if !housingDetails.isEmpty {
            insights.append(
                Insight(
                    category: .housing,
                    severity: housingSeverity,
                    title: "Housing snapshot",
                    detail: housingDetails.joined(separator: ". ") + "."
                )
            )
        }

        if let hh = demographics.averageHouseholdSize {
            insights.append(
                Insight(
                    category: .demographics,
                    severity: .neutral,
                    title: "Average household size",
                    detail: "\(formatNumber(hh, decimals: 2)) people per household."
                )
            )
        }

        // Mobility / remote work
        if let wfh = demographics.workersWfhPct {
            let sev: Insight.Severity = wfh >= 20 ? .positive : .neutral
            let label = wfh >= 20 ? "Remote-work common" : "Remote-work less common"
            insights.append(
                Insight(
                    category: .mobility,
                    severity: sev,
                    title: label,
                    detail: "\(formatPct(wfh)) of workers report working from home."
                )
            )
        }

        // Poverty
        if let pov = demographics.povertyRatePct {
            let sev: Insight.Severity
            let label: String
            if pov >= 20 {
                sev = .caution
                label = "Higher poverty rate"
            } else if pov <= 8 {
                sev = .positive
                label = "Lower poverty rate"
            } else {
                sev = .neutral
                label = "Poverty rate"
            }

            insights.append(
                Insight(
                    category: .affordability,
                    severity: sev,
                    title: label,
                    detail: "\(formatPct(pov)) of people are below the poverty line (ACS estimate)."
                )
            )
        }

        // Keep it tidy: stable ordering, avoid spam
        return insights
    }

    private static func formatFIPS(state: String?, local: String?, label: String) -> String {
        guard let s = state, let l = local else { return "" }
        return " (\(label): \(s)\(l))"
    }

    private static func formatCurrency(_ value: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.maximumFractionDigits = 0
        nf.locale = Locale(identifier: "en_US")
        return nf.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func formatPct(_ value: Double) -> String {
        return "\(formatNumber(value, decimals: 0))%"
    }

    private static func formatNumber(_ value: Double, decimals: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = decimals
        nf.maximumFractionDigits = decimals
        return nf.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Boundary Analyzer

private enum BoundaryAnalyzer {
    private static let earthRadiusMeters = 6_371_008.8

    static func metrics(from fc: GeoJSONFeatureCollection) -> BoundaryMetrics? {
        var allPoints: [(lat: Double, lon: Double)] = []
        var areaM2Total: Double = 0
        var perimeterMTotal: Double = 0

        for f in fc.features {
            guard let g = f.geometry else { continue }
            switch g {
            case .polygon(let rings):
                if let exterior = rings.first {
                    let pts = exterior.compactMap { coord -> (Double, Double)? in
                        guard coord.count >= 2 else { return nil }
                        return (coord[1], coord[0]) // lat, lon
                    }
                    if pts.count >= 3 {
                        allPoints.append(contentsOf: pts)
                        areaM2Total += abs(sphericalPolygonArea(pts))
                        perimeterMTotal += polylineLength(pts, closed: true)
                    }
                }
            case .multiPolygon(let polys):
                for poly in polys {
                    if let exterior = poly.first {
                        let pts = exterior.compactMap { coord -> (Double, Double)? in
                            guard coord.count >= 2 else { return nil }
                            return (coord[1], coord[0])
                        }
                        if pts.count >= 3 {
                            allPoints.append(contentsOf: pts)
                            areaM2Total += abs(sphericalPolygonArea(pts))
                            perimeterMTotal += polylineLength(pts, closed: true)
                        }
                    }
                }
            case .other:
                continue
            }
        }

        guard !allPoints.isEmpty else { return nil }

        let bbox = boundingBox(allPoints)
        let centroid = centroidApprox(allPoints)

        return BoundaryMetrics(
            centroid: centroid,
            bbox: bbox,
            areaKm2Approx: areaM2Total > 0 ? (areaM2Total / 1_000_000.0) : nil,
            perimeterKmApprox: perimeterMTotal > 0 ? (perimeterMTotal / 1_000.0) : nil
        )
    }

    private static func boundingBox(_ pts: [(lat: Double, lon: Double)]) -> BoundingBox {
        var minLat = Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude

        for p in pts {
            minLat = min(minLat, p.lat)
            minLon = min(minLon, p.lon)
            maxLat = max(maxLat, p.lat)
            maxLon = max(maxLon, p.lon)
        }
        return BoundingBox(minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)
    }

    private static func centroidApprox(_ pts: [(lat: Double, lon: Double)]) -> CLLocationCoordinate2D? {
        guard !pts.isEmpty else { return nil }
        let sumLat = pts.reduce(0.0) { $0 + $1.lat }
        let sumLon = pts.reduce(0.0) { $0 + $1.lon }
        return CLLocationCoordinate2D(latitude: sumLat / Double(pts.count), longitude: sumLon / Double(pts.count))
    }

    private static func polylineLength(_ pts: [(lat: Double, lon: Double)], closed: Bool) -> Double {
        guard pts.count >= 2 else { return 0 }
        var total = 0.0
        for i in 1..<pts.count {
            total += haversineMeters(pts[i - 1], pts[i])
        }
        if closed {
            total += haversineMeters(pts[pts.count - 1], pts[0])
        }
        return total
    }

    private static func haversineMeters(_ a: (lat: Double, lon: Double), _ b: (lat: Double, lon: Double)) -> Double {
        let lat1 = a.lat * .pi / 180.0
        let lon1 = a.lon * .pi / 180.0
        let lat2 = b.lat * .pi / 180.0
        let lon2 = b.lon * .pi / 180.0

        let dLat = lat2 - lat1
        let dLon = lon2 - lon1

        let sinDLat = sin(dLat / 2)
        let sinDLon = sin(dLon / 2)

        let h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon
        let c = 2 * atan2(sqrt(h), sqrt(1 - h))
        return earthRadiusMeters * c
    }

    private static func sphericalPolygonArea(_ pts: [(lat: Double, lon: Double)]) -> Double {
        guard pts.count >= 3 else { return 0 }
        var sum = 0.0

        for i in 0..<pts.count {
            let j = (i + 1) % pts.count
            let lat1 = pts[i].lat * .pi / 180.0
            let lat2 = pts[j].lat * .pi / 180.0
            let lon1 = pts[i].lon * .pi / 180.0
            let lon2 = pts[j].lon * .pi / 180.0

            var dLon = lon2 - lon1
            if dLon > .pi { dLon -= 2 * .pi }
            if dLon < -.pi { dLon += 2 * .pi }

            sum += dLon * (sin(lat1) + sin(lat2))
        }

        return (earthRadiusMeters * earthRadiusMeters) * (sum / 2.0)
    }
}

private extension CensusZipDemographicsService {
    /// Validates identifier inputs before interpolation into API query clauses.
    func isValid(value: String, regex: String) -> Bool {
        value.range(of: regex, options: .regularExpression) != nil
    }
}

// MARK: - Census Geocoder Response Models (expanded minimal)

private struct CensusGeocoderResponse: Codable {
    let result: CensusGeocoderResult?
}

private struct CensusGeocoderResult: Codable {
    let geographies: [String: [CensusGeocoderGeography]]?
}

private struct CensusGeocoderGeography: Codable {
    // ZCTA layer
    let ZCTA5: String?

    // Common fields across layers
    let NAME: String?
    let BASENAME: String?
    let GEOID: String?

    // FIPS components (present on many layers)
    let STATE: String?
    let COUNTY: String?

    // Tract component (on tract layer)
    let TRACT: String?

    // Place layers
    let PLACE: String?
}
