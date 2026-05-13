import CoreLocation
import Foundation

final class NeighborhoodDiscoveryService: @unchecked Sendable, NeighborhoodDiscoveryServing {
    private let censusService: any CensusNeighborhoodServing

    nonisolated init(censusService: any CensusNeighborhoodServing) {
        self.censusService = censusService
    }

    func discoverNeighborhoods(
        from seed: NeighborhoodDiscoverySeed,
        recentPlaces: [NeighborhoodLibraryEntry]
    ) async throws -> NeighborhoodDiscoveryResult {
        let seedProfile = try await resolvedSeedProfile(from: seed)
        let seedCandidate = NeighborhoodDiscoveryCandidateFactory.candidate(
            profile: seedProfile,
            coordinate: CLLocationCoordinate2D(
                latitude: seed.snapshot.latitude,
                longitude: seed.snapshot.longitude
            ),
            scale: seed.snapshot.preferredScale
        )

        let candidates = try await nearbyCandidates(around: seedCandidate)
        guard !candidates.isEmpty else {
            throw NeighborhoodDiscoveryError.noCandidates
        }

        let recommendations = NeighborhoodDiscoveryHeuristicRanker.recommendations(
            seed: seedCandidate,
            candidates: candidates,
            scale: seed.snapshot.preferredScale
        )
        return NeighborhoodDiscoveryResult(
            seedTitle: seedCandidate.title,
            summary: NeighborhoodDiscoveryHeuristicRanker.summary(seed: seedCandidate, recommendations: recommendations),
            source: .heuristic,
            recommendations: recommendations,
            generatedAt: Date()
        )
    }

    private func resolvedSeedProfile(from seed: NeighborhoodDiscoverySeed) async throws -> ResolvedPlaceProfile {
        if let profile = seed.profile {
            return profile
        }

        return try await censusService.fetchPlaceProfile(
            latitude: seed.snapshot.latitude,
            longitude: seed.snapshot.longitude
        )
    }

    private func nearbyCandidates(around seed: DiscoveryCandidateProfile) async throws -> [DiscoveryCandidateProfile] {
        let offsets = [
            (distanceKm: 1.8, bearingDegrees: 0.0),
            (distanceKm: 1.8, bearingDegrees: 60.0),
            (distanceKm: 1.8, bearingDegrees: 120.0),
            (distanceKm: 1.8, bearingDegrees: 180.0),
            (distanceKm: 1.8, bearingDegrees: 240.0),
            (distanceKm: 1.8, bearingDegrees: 300.0),
            (distanceKm: 3.8, bearingDegrees: 45.0),
            (distanceKm: 3.8, bearingDegrees: 225.0)
        ]

        var fetched: [DiscoveryCandidateProfile] = []

        await withTaskGroup(of: DiscoveryCandidateProfile?.self) { group in
            for offset in offsets {
                group.addTask { [censusService] in
                    let coordinate = NeighborhoodDiscoveryCandidateFactory.offsetCoordinate(
                        from: CLLocationCoordinate2D(
                            latitude: seed.latitude,
                            longitude: seed.longitude
                        ),
                        distanceKilometers: offset.distanceKm,
                        bearingDegrees: offset.bearingDegrees
                    )

                    do {
                        let profile = try await censusService.fetchPlaceProfile(
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude
                        )
                        return NeighborhoodDiscoveryCandidateFactory.candidate(
                            profile: profile,
                            coordinate: coordinate,
                            scale: seed.preferredScale
                        )
                    } catch {
                        return nil
                    }
                }
            }

            for await candidate in group {
                if let candidate {
                    fetched.append(candidate)
                }
            }
        }

        var seenIDs: Set<String> = [seed.id]
        return fetched.filter { candidate in
            guard !seenIDs.contains(candidate.id) else { return false }
            seenIDs.insert(candidate.id)
            return true
        }
    }

}
