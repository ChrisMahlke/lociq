//
//  CensusZipDemographicsService.swift
//  Lociq
//
//  Coordinator that prefers the Firebase callable backend and falls back to
//  the direct Census client when needed.
//

import Foundation
import os

protocol CensusNeighborhoodServing: Sendable {
    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedPlaceProfile
    func fetchZipBundle(latitude: Double, longitude: Double) async throws -> ZipLookupResult
    func fetchNeighborhoodBoundaries(
        latitude: Double,
        longitude: Double,
        tractGeoid: String?,
        zipBoundary: GeoJSONFeatureCollection
    ) async -> NeighborhoodBoundarySet
    func fetchDemographics(
        for scale: NeighborhoodScale,
        zcta: String,
        tractGeoid: String?,
        latitude: Double,
        longitude: Double
    ) async throws -> Demographics
    func fetchComparisonProfile(
        latitude: Double,
        longitude: Double,
        scale: NeighborhoodScale,
        fallbackTitle: String,
        fallbackSubtitle: String
    ) async throws -> ComparisonProfileResult
}

public final class CensusZipDemographicsService: @unchecked Sendable, CensusNeighborhoodServing {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.chrismahlke.lociq",
        category: "CensusZipDemographicsService"
    )

    public enum ServiceError: Error, LocalizedError {
        case invalidURL
        case requestFailed(status: Int, bodySnippet: String)
        case decodeFailed(String)
        case noZCTAFound
        case noBoundaryFound
        case noDemographicsFound

        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .requestFailed(let status, let body): return "HTTP \(status): \(body)"
            case .decodeFailed(let msg): return "Decode failed: \(msg)"
            case .noZCTAFound: return "No ZCTA found for coordinate"
            case .noBoundaryFound: return "No boundary found for ZCTA"
            case .noDemographicsFound: return "No demographics returned for ZCTA"
            }
        }
    }

    private let directClient: DirectCensusZipDemographicsClient
    private let firebaseClient: FirebaseLociqCallableClient?
    private let lookupCache = NeighborhoodLookupCache()

    public init(
        censusApiKey: String,
        acsYear: Int = 2024,
        session: URLSession = .shared,
        firebaseClient: FirebaseLociqCallableClient? = nil
    ) {
        self.directClient = DirectCensusZipDemographicsClient(
            censusApiKey: censusApiKey,
            acsYear: acsYear,
            session: session
        )
        self.firebaseClient = firebaseClient ?? FirebaseLociqCallableClient.makeDefaultIfAvailable()
    }

    // MARK: - Public API

    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedPlaceProfile {
        let cacheKey = Self.coordinateCacheKey(latitude: latitude, longitude: longitude)

        if let cached = await lookupCache.placeProfile(for: cacheKey) {
            return cached
        }

        if let firebaseClient {
            do {
                let profile = try await firebaseClient.fetchPlaceProfile(latitude: latitude, longitude: longitude)
                await lookupCache.store(placeProfile: profile, for: cacheKey)
                return profile
            } catch {
                Self.logger.error("Firebase place profile lookup failed; falling back to direct APIs. \(String(describing: error), privacy: .public)")
            }
        }

        let profile = try await directClient.fetchPlaceProfile(latitude: latitude, longitude: longitude)
        await lookupCache.store(placeProfile: profile, for: cacheKey)
        return profile
    }

    /// Main entry point:
    /// lat/lon -> ZCTA + county + tract + place/incorporation -> boundary + ACS -> insights
    public func fetchZipBundle(latitude: Double, longitude: Double) async throws -> ZipLookupResult {
        let profile = try await fetchPlaceProfile(latitude: latitude, longitude: longitude)
        return profile.zipBundle
    }

    public func fetchNeighborhoodBoundaries(
        latitude: Double,
        longitude: Double,
        tractGeoid: String?,
        zipBoundary: GeoJSONFeatureCollection
    ) async -> NeighborhoodBoundarySet {
        let cacheKey = Self.coordinateCacheKey(latitude: latitude, longitude: longitude)
        if let cached = await lookupCache.placeProfile(for: cacheKey) {
            return cached.boundaries
        }

        if let firebaseClient {
            do {
                return try await firebaseClient.fetchNeighborhoodBoundaries(
                    latitude: latitude,
                    longitude: longitude,
                    tractGeoid: tractGeoid,
                    zcta: Self.extractZCTA(from: zipBoundary)
                )
            } catch {
                Self.logger.error("Firebase boundary lookup failed; falling back to direct APIs. \(String(describing: error), privacy: .public)")
            }
        }

        return await directClient.fetchNeighborhoodBoundaries(
            latitude: latitude,
            longitude: longitude,
            tractGeoid: tractGeoid,
            zipBoundary: zipBoundary
        )
    }

    public func fetchDemographics(
        for scale: NeighborhoodScale,
        zcta: String,
        tractGeoid: String?,
        latitude: Double,
        longitude: Double
    ) async throws -> Demographics {
        let cacheKey = Self.coordinateCacheKey(latitude: latitude, longitude: longitude)
        if let cached = await lookupCache.placeProfile(for: cacheKey) {
            switch scale {
            case .zip:
                return cached.scaleDemographics.zip
            case .tract:
                if let tract = cached.scaleDemographics.tract {
                    return tract
                }
            }
        }

        if let firebaseClient {
            do {
                return try await firebaseClient.fetchDemographics(
                    scale: scale,
                    zcta: zcta,
                    tractGeoid: tractGeoid,
                    latitude: latitude,
                    longitude: longitude
                )
            } catch {
                Self.logger.error("Firebase demographics lookup failed; falling back to direct APIs. \(String(describing: error), privacy: .public)")
            }
        }

        return try await directClient.fetchDemographics(
            for: scale,
            zcta: zcta,
            tractGeoid: tractGeoid,
            latitude: latitude,
            longitude: longitude
        )
    }

    func fetchComparisonProfile(
        latitude: Double,
        longitude: Double,
        scale: NeighborhoodScale,
        fallbackTitle: String,
        fallbackSubtitle: String
    ) async throws -> ComparisonProfileResult {
        let cacheKey = Self.comparisonCacheKey(
            latitude: latitude,
            longitude: longitude,
            scale: scale
        )

        if let cached = await lookupCache.comparisonProfile(for: cacheKey) {
            return cached
        }

        if let firebaseClient {
            do {
                let comparison = try await firebaseClient.fetchComparisonProfile(
                    latitude: latitude,
                    longitude: longitude,
                    scale: scale,
                    fallbackTitle: fallbackTitle,
                    fallbackSubtitle: fallbackSubtitle
                )
                await lookupCache.store(comparisonProfile: comparison, for: cacheKey)
                return comparison
            } catch {
                Self.logger.error("Firebase comparison lookup failed; falling back to direct APIs. \(String(describing: error), privacy: .public)")
            }
        }

        let comparison = try await directClient.fetchComparisonProfile(
            latitude: latitude,
            longitude: longitude,
            scale: scale,
            fallbackTitle: fallbackTitle,
            fallbackSubtitle: fallbackSubtitle
        )
        await lookupCache.store(comparisonProfile: comparison, for: cacheKey)
        return comparison
    }

    private static func extractZCTA(from boundary: GeoJSONFeatureCollection) -> String? {
        for feature in boundary.features {
            if let zcta = feature.properties?["ZCTA5"] ?? feature.properties?["GEOID"] {
                return zcta
            }
        }

        return nil
    }

    private static func coordinateCacheKey(latitude: Double, longitude: Double) -> String {
        String(format: "%.5f,%.5f", latitude, longitude)
    }

    private static func comparisonCacheKey(
        latitude: Double,
        longitude: Double,
        scale: NeighborhoodScale
    ) -> String {
        "\(coordinateCacheKey(latitude: latitude, longitude: longitude)):\(scale == .tract ? "tract" : "zip")"
    }
}

private actor NeighborhoodLookupCache {
    private var placeProfiles: [String: ResolvedPlaceProfile] = [:]
    private var comparisonProfiles: [String: ComparisonProfileResult] = [:]

    func placeProfile(for key: String) -> ResolvedPlaceProfile? {
        placeProfiles[key]
    }

    func comparisonProfile(for key: String) -> ComparisonProfileResult? {
        comparisonProfiles[key]
    }

    func store(placeProfile: ResolvedPlaceProfile, for key: String) {
        placeProfiles[key] = placeProfile
    }

    func store(comparisonProfile: ComparisonProfileResult, for key: String) {
        comparisonProfiles[key] = comparisonProfile
    }
}
