//
//  CensusNeighborhoodModels.swift
//  Lociq
//
//  Shared Census, ACS, and GeoJSON models for the minimal city profile.
//

import Foundation

struct ZipLookupResult: Sendable {
    let zcta: String
    let county: CountyInfo?
    let place: PlaceInfo?
    let demographics: Demographics
}

struct NeighborhoodBoundarySet: Sendable {
    let city: GeoJSONFeatureCollection?
}

struct ScaleDemographicsBundle: Sendable {
    let place: Demographics?
    let zip: Demographics
}

struct ResolvedPlaceProfile: Sendable {
    let zipBundle: ZipLookupResult
    let boundaries: NeighborhoodBoundarySet
    let scaleDemographics: ScaleDemographicsBundle
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
        transitCommuters: Int? = nil,
        transitCommutersPct: Double? = nil,
        averageCommuteMinutes: Double? = nil,
        vacantHousingUnits: Int? = nil,
        vacancyRatePct: Double? = nil,
        under18Pct: Double? = nil,
        age18To34Pct: Double? = nil,
        age35To64Pct: Double? = nil,
        age65PlusPct: Double? = nil,
        bachelorsOrHigherPct: Double? = nil,
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
