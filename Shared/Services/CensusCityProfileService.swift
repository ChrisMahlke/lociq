//
//  CensusCityProfileService.swift
//  Lociq
//
//  Coordinator for Census-backed city lookup and normalization.
//
//  This service wraps the direct Census client with a small in-memory lookup
//  cache. The cache is session-scoped and keyed by Census place, so a new fix
//  anywhere in the same place reuses statistics. The persistent cache lives
//  elsewhere and stores display-ready profiles.
//

import Foundation

/// Fetches resolved city profiles and memoizes successful lookups by place.
///
/// Every fetch geocodes, because the place is what decides whether cached
/// statistics apply. ACS and TIGER requests are skipped when the place already
/// loaded this session, unless the caller forces a refresh.
struct CensusCityProfileService: Sendable {
    /// Uncached client that performs the actual Census service composition.
    private let directClient: DirectCensusCityProfileClient

    /// Actor-protected memoization store for successful profile lookups.
    private let lookupCache = CityLookupCache()

    /// Creates a cached city-profile service around a direct client.
    init(directClient: DirectCensusCityProfileClient) {
        self.directClient = directClient
    }

    /// Resolves the place for a coordinate, then returns memoized or fresh statistics.
    ///
    /// Only complete profiles are memoized: demographics and boundary both
    /// loaded, from a fetch that was not cancelled. Unavailable and partial
    /// results are never memoized, so a later load can still heal them.
    func fetchPlaceProfile(
        latitude: Double,
        longitude: Double,
        options: CityProfileFetchOptions = CityProfileFetchOptions()
    ) async throws -> ResolvedCityProfile {
        let geography = try await directClient.fetchGeography(latitude: latitude, longitude: longitude)

        guard let placeKey = geography.place?.geoid else {
            return await directClient.fetchPlaceProfile(for: geography)
        }

        if !options.forceRefresh, let cached = await lookupCache.placeProfile(for: placeKey) {
            return cached
        }

        let profile = await directClient.fetchPlaceProfile(for: geography, knownBoundary: options.knownBoundary)
        if profile.demographics.place != nil, profile.partialFailures.isEmpty, !Task.isCancelled {
            await lookupCache.store(placeProfile: profile, for: placeKey)
        }
        return profile
    }
}

/// Actor-backed in-memory lookup cache for resolved Census profiles.
///
/// `CensusCityProfileService` is `Sendable`, so mutable cache state is isolated
/// behind an actor. This keeps lookups safe when multiple profile requests are
/// triggered by location updates or refresh actions.
private actor CityLookupCache {
    private var placeProfiles: [String: ResolvedCityProfile] = [:]

    /// Returns the profile cached for the supplied place GEOID.
    func placeProfile(for key: String) -> ResolvedCityProfile? {
        placeProfiles[key]
    }

    /// Stores a profile for subsequent lookups within the same app session.
    func store(placeProfile: ResolvedCityProfile, for key: String) {
        placeProfiles[key] = placeProfile
    }
}

/// The Census clients the app uses, built once and shared by every path.
///
/// One graph means one set of session caches: a boundary downloaded by one
/// load is reused by the next, and no path builds duplicate clients.
struct CensusServiceGraph: Sendable {
    let geocoderClient: CensusGeocoderClient
    let boundaryClient: TIGERBoundaryClient
    let demographicsClient: ACSDemographicsClient
    let profileService: CensusCityProfileService

    /// Builds the production client graph over one URL session.
    init(censusAPIKey: String, vintage: CensusDataVintage = .current, session: URLSession = .shared) {
        let httpClient = CensusHTTPClient(session: session)
        let boundaryHTTPClient = CensusHTTPClient(session: session, retryPolicy: .boundary)
        geocoderClient = CensusGeocoderClient(httpClient: httpClient, vintage: vintage)
        boundaryClient = TIGERBoundaryClient(httpClient: boundaryHTTPClient, vintage: vintage)
        demographicsClient = ACSDemographicsClient(
            censusApiKey: censusAPIKey,
            acsYear: vintage.acsYear,
            httpClient: httpClient
        )
        profileService = CensusCityProfileService(
            directClient: DirectCensusCityProfileClient(
                geocoderClient: geocoderClient,
                boundaryClient: boundaryClient,
                demographicsClient: demographicsClient
            )
        )
    }
}
