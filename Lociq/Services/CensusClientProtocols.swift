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
    /// - Returns: A resolved profile with optional partial failures.
    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedCityProfile
}

/// Resolves device coordinates into Census geography identifiers.
///
/// The geocoder is kept separate from the full profile client so fallback states
/// can still show a city label when ACS data fails.
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
