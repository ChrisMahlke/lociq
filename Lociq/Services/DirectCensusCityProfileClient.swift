//
//  DirectCensusCityProfileClient.swift
//  Lociq
//
//  Coordinates Census geocoding, ACS demographics, and TIGER city boundaries.
//
//  This client performs the direct service fan-out for a coordinate. It is kept
//  separate from the caching service so tests and higher-level loaders can
//  choose whether they want memoization or raw Census behavior.
//

import Foundation

/// Composes geocoder, ACS, and TIGER clients into one resolved city profile.
///
/// The client treats boundary loading as optional and demographics loading as
/// recoverable. That lets the app show partial but useful information when one
/// Census service fails.
struct DirectCensusCityProfileClient: Sendable {
    /// Coordinate-to-Census-geography resolver.
    private let geocoderClient: any CensusGeographyFetching

    /// TIGERweb boundary client for the resolved place.
    private let boundaryClient: any TIGERBoundaryFetching

    /// ACS demographic client for the resolved place.
    private let demographicsClient: any ACSDemographicsFetching

    /// Creates the direct Census client from already-built service clients.
    ///
    /// The clients are built once per app session (`CensusServiceGraph`) and
    /// shared, so every path uses the same session caches.
    init(
        geocoderClient: any CensusGeographyFetching,
        boundaryClient: any TIGERBoundaryFetching,
        demographicsClient: any ACSDemographicsFetching
    ) {
        self.geocoderClient = geocoderClient
        self.boundaryClient = boundaryClient
        self.demographicsClient = demographicsClient
    }

    /// Resolves the county and place that contain a coordinate.
    ///
    /// - Throws: The geocoder's failure. Nothing downstream can run without it.
    func fetchGeography(latitude: Double, longitude: Double) async throws -> CityGeographyProfile {
        let geographies = try await geocoderClient.fetchGeographiesFromCoordinate(
            latitude: latitude,
            longitude: longitude
        )
        return CityGeographyProfile(county: geographies.county, place: geographies.place)
    }

    /// Loads statistics and the boundary for an already-resolved place.
    ///
    /// Boundary and demographic requests run concurrently because they are
    /// independent once the place is known. A demographics failure is recorded
    /// as a typed partial failure so the loader can explain it precisely. A
    /// known boundary for the same place is reused instead of downloaded.
    func fetchPlaceProfile(
        for geography: CityGeographyProfile,
        knownBoundary: KnownPlaceBoundary? = nil
    ) async -> ResolvedCityProfile {
        guard let place = geography.place else {
            return ResolvedCityProfile(
                geography: geography,
                boundarySet: CityBoundarySet(city: nil),
                demographics: CityDemographicsBundle(place: nil)
            )
        }

        let reusableBoundary = knownBoundary.flatMap { $0.geoid == place.geoid ? $0.boundary : nil }
        async let cityBoundaryTask = boundary(for: place, reusing: reusableBoundary)
        async let placeDemographicsTask = demographicsClient.fetchDemographics(place: place)

        var partialFailures: [CityProfilePartialFailure] = []
        let placeDemographics: Demographics?
        do {
            placeDemographics = try await placeDemographicsTask
        } catch is CancellationError {
            placeDemographics = nil
        } catch {
            LociqDiagnostics.cityProfilePartialLoadFailed(error, stage: "acs-demographics")
            partialFailures.append(
                CityProfilePartialFailure(stage: .demographics, failure: CityProfileLoadFailure(error: error))
            )
            placeDemographics = nil
        }
        let cityBoundary = await cityBoundaryTask
        if cityBoundary == nil {
            partialFailures.append(CityProfilePartialFailure(stage: .boundary, failure: .boundaryUnavailable))
        }

        return ResolvedCityProfile(
            geography: geography,
            boundarySet: CityBoundarySet(city: cityBoundary),
            demographics: CityDemographicsBundle(place: placeDemographics),
            partialFailures: partialFailures
        )
    }

    /// Returns a reusable boundary immediately, or fetches one for the place.
    private func boundary(
        for place: PlaceInfo,
        reusing reusableBoundary: GeoJSONFeatureCollection?
    ) async -> GeoJSONFeatureCollection? {
        if let reusableBoundary { return reusableBoundary }
        return await boundaryClient.fetchPlaceBoundary(place: place)
    }
}
