//
//  CensusCityProfileService.swift
//  Lociq
//
//  Coordinator for Census-backed city lookup and normalization.
//
//  This service wraps the direct Census client with a small in-memory lookup
//  cache. The cache is intentionally session-scoped and coordinate-keyed. The
//  persistent cache lives elsewhere and stores display-ready profiles.
//

import Foundation

/// Fetches resolved city profiles and memoizes successful coordinate lookups.
///
/// Nearby location updates often report the same city multiple times. A short
/// lived in-memory cache avoids repeating geocoder, ACS, and TIGER requests for
/// the same rounded coordinate during one app session.
struct CensusCityProfileService: Sendable {
    /// Uncached client that performs the actual Census service composition.
    private let directClient: DirectCensusCityProfileClient

    /// Actor-protected memoization store for successful profile lookups.
    private let lookupCache = CityLookupCache()

    /// Creates a cached city-profile service for the supplied ACS dataset year.
    init(
        censusApiKey: String,
        acsYear: Int = 2024,
        session: URLSession = .shared
    ) {
        directClient = DirectCensusCityProfileClient(
            censusApiKey: censusApiKey,
            acsYear: acsYear,
            session: session
        )
    }

    /// Fetches or returns a cached city profile for a rounded coordinate key.
    ///
    /// Only profiles with place-level demographics are cached. Unavailable and
    /// partial shell states are intentionally not memoized here because a later
    /// retry may succeed.
    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedCityProfile {
        let cacheKey = Self.coordinateCacheKey(latitude: latitude, longitude: longitude)

        if let cached = await lookupCache.placeProfile(for: cacheKey) {
            return cached
        }

        let profile = try await directClient.fetchPlaceProfile(latitude: latitude, longitude: longitude)
        if profile.demographics.place != nil {
            await lookupCache.store(placeProfile: profile, for: cacheKey)
        }
        return profile
    }

    /// Rounds coordinates for in-memory profile caching.
    ///
    /// Five decimal places is precise enough to distinguish nearby blocks while
    /// still absorbing minor GPS jitter inside the same local area.
    private static func coordinateCacheKey(latitude: Double, longitude: Double) -> String {
        String(format: "%.5f,%.5f", latitude, longitude)
    }
}

/// Actor-backed in-memory lookup cache for resolved Census profiles.
///
/// `CensusCityProfileService` is `Sendable`, so mutable cache state is isolated
/// behind an actor. This keeps lookups safe when multiple profile requests are
/// triggered by location updates or refresh actions.
private actor CityLookupCache {
    private var placeProfiles: [String: ResolvedCityProfile] = [:]

    /// Returns the profile cached for the supplied key.
    func placeProfile(for key: String) -> ResolvedCityProfile? {
        placeProfiles[key]
    }

    /// Stores a profile for subsequent lookups within the same app session.
    func store(placeProfile: ResolvedCityProfile, for key: String) {
        placeProfiles[key] = placeProfile
    }
}
