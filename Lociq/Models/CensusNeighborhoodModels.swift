//
//  CensusNeighborhoodModels.swift
//  Lociq
//
//  Shared domain models for neighborhood lookup, GeoJSON, and generated insights.
//

import CoreLocation
import Foundation

public struct ZipLookupResult: Sendable {
    public let zcta: String
    public let county: CountyInfo?
    public let tract: TractInfo?
    public let place: PlaceInfo?
    public let isIncorporatedPlace: Bool
    public let boundary: GeoJSONFeatureCollection
    public let boundaryMetrics: BoundaryMetrics?
    public let demographics: Demographics
    public let insights: [Insight]

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
    public let city: GeoJSONFeatureCollection?
    public let tract: GeoJSONFeatureCollection?
    public let blockGroup: GeoJSONFeatureCollection?
    public let block: GeoJSONFeatureCollection?

    public init(
        zip: GeoJSONFeatureCollection,
        city: GeoJSONFeatureCollection? = nil,
        tract: GeoJSONFeatureCollection?,
        blockGroup: GeoJSONFeatureCollection? = nil,
        block: GeoJSONFeatureCollection?
    ) {
        self.zip = zip
        self.city = city
        self.tract = tract
        self.blockGroup = blockGroup
        self.block = block
    }
}

struct ScaleDemographicsBundle: Sendable {
    let place: Demographics?
    let zip: Demographics
    let tract: Demographics?
    let blockGroup: Demographics?

    init(place: Demographics? = nil, zip: Demographics, tract: Demographics?, blockGroup: Demographics? = nil) {
        self.place = place
        self.zip = zip
        self.tract = tract
        self.blockGroup = blockGroup
    }
}

struct ResolvedPlaceProfile: Sendable {
    let zipBundle: ZipLookupResult
    let boundaries: NeighborhoodBoundarySet
    let scaleDemographics: ScaleDemographicsBundle

    init(
        zipBundle: ZipLookupResult,
        boundaries: NeighborhoodBoundarySet,
        scaleDemographics: ScaleDemographicsBundle
    ) {
        self.zipBundle = zipBundle
        self.boundaries = boundaries
        self.scaleDemographics = scaleDemographics
    }
}

struct ComparisonProfileResult: Sendable {
    let id: String
    let title: String
    let subtitle: String
    let demographics: Demographics
    let metricsSource: MetricsSource

    init(
        id: String,
        title: String,
        subtitle: String,
        demographics: Demographics,
        metricsSource: MetricsSource
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.demographics = demographics
        self.metricsSource = metricsSource
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
    public let geoid: String?
    public let stateFIPS: String?
    public let countyFIPS: String?
    public let tractCode: String?

    public init(name: String?, geoid: String?, stateFIPS: String?, countyFIPS: String?, tractCode: String?) {
        self.name = name
        self.geoid = geoid
        self.stateFIPS = stateFIPS
        self.countyFIPS = countyFIPS
        self.tractCode = tractCode
    }
}

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
    public let population: Int?
    public let medianHouseholdIncome: Int?
    public let medianAge: Double?
    public let housingUnits: Int?
    public let medianHomeValue: Int?
    public let medianGrossRent: Int?
    public let averageHouseholdSize: Double?
    public let ownerOccupied: Int?
    public let renterOccupied: Int?
    public let ownerOccupiedPct: Double?
    public let renterOccupiedPct: Double?
    public let workersTotal: Int?
    public let workersWfh: Int?
    public let workersWfhPct: Double?
    public let transitCommuters: Int?
    public let transitCommutersPct: Double?
    public let averageCommuteMinutes: Double?
    public let vacantHousingUnits: Int?
    public let vacancyRatePct: Double?
    public let under18Pct: Double?
    public let age18To34Pct: Double?
    public let age35To64Pct: Double?
    public let age65PlusPct: Double?
    public let bachelorsOrHigherPct: Double?
    public let povertyUniverse: Int?
    public let povertyBelow: Int?
    public let povertyRatePct: Double?
    public let whiteAlone: Int?
    public let blackAlone: Int?
    public let asianAlone: Int?
    public let hispanicOrLatino: Int?

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
        transitCommuters: Int?,
        transitCommutersPct: Double?,
        averageCommuteMinutes: Double?,
        vacantHousingUnits: Int?,
        vacancyRatePct: Double?,
        under18Pct: Double?,
        age18To34Pct: Double?,
        age35To64Pct: Double?,
        age65PlusPct: Double?,
        bachelorsOrHigherPct: Double?,
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
        self.transitCommuters = transitCommuters
        self.transitCommutersPct = transitCommutersPct
        self.averageCommuteMinutes = averageCommuteMinutes
        self.vacantHousingUnits = vacantHousingUnits
        self.vacancyRatePct = vacancyRatePct
        self.under18Pct = under18Pct
        self.age18To34Pct = age18To34Pct
        self.age35To64Pct = age35To64Pct
        self.age65PlusPct = age65PlusPct
        self.bachelorsOrHigherPct = bachelorsOrHigherPct
        self.povertyUniverse = povertyUniverse
        self.povertyBelow = povertyBelow
        self.povertyRatePct = povertyRatePct
        self.whiteAlone = whiteAlone
        self.blackAlone = blackAlone
        self.asianAlone = asianAlone
        self.hispanicOrLatino = hispanicOrLatino
    }
}

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
    case polygon([[[Double]]])
    case multiPolygon([[[[Double]]]])
    case other(String)

    private enum CodingKeys: String, CodingKey { case type, coordinates }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "Polygon":
            self = .polygon(try container.decode([[[Double]]].self, forKey: .coordinates))
        case "MultiPolygon":
            self = .multiPolygon(try container.decode([[[[Double]]]].self, forKey: .coordinates))
        default:
            self = .other(type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .polygon(let coordinates):
            try container.encode("Polygon", forKey: .type)
            try container.encode(coordinates, forKey: .coordinates)
        case .multiPolygon(let coordinates):
            try container.encode("MultiPolygon", forKey: .type)
            try container.encode(coordinates, forKey: .coordinates)
        case .other(let type):
            try container.encode(type, forKey: .type)
        }
    }
}
