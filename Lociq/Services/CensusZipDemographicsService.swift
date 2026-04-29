//
//  CensusZipDemographicsService.swift
//  Lociq
//
//  Coordinator for Census-backed neighborhood lookup and normalization.
//

import Foundation

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
    private let lookupCache = NeighborhoodLookupCache()

    public init(
        censusApiKey: String,
        acsYear: Int = 2024,
        session: URLSession = .shared
    ) {
        self.directClient = DirectCensusZipDemographicsClient(
            censusApiKey: censusApiKey,
            acsYear: acsYear,
            session: session
        )
    }

    // MARK: - Public API

    func fetchPlaceProfile(latitude: Double, longitude: Double) async throws -> ResolvedPlaceProfile {
        let cacheKey = Self.coordinateCacheKey(latitude: latitude, longitude: longitude)

        if let cached = await lookupCache.placeProfile(for: cacheKey) {
            return cached
        }

        let profile = try await directClient.fetchPlaceProfile(latitude: latitude, longitude: longitude)
        let normalizedProfile = await normalizeInsights(in: profile)
        await lookupCache.store(placeProfile: normalizedProfile, for: cacheKey)
        return normalizedProfile
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

    private func normalizeInsights(in profile: ResolvedPlaceProfile) async -> ResolvedPlaceProfile {
        let normalizedInsights = await normalizedInsights(for: profile.zipBundle)
        let normalizedBundle = ZipLookupResult(
            zcta: profile.zipBundle.zcta,
            county: profile.zipBundle.county,
            tract: profile.zipBundle.tract,
            place: profile.zipBundle.place,
            isIncorporatedPlace: profile.zipBundle.isIncorporatedPlace,
            boundary: profile.zipBundle.boundary,
            boundaryMetrics: profile.zipBundle.boundaryMetrics,
            demographics: profile.zipBundle.demographics,
            insights: normalizedInsights
        )

        return ResolvedPlaceProfile(
            zipBundle: normalizedBundle,
            boundaries: profile.boundaries,
            scaleDemographics: profile.scaleDemographics
        )
    }

    private func normalizedInsights(for bundle: ZipLookupResult) async -> [Insight] {
        return InsightEngine.makeInsights(
            zcta: bundle.zcta,
            county: bundle.county,
            tract: bundle.tract,
            isIncorporatedPlace: bundle.isIncorporatedPlace,
            boundaryMetrics: bundle.boundaryMetrics,
            demographics: bundle.demographics
        )
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
