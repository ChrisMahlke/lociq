//
//  CensusClientProtocols.swift
//  Lociq
//
//  Defines small Census service protocols for isolated tests and composition.
//

import Foundation

/// Loads the full resolved Census profile for a coordinate.
protocol CityProfileFetching: Sendable {
    /// Fetches geocoded place metadata, ACS demographics, and optional TIGER geometry.
    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedCityProfile
}

/// Resolves device coordinates into Census geography identifiers.
protocol CensusGeographyFetching: Sendable {
    /// Fetches Census geographies for the supplied latitude and longitude.
    func fetchGeographiesFromCoordinate(latitude: Double, longitude: Double) async throws -> CensusGeographiesBundle
}

/// Fetches ACS demographic estimates for a Census place.
protocol ACSDemographicsFetching: Sendable {
    /// Fetches normalized place-level ACS estimates.
    func fetchDemographics(place: PlaceInfo) async throws -> Demographics
}

/// Fetches TIGERweb boundary geometry for a Census place.
protocol TIGERBoundaryFetching: Sendable {
    /// Fetches optional GeoJSON geometry for the supplied place.
    func fetchPlaceBoundary(place: PlaceInfo?) async -> GeoJSONFeatureCollection?
}

extension CensusCityProfileService: CityProfileFetching {}
extension CensusGeocoderClient: CensusGeographyFetching {}
extension ACSDemographicsClient: ACSDemographicsFetching {}
extension TIGERBoundaryClient: TIGERBoundaryFetching {}
