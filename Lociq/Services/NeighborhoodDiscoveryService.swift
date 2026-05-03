import CoreLocation
import Foundation

final class NeighborhoodDiscoveryService: @unchecked Sendable, NeighborhoodDiscoveryServing {
    private let censusService: any CensusNeighborhoodServing
    private let geminiClient: GeminiDiscoveryClient?

    nonisolated init(
        censusService: any CensusNeighborhoodServing,
        geminiClient: GeminiDiscoveryClient?
    ) {
        self.censusService = censusService
        self.geminiClient = geminiClient
    }

    func discoverNeighborhoods(
        from seed: NeighborhoodDiscoverySeed,
        recentPlaces: [NeighborhoodLibraryEntry]
    ) async throws -> NeighborhoodDiscoveryResult {
        let seedProfile = try await resolvedSeedProfile(from: seed)
        let seedCandidate = makeCandidate(
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

        if let geminiClient {
            do {
                let plan = try await geminiClient.planRecommendations(
                    seed: seedCandidate,
                    candidates: candidates,
                    recentPlaces: recentPlaces
                )
                let recommendations = merge(plan: plan, candidates: candidates, scale: seed.snapshot.preferredScale)
                if recommendations.count == 3 {
                    return NeighborhoodDiscoveryResult(
                        seedTitle: seedCandidate.title,
                        summary: plan.summary,
                        source: .gemini,
                        recommendations: recommendations,
                        generatedAt: Date()
                    )
                }
            } catch {
                // Fall through to the local heuristic path.
            }
        }

        let recommendations = heuristicRecommendations(
            seed: seedCandidate,
            candidates: candidates,
            scale: seed.snapshot.preferredScale
        )
        return NeighborhoodDiscoveryResult(
            seedTitle: seedCandidate.title,
            summary: heuristicSummary(seed: seedCandidate, recommendations: recommendations),
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
                    let coordinate = Self.offsetCoordinate(
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
                        return Self.makeCandidate(
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

    private func merge(
        plan: GeminiDiscoveryPlan,
        candidates: [DiscoveryCandidateProfile],
        scale: BoundaryOverlayScale
    ) -> [NeighborhoodDiscoveryRecommendation] {
        let candidateByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        var used: Set<String> = []

        return plan.recommendations.compactMap { selection in
            guard
                let candidate = candidateByID[selection.candidateID],
                !used.contains(candidate.id)
            else {
                return nil
            }
            used.insert(candidate.id)

            return NeighborhoodDiscoveryRecommendation(
                id: "\(selection.kind.rawValue)-\(candidate.id)",
                kind: selection.kind,
                title: candidate.title,
                subtitle: candidate.subtitle,
                summary: selection.summary,
                highlights: Array(selection.highlights.prefix(3)),
                destination: NeighborhoodLookupSnapshot(
                    id: candidate.id,
                    title: candidate.title,
                    subtitle: candidate.subtitle,
                    zipCode: candidate.zipCode,
                    latitude: candidate.latitude,
                    longitude: candidate.longitude,
                    preferredScale: scale
                )
            )
        }
    }

    private func heuristicRecommendations(
        seed: DiscoveryCandidateProfile,
        candidates: [DiscoveryCandidateProfile],
        scale: BoundaryOverlayScale
    ) -> [NeighborhoodDiscoveryRecommendation] {
        let similar = candidates.min(by: { similarityScore(seed: seed, candidate: $0) < similarityScore(seed: seed, candidate: $1) })
        let hiddenGem = candidates.max(by: { hiddenGemScore(seed: seed, candidate: $0) < hiddenGemScore(seed: seed, candidate: $1) })
        let weekly = candidates.max(by: { stretchScore(seed: seed, candidate: $0) < stretchScore(seed: seed, candidate: $1) })

        var used: Set<String> = []
        let picks: [(NeighborhoodDiscoveryKind, DiscoveryCandidateProfile?, String)] = [
            (.hiddenGem, hiddenGem, AppStrings.Formats.discoveryHiddenGemFallback(seed.title)),
            (.similar, similar, AppStrings.Formats.discoverySimilarFallback(seed.title)),
            (.weekly, weekly, AppStrings.Formats.discoveryWeeklyFallback(seed.title))
        ]

        var recommendations: [NeighborhoodDiscoveryRecommendation] = []
        for (kind, maybeCandidate, fallbackSummary) in picks {
            guard let candidate = maybeCandidate else { continue }
            guard !used.contains(candidate.id) else { continue }
            used.insert(candidate.id)

            let highlights = highlightChips(seed: seed, candidate: candidate)
            recommendations.append(
                NeighborhoodDiscoveryRecommendation(
                    id: "\(kind.rawValue)-\(candidate.id)",
                    kind: kind,
                    title: candidate.title,
                    subtitle: candidate.subtitle,
                    summary: fallbackSummary,
                    highlights: highlights,
                    destination: NeighborhoodLookupSnapshot(
                        id: candidate.id,
                        title: candidate.title,
                        subtitle: candidate.subtitle,
                        zipCode: candidate.zipCode,
                        latitude: candidate.latitude,
                        longitude: candidate.longitude,
                        preferredScale: scale
                    )
                )
            )
        }

        if recommendations.count < 3 {
            for candidate in candidates where !used.contains(candidate.id) {
                used.insert(candidate.id)
                recommendations.append(
                    NeighborhoodDiscoveryRecommendation(
                        id: "extra-\(candidate.id)",
                        kind: .weekly,
                        title: candidate.title,
                        subtitle: candidate.subtitle,
                        summary: AppStrings.Formats.discoveryWeeklyFallback(seed.title),
                        highlights: highlightChips(seed: seed, candidate: candidate),
                        destination: NeighborhoodLookupSnapshot(
                            id: candidate.id,
                            title: candidate.title,
                            subtitle: candidate.subtitle,
                            zipCode: candidate.zipCode,
                            latitude: candidate.latitude,
                            longitude: candidate.longitude,
                            preferredScale: scale
                        )
                    )
                )
                if recommendations.count == 3 {
                    break
                }
            }
        }

        return recommendations
    }

    private func heuristicSummary(
        seed: DiscoveryCandidateProfile,
        recommendations: [NeighborhoodDiscoveryRecommendation]
    ) -> String {
        guard !recommendations.isEmpty else {
            return AppStrings.Labels.discoveryNoCandidatesBody
        }

        let titles = recommendations.map(\.title)
        switch titles.count {
        case 1:
            return AppStrings.Formats.discoverySummarySingle(seed.title, titles[0])
        case 2:
            return AppStrings.Formats.discoverySummaryPair(seed.title, titles[0], titles[1])
        default:
            return AppStrings.Formats.discoverySummaryTriple(seed.title, titles[0], titles[1], titles[2])
        }
    }

    private func similarityScore(seed: DiscoveryCandidateProfile, candidate: DiscoveryCandidateProfile) -> Double {
        let population = normalizedDifference(seed.metrics.population, candidate.metrics.population, floor: 5_000)
        let income = normalizedDifference(seed.metrics.medianIncome, candidate.metrics.medianIncome, floor: 10_000)
        let age = normalizedDifference(seed.metrics.medianAge, candidate.metrics.medianAge, floor: 2)
        let rent = normalizedDifference(seed.demographics.medianGrossRent, candidate.demographics.medianGrossRent, floor: 200)
        let poverty = normalizedDifference(seed.demographics.povertyRatePct, candidate.demographics.povertyRatePct, floor: 2)
        return population + income + age + rent + poverty
    }

    private func hiddenGemScore(seed: DiscoveryCandidateProfile, candidate: DiscoveryCandidateProfile) -> Double {
        let seedRent = Double(seed.demographics.medianGrossRent ?? 0)
        let candidateRent = Double(candidate.demographics.medianGrossRent ?? 0)
        let rentAdvantage = max(0, seedRent - candidateRent) / 300

        let seedHomeValue = Double(seed.demographics.medianHomeValue ?? 0)
        let candidateHomeValue = Double(candidate.demographics.medianHomeValue ?? 0)
        let homeValueAdvantage = max(0, seedHomeValue - candidateHomeValue) / 75_000

        let povertyPenalty = max(0, (candidate.demographics.povertyRatePct ?? 0) - ((seed.demographics.povertyRatePct ?? 0) + 2)) / 2
        let remoteBoost = (candidate.demographics.workersWfhPct ?? 0) / 8
        return rentAdvantage + homeValueAdvantage + remoteBoost - povertyPenalty
    }

    private func stretchScore(seed: DiscoveryCandidateProfile, candidate: DiscoveryCandidateProfile) -> Double {
        let contrast = normalizedDifference(seed.metrics.medianIncome, candidate.metrics.medianIncome, floor: 10_000)
            + normalizedDifference(seed.metrics.medianAge, candidate.metrics.medianAge, floor: 2)
            + normalizedDifference(seed.demographics.ownerOccupiedPct, candidate.demographics.ownerOccupiedPct, floor: 4)
        let povertyGuard = max(0, 18 - (candidate.demographics.povertyRatePct ?? 18)) / 6
        return contrast + povertyGuard
    }

    private func highlightChips(seed: DiscoveryCandidateProfile, candidate: DiscoveryCandidateProfile) -> [String] {
        var chips: [String] = []

        if let seedRent = seed.demographics.medianGrossRent,
           let candidateRent = candidate.demographics.medianGrossRent,
           abs(seedRent - candidateRent) >= 150 {
            let winner = candidateRent < seedRent ? candidate.title : seed.title
            chips.append(AppStrings.Formats.discoveryLowerRent(winner))
        }

        if let seedIncome = seed.metrics.medianIncome,
           let candidateIncome = candidate.metrics.medianIncome,
           abs(seedIncome - candidateIncome) >= 10_000 {
            let winner = candidateIncome > seedIncome ? candidate.title : seed.title
            chips.append(AppStrings.Formats.discoveryHigherIncome(winner))
        }

        if let seedRemote = seed.demographics.workersWfhPct,
           let candidateRemote = candidate.demographics.workersWfhPct,
           abs(seedRemote - candidateRemote) >= 2 {
            let winner = candidateRemote > seedRemote ? candidate.title : seed.title
            chips.append(AppStrings.Formats.discoveryRemoteWork(winner))
        }

        if let seedPoverty = seed.demographics.povertyRatePct,
           let candidatePoverty = candidate.demographics.povertyRatePct,
           abs(seedPoverty - candidatePoverty) >= 1.5 {
            let winner = candidatePoverty < seedPoverty ? candidate.title : seed.title
            chips.append(AppStrings.Formats.discoveryLowerPoverty(winner))
        }

        if chips.isEmpty {
            chips.append(AppStrings.Formats.discoverySimilarVibe(candidate.title))
        }

        return Array(chips.prefix(3))
    }

    private func normalizedDifference<T: BinaryInteger>(_ lhs: T?, _ rhs: T?, floor: Double) -> Double {
        guard let lhs, let rhs else { return 0 }
        return abs(Double(Int(lhs) - Int(rhs))) / floor
    }

    private func normalizedDifference(_ lhs: Double?, _ rhs: Double?, floor: Double) -> Double {
        guard let lhs, let rhs else { return 0 }
        return abs(lhs - rhs) / floor
    }

    nonisolated private static func offsetCoordinate(
        from coordinate: CLLocationCoordinate2D,
        distanceKilometers: Double,
        bearingDegrees: Double
    ) -> CLLocationCoordinate2D {
        let earthRadiusKm = 6_371.0
        let bearing = bearingDegrees * .pi / 180
        let distanceRatio = distanceKilometers / earthRadiusKm
        let startLat = coordinate.latitude * .pi / 180
        let startLon = coordinate.longitude * .pi / 180

        let endLat = asin(
            sin(startLat) * cos(distanceRatio) +
            cos(startLat) * sin(distanceRatio) * cos(bearing)
        )

        let endLon = startLon + atan2(
            sin(bearing) * sin(distanceRatio) * cos(startLat),
            cos(distanceRatio) - sin(startLat) * sin(endLat)
        )

        return CLLocationCoordinate2D(
            latitude: endLat * 180 / .pi,
            longitude: endLon * 180 / .pi
        )
    }

    nonisolated private static func makeCandidate(
        profile: ResolvedPlaceProfile,
        coordinate: CLLocationCoordinate2D,
        scale: BoundaryOverlayScale
    ) -> DiscoveryCandidateProfile {
        let demographics = scale == .tract ? (profile.scaleDemographics.tract ?? profile.scaleDemographics.zip) : profile.scaleDemographics.zip
        let metrics = CensusMetrics(
            population: demographics.population,
            medianIncome: demographics.medianHouseholdIncome,
            medianAge: demographics.medianAge,
            households: demographics.housingUnits,
            populationTrend: nil,
            ageBuckets: nil,
            educationLevels: nil,
            householdIncome: nil
        )

        let title = profile.zipBundle.place?.name ?? demographics.name
        let subtitle = makeSubtitle(bundle: profile.zipBundle, scale: scale)
        let id = profile.zipBundle.tract?.geoid ?? profile.zipBundle.zcta

        return DiscoveryCandidateProfile(
            id: id,
            title: title,
            subtitle: subtitle,
            zipCode: profile.zipBundle.zcta,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            metrics: metrics,
            demographics: demographics,
            preferredScale: scale
        )
    }

    nonisolated private static func makeSubtitle(bundle: ZipLookupResult, scale: BoundaryOverlayScale) -> String {
        var parts: [String] = []
        if let county = bundle.county?.name, !county.isEmpty {
            parts.append(county)
        }
        parts.append(AppStrings.Formats.zip(bundle.zcta))
        if scale == .tract, let tractCode = bundle.tract?.tractCode, !tractCode.isEmpty {
            parts.append(AppStrings.Formats.tract(tractCode))
        }
        return parts.joined(separator: " · ")
    }

    private func makeCandidate(
        profile: ResolvedPlaceProfile,
        coordinate: CLLocationCoordinate2D,
        scale: BoundaryOverlayScale
    ) -> DiscoveryCandidateProfile {
        Self.makeCandidate(profile: profile, coordinate: coordinate, scale: scale)
    }

}
