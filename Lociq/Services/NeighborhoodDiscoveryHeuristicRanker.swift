import Foundation

enum NeighborhoodDiscoveryHeuristicRanker {
    static func recommendations(
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
            guard let candidate = maybeCandidate, !used.contains(candidate.id) else { continue }
            used.insert(candidate.id)
            recommendations.append(
                recommendation(
                    kind: kind,
                    candidate: candidate,
                    summary: fallbackSummary,
                    highlights: highlightChips(seed: seed, candidate: candidate),
                    scale: scale
                )
            )
        }

        appendFallbackRecommendations(
            seed: seed,
            candidates: candidates,
            scale: scale,
            used: &used,
            recommendations: &recommendations
        )

        return recommendations
    }

    static func summary(
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

    private static func appendFallbackRecommendations(
        seed: DiscoveryCandidateProfile,
        candidates: [DiscoveryCandidateProfile],
        scale: BoundaryOverlayScale,
        used: inout Set<String>,
        recommendations: inout [NeighborhoodDiscoveryRecommendation]
    ) {
        guard recommendations.count < 3 else { return }

        for candidate in candidates where !used.contains(candidate.id) {
            used.insert(candidate.id)
            recommendations.append(
                recommendation(
                    kind: .weekly,
                    candidate: candidate,
                    summary: AppStrings.Formats.discoveryWeeklyFallback(seed.title),
                    highlights: highlightChips(seed: seed, candidate: candidate),
                    scale: scale,
                    idPrefix: "extra"
                )
            )

            if recommendations.count == 3 {
                break
            }
        }
    }

    private static func recommendation(
        kind: NeighborhoodDiscoveryKind,
        candidate: DiscoveryCandidateProfile,
        summary: String,
        highlights: [String],
        scale: BoundaryOverlayScale,
        idPrefix: String? = nil
    ) -> NeighborhoodDiscoveryRecommendation {
        NeighborhoodDiscoveryRecommendation(
            id: "\(idPrefix ?? kind.rawValue)-\(candidate.id)",
            kind: kind,
            title: candidate.title,
            subtitle: candidate.subtitle,
            summary: summary,
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
    }

    private static func similarityScore(seed: DiscoveryCandidateProfile, candidate: DiscoveryCandidateProfile) -> Double {
        let population = normalizedDifference(seed.metrics.population, candidate.metrics.population, floor: 5_000)
        let income = normalizedDifference(seed.metrics.medianIncome, candidate.metrics.medianIncome, floor: 10_000)
        let age = normalizedDifference(seed.metrics.medianAge, candidate.metrics.medianAge, floor: 2)
        let rent = normalizedDifference(seed.demographics.medianGrossRent, candidate.demographics.medianGrossRent, floor: 200)
        let poverty = normalizedDifference(seed.demographics.povertyRatePct, candidate.demographics.povertyRatePct, floor: 2)
        return population + income + age + rent + poverty
    }

    private static func hiddenGemScore(seed: DiscoveryCandidateProfile, candidate: DiscoveryCandidateProfile) -> Double {
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

    private static func stretchScore(seed: DiscoveryCandidateProfile, candidate: DiscoveryCandidateProfile) -> Double {
        let contrast = normalizedDifference(seed.metrics.medianIncome, candidate.metrics.medianIncome, floor: 10_000)
            + normalizedDifference(seed.metrics.medianAge, candidate.metrics.medianAge, floor: 2)
            + normalizedDifference(seed.demographics.ownerOccupiedPct, candidate.demographics.ownerOccupiedPct, floor: 4)
        let povertyGuard = max(0, 18 - (candidate.demographics.povertyRatePct ?? 18)) / 6
        return contrast + povertyGuard
    }

    private static func highlightChips(seed: DiscoveryCandidateProfile, candidate: DiscoveryCandidateProfile) -> [String] {
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

    private static func normalizedDifference<T: BinaryInteger>(_ lhs: T?, _ rhs: T?, floor: Double) -> Double {
        guard let lhs, let rhs else { return 0 }
        return abs(Double(Int(lhs) - Int(rhs))) / floor
    }

    private static func normalizedDifference(_ lhs: Double?, _ rhs: Double?, floor: Double) -> Double {
        guard let lhs, let rhs else { return 0 }
        return abs(lhs - rhs) / floor
    }
}
