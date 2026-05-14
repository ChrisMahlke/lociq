//
//  GeographyModels.swift
//  Lociq
//
//  Defines resolved Census geography models used to load a city profile.
//
//  These types sit between raw Census geocoder responses and the rest of the
//  app. They expose the identifiers required for ACS and TIGER requests without
//  leaking the full geocoder payload into domain or UI code.
//

import Foundation

/// Groups the Census geographies resolved from one device coordinate.
///
/// A coordinate can resolve to a county even when no incorporated place or CDP
/// is available. The app currently displays city-level data, so `place` is the
/// critical value for downstream profile loading.
struct CityGeographyProfile: Sendable {
    /// County containing the coordinate, used as contextual fallback metadata.
    let county: CountyInfo?

    /// Incorporated place or census-designated place containing the coordinate.
    let place: PlaceInfo?
}

/// Groups the boundary geometries attached to a resolved city profile.
///
/// The wrapper keeps geometry separate from demographic values. That separation
/// lets the loader represent ACS success with TIGER failure as a partial load.
struct CityBoundarySet: Sendable {
    /// City or CDP boundary geometry returned by TIGERweb.
    let city: GeoJSONFeatureCollection?
}

/// Groups demographic records attached to a resolved city profile.
///
/// The app is intentionally city-only today, but the wrapper leaves room for
/// future demographic scopes without changing `ResolvedCityProfile`.
struct CityDemographicsBundle: Sendable {
    /// Place-level ACS demographics for the resolved city or CDP.
    let place: Demographics?
}

/// Represents the full domain record assembled from Census geocoding, ACS values, and TIGER geometry.
///
/// This is the service-domain aggregate. It is richer than the UI snapshot and
/// preserves partial-failure information so cache and display logic can make
/// accurate decisions about incomplete data.
struct ResolvedCityProfile: Sendable {
    let geography: CityGeographyProfile
    let boundarySet: CityBoundarySet
    let demographics: CityDemographicsBundle
    let partialFailures: [CityProfilePartialFailure]

    /// Creates a resolved city profile with optional typed partial failures for failed subrequests.
    ///
    /// - Parameters:
    ///   - geography: Resolved Census place and county metadata.
    ///   - boundarySet: Optional TIGER geometry associated with the place.
    ///   - demographics: Optional ACS demographic bundle associated with the place.
    ///   - partialFailures: Subrequest failures that did not prevent useful data.
    init(
        geography: CityGeographyProfile,
        boundarySet: CityBoundarySet,
        demographics: CityDemographicsBundle,
        partialFailures: [CityProfilePartialFailure] = []
    ) {
        self.geography = geography
        self.boundarySet = boundarySet
        self.demographics = demographics
        self.partialFailures = partialFailures
    }
}

/// Census county metadata returned by the Census geocoder.
///
/// County data is mainly fallback context. City-level ACS and TIGER requests use
/// `PlaceInfo`, but county metadata helps the app preserve a useful location
/// shell when place-level resolution fails.
struct CountyInfo: Sendable {
    /// Display name returned by the geocoder.
    let name: String

    /// Two-digit Census state FIPS code.
    let stateFIPS: String?

    /// Three-digit Census county FIPS code.
    let countyFIPS: String?

    /// Full Census geographic identifier when provided.
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
///
/// This is the key record for downstream ACS and TIGER calls. State FIPS plus
/// place FIPS uniquely identify the place in the Census APIs used by LOC IQ.
struct PlaceInfo: Sendable {
    /// Distinguishes incorporated places from census-designated places when querying downstream services.
    ///
    /// TIGERweb exposes incorporated places and CDPs as different layers, so
    /// the type affects which layer the boundary client queries.
    enum PlaceType: String, Sendable {
        case incorporatedPlace
        case censusDesignatedPlace
        case unknown
    }

    /// Display name returned by the Census geocoder.
    let name: String

    /// Two-digit Census state FIPS code.
    let stateFIPS: String?

    /// Five-digit Census place FIPS code.
    let placeFIPS: String?

    /// Census place category used for TIGER layer selection.
    let type: PlaceType

    /// Creates place metadata for an incorporated place or census-designated place.
    init(name: String, stateFIPS: String?, placeFIPS: String?, type: PlaceType) {
        self.name = name
        self.stateFIPS = stateFIPS
        self.placeFIPS = placeFIPS
        self.type = type
    }
}
