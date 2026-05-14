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
    private let geocoderClient: CensusGeocoderClient

    /// TIGERweb boundary client for the resolved place.
    private let boundaryClient: TIGERBoundaryClient

    /// ACS demographic client for the resolved place.
    private let demographicsClient: ACSDemographicsClient

    /// Creates the direct Census client by composing geocoder, ACS, and TIGERweb dependencies over one session.
    init(
        censusApiKey: String,
        acsYear: Int = 2024,
        session: URLSession = .shared
    ) {
        let httpClient = CensusHTTPClient(session: session)
        geocoderClient = CensusGeocoderClient(httpClient: httpClient)
        boundaryClient = TIGERBoundaryClient(httpClient: httpClient)
        demographicsClient = ACSDemographicsClient(
            censusApiKey: censusApiKey,
            acsYear: acsYear,
            httpClient: httpClient
        )
    }

    /// Resolves a coordinate into one city-level profile with place demographics and boundary geometry.
    ///
    /// Boundary and demographic requests are started concurrently after
    /// geocoding succeeds because they are independent once the place is known.
    /// Demographic failure is captured as a partial failure rather than
    /// throwing immediately, which allows the loader to decide whether a
    /// location shell can still be useful.
    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedCityProfile {
        let geographies = try await geocoderClient.fetchGeographiesFromCoordinate(
            latitude: latitude,
            longitude: longitude
        )
        let geography = CityGeographyProfile(
            county: geographies.county,
            place: geographies.place
        )

        async let cityBoundaryTask = boundaryClient.fetchPlaceBoundary(place: geography.place)
        async let placeDemographicsTask = fetchPlaceDemographics(place: geography.place)
        var partialFailures: [CityProfilePartialFailure] = []
        let placeDemographics: Demographics?
        do {
            placeDemographics = try await placeDemographicsTask
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
            demographics: CityDemographicsBundle(
                place: placeDemographics
            ),
            partialFailures: partialFailures
        )
    }

    /// Fetches demographics for a resolved place or throws when no place is available.
    ///
    /// Missing place metadata means ACS cannot be queried at the place level,
    /// so the condition is normalized into `noDemographicsFound`.
    private func fetchPlaceDemographics(place: PlaceInfo?) async throws -> Demographics {
        guard let place else {
            throw CensusServiceError.noDemographicsFound
        }

        return try await demographicsClient.fetchDemographics(place: place)
    }
}
