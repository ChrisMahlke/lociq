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

    /// Main entry point:
    /// lat/lon -> ZCTA + county + tract + place/incorporation -> boundary + ACS -> insights
    public func fetchZipBundle(latitude: Double, longitude: Double) async throws -> ZipLookupResult {
        if let firebaseClient {
            do {
                return try await firebaseClient.fetchZipBundle(latitude: latitude, longitude: longitude)
            } catch {
                Self.logger.error("Firebase zip bundle lookup failed; falling back to direct APIs. \(String(describing: error), privacy: .public)")
            }
        }

        return try await directClient.fetchZipBundle(latitude: latitude, longitude: longitude)
    }

    public func fetchNeighborhoodBoundaries(
        latitude: Double,
        longitude: Double,
        tractGeoid: String?,
        zipBoundary: GeoJSONFeatureCollection
    ) async -> NeighborhoodBoundarySet {
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

    private static func extractZCTA(from boundary: GeoJSONFeatureCollection) -> String? {
        for feature in boundary.features {
            if let zcta = feature.properties?["ZCTA5"] ?? feature.properties?["GEOID"] {
                return zcta
            }
        }

        return nil
    }
}
