//
//  CensusCityProfileService.swift
//  Lociq
//
//  Coordinator for Census-backed city lookup and normalization.
//

import Foundation

public final class CensusCityProfileService: @unchecked Sendable {
    public enum ServiceError: Error, LocalizedError {
        case invalidURL
        case requestFailed(status: Int, bodySnippet: String)
        case decodeFailed(String)
        case noBoundaryFound
        case noDemographicsFound

        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .requestFailed(let status, let body): return "HTTP \(status): \(body)"
            case .decodeFailed(let message): return "Decode failed: \(message)"
            case .noBoundaryFound: return "No boundary found"
            case .noDemographicsFound: return "No demographics returned"
            }
        }
    }

    private let directClient: DirectCensusCityProfileClient
    private let lookupCache = CityLookupCache()

    /// Creates a cached city-profile service for the supplied ACS dataset year.
    public nonisolated init(
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
    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedCityProfile {
        let cacheKey = Self.coordinateCacheKey(latitude: latitude, longitude: longitude)

        if let cached = await lookupCache.placeProfile(for: cacheKey) {
            return cached
        }

        let profile = try await directClient.fetchPlaceProfile(latitude: latitude, longitude: longitude)
        await lookupCache.store(placeProfile: profile, for: cacheKey)
        return profile
    }

    /// Rounds coordinates for in-memory profile caching.
    private static func coordinateCacheKey(latitude: Double, longitude: Double) -> String {
        String(format: "%.5f,%.5f", latitude, longitude)
    }
}

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
