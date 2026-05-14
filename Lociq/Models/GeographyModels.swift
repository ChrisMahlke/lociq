//
//  GeographyModels.swift
//  Lociq
//
//  Defines resolved Census geography models used to load a city profile.
//

import Foundation

/// Groups the Census geographies resolved from one device coordinate.
struct CityGeographyProfile: Sendable {
    let county: CountyInfo?
    let place: PlaceInfo?
}

/// Groups the boundary geometries attached to a resolved city profile.
struct CityBoundarySet: Sendable {
    let city: GeoJSONFeatureCollection?
}

/// Groups demographic records attached to a resolved city profile.
struct CityDemographicsBundle: Sendable {
    let place: Demographics?
}

/// Represents the full domain record assembled from Census geocoding, ACS values, and TIGER geometry.
struct ResolvedCityProfile: Sendable {
    let geography: CityGeographyProfile
    let boundarySet: CityBoundarySet
    let demographics: CityDemographicsBundle
}

/// Census county metadata returned by the Census geocoder.
struct CountyInfo: Sendable {
    let name: String
    let stateFIPS: String?
    let countyFIPS: String?
    let geoid: String?

    /// Creates county metadata returned by the Census geocoder.
    init(name: String, stateFIPS: String?, countyFIPS: String?, geoid: String?) {
        self.name = name
        self.stateFIPS = stateFIPS
        self.countyFIPS = countyFIPS
        self.geoid = geoid
    }
}

/// Census place metadata for an incorporated place or census-designated place.
struct PlaceInfo: Sendable {
    /// Distinguishes incorporated places from census-designated places when querying downstream services.
    enum PlaceType: String, Sendable {
        case incorporatedPlace
        case censusDesignatedPlace
        case unknown
    }

    let name: String
    let stateFIPS: String?
    let placeFIPS: String?
    let type: PlaceType

    /// Creates place metadata for an incorporated place or census-designated place.
    init(name: String, stateFIPS: String?, placeFIPS: String?, type: PlaceType) {
        self.name = name
        self.stateFIPS = stateFIPS
        self.placeFIPS = placeFIPS
        self.type = type
    }
}
