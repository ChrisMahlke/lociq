//
//  CensusClientProtocols.swift
//  Lociq
//
//  Defines small Census service protocols for isolated tests and composition.
//
//  The production loader composes concrete Census clients, while tests use
//  protocol-backed fakes. These protocols define the seams where network work
//  is replaced by deterministic values.
//

import Foundation

/// Options for one full profile fetch.
nonisolated struct CityProfileFetchOptions: Sendable {
    /// Skips the in-memory place memo so statistics are requested again.
    var forceRefresh = false

    /// Boundary already on screen for a place, reused when the place is unchanged.
    var knownBoundary: KnownPlaceBoundary?

    /// Creates fetch options.
    init(forceRefresh: Bool = false, knownBoundary: KnownPlaceBoundary? = nil) {
        self.forceRefresh = forceRefresh
        self.knownBoundary = knownBoundary
    }
}

/// A boundary the app already holds, keyed by the Census place it outlines.
///
/// Boundaries do not change within a data vintage, so a refresh of the same
/// place can reuse the geometry instead of downloading it again.
nonisolated struct KnownPlaceBoundary: Sendable {
    /// Seven-digit place GEOID the boundary belongs to.
    let geoid: String

    /// Boundary geometry for that place.
    let boundary: GeoJSONFeatureCollection
}

/// Loads the full resolved Census profile for a coordinate.
///
/// This is the broadest service protocol. It hides the internal fan-out across
/// geocoding, ACS, and TIGER from the loader.
protocol CityProfileFetching: Sendable {
    /// Fetches geocoded place metadata, ACS demographics, and optional TIGER geometry.
    ///
    /// - Parameters:
    ///   - latitude: WGS84 latitude from Core Location.
    ///   - longitude: WGS84 longitude from Core Location.
    ///   - options: Memo and boundary-reuse options for this fetch.
    /// - Returns: A resolved profile with optional partial failures. A profile
    ///   without a place means the coordinate is outside every Census place.
    /// - Throws: A geocoder failure, because nothing can be resolved without it.
    func fetchPlaceProfile(latitude: Double, longitude: Double, options: CityProfileFetchOptions) async throws -> ResolvedCityProfile
}

/// Resolves device coordinates into Census geography identifiers.
///
/// The geocoder is kept separate from the full profile client so the loader can
/// still name the city when no API key is configured.
protocol CensusGeographyFetching: Sendable {
    /// Fetches Census geographies for the supplied latitude and longitude.
    func fetchGeographiesFromCoordinate(latitude: Double, longitude: Double) async throws -> CensusGeographiesBundle
}

/// Fetches ACS demographic estimates for a Census place.
///
/// Implementations should return domain-level `Demographics`, not raw ACS rows.
protocol ACSDemographicsFetching: Sendable {
    /// Fetches normalized place-level ACS estimates.
    func fetchDemographics(place: PlaceInfo) async throws -> Demographics
}

/// Fetches TIGERweb boundary geometry for a Census place.
///
/// Boundary fetches return optional geometry instead of throwing because missing
/// outlines should not prevent useful demographic data from rendering.
protocol TIGERBoundaryFetching: Sendable {
    /// Fetches optional GeoJSON geometry for the supplied place.
    func fetchPlaceBoundary(place: PlaceInfo?) async -> GeoJSONFeatureCollection?
}

extension CensusCityProfileService: CityProfileFetching {}
extension CensusGeocoderClient: CensusGeographyFetching {}
extension ACSDemographicsClient: ACSDemographicsFetching {}
extension TIGERBoundaryClient: TIGERBoundaryFetching {}
