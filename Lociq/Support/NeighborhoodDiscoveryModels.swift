import CoreLocation
import Foundation

enum NeighborhoodDiscoveryKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case hiddenGem = "hidden_gem"
    case similar = "similar"
    case weekly = "weekly"

    var id: String { rawValue }
}

enum DiscoveryGenerationSource: String, Codable, Sendable {
    case gemini
    case heuristic
}

struct NeighborhoodDiscoveryRecommendation: Identifiable, Equatable, Sendable {
    let id: String
    let kind: NeighborhoodDiscoveryKind
    let title: String
    let subtitle: String
    let summary: String
    let highlights: [String]
    let destination: NeighborhoodLookupSnapshot
}

struct NeighborhoodDiscoveryResult: Equatable, Sendable {
    let seedTitle: String
    let summary: String
    let source: DiscoveryGenerationSource
    let recommendations: [NeighborhoodDiscoveryRecommendation]
    let generatedAt: Date
}

struct NeighborhoodDiscoverySeed: Sendable {
    let snapshot: NeighborhoodLookupSnapshot
    let profile: ResolvedPlaceProfile?
}

enum NeighborhoodDiscoveryError: LocalizedError {
    case missingSeed
    case noCandidates

    var errorDescription: String? {
        switch self {
        case .missingSeed:
            return AppStrings.Labels.discoveryNeedsPlaceBody
        case .noCandidates:
            return AppStrings.Labels.discoveryNoCandidatesBody
        }
    }
}

protocol NeighborhoodDiscoveryServing: Sendable {
    func discoverNeighborhoods(
        from seed: NeighborhoodDiscoverySeed,
        recentPlaces: [NeighborhoodLibraryEntry]
    ) async throws -> NeighborhoodDiscoveryResult
}

struct DiscoveryCandidateProfile: Sendable {
    let id: String
    let title: String
    let subtitle: String
    let zipCode: String?
    let latitude: Double
    let longitude: Double
    let metrics: CensusMetrics
    let demographics: Demographics
    let preferredScale: BoundaryOverlayScale
}
