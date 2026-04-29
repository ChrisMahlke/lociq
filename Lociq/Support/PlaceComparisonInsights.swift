import Foundation

enum ComparisonLeadingSide: Equatable {
    case primary
    case secondary
    case tied
}

enum ComparisonCalloutTone: Equatable {
    case neutral
    case positive
    case caution
}

struct ComparisonMetricPresentation: Identifiable, Equatable {
    let id: String
    let label: String
    let primaryValue: String
    let secondaryValue: String?
    let deltaText: String?
    let leadingSide: ComparisonLeadingSide
}

struct ComparisonNarrativeCallout: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let tone: ComparisonCalloutTone
}

struct PlaceComparisonPresentation: Equatable {
    let summary: String?
    let metricRows: [ComparisonMetricPresentation]
    let callouts: [ComparisonNarrativeCallout]
}

enum PlaceComparisonInsightsBuilder {
    static func make(
        primary: ComparablePlaceProfile,
        secondary: ComparablePlaceProfile?
    ) -> PlaceComparisonPresentation {
        guard let secondary else {
            return PlaceComparisonPresentation(
                summary: nil,
                metricRows: metricRows(primary: primary, secondary: nil),
                callouts: []
            )
        }

        let signals = buildSignals(primary: primary, secondary: secondary)
        let summary = makeSummary(from: signals)

        return PlaceComparisonPresentation(
            summary: summary,
            metricRows: metricRows(primary: primary, secondary: secondary),
            callouts: Array(signals.prefix(3)).map(\.callout)
        )
    }

    private static func metricRows(
        primary: ComparablePlaceProfile,
        secondary: ComparablePlaceProfile?
    ) -> [ComparisonMetricPresentation] {
        [
            makeIntRow(
                label: AppStrings.Metrics.population,
                primaryName: primary.title,
                secondaryName: secondary?.title,
                primaryValue: primary.metrics.population,
                secondaryValue: secondary?.metrics.population,
                formatter: InsightsFormatting.number
            ),
            makeIntRow(
                label: AppStrings.Metrics.medianIncome,
                primaryName: primary.title,
                secondaryName: secondary?.title,
                primaryValue: primary.metrics.medianIncome,
                secondaryValue: secondary?.metrics.medianIncome,
                formatter: InsightsFormatting.currency
            ),
            makeDoubleRow(
                label: AppStrings.Metrics.medianAge,
                primaryName: primary.title,
                secondaryName: secondary?.title,
                primaryValue: primary.metrics.medianAge,
                secondaryValue: secondary?.metrics.medianAge,
                displayFormatter: formatAge,
                deltaFormatter: { String(format: AppStrings.Symbols.oneDecimalFormat, $0) + " yrs" }
            ),
            makeIntRow(
                label: AppStrings.Metrics.households,
                primaryName: primary.title,
                secondaryName: secondary?.title,
                primaryValue: primary.metrics.households,
                secondaryValue: secondary?.metrics.households,
                formatter: InsightsFormatting.number
            ),
            makeIntRow(
                label: AppStrings.Labels.compareHomeValue,
                primaryName: primary.title,
                secondaryName: secondary?.title,
                primaryValue: primary.demographics?.medianHomeValue,
                secondaryValue: secondary?.demographics?.medianHomeValue,
                formatter: InsightsFormatting.currency
            ),
            makeIntRow(
                label: AppStrings.Labels.compareRent,
                primaryName: primary.title,
                secondaryName: secondary?.title,
                primaryValue: primary.demographics?.medianGrossRent,
                secondaryValue: secondary?.demographics?.medianGrossRent,
                formatter: InsightsFormatting.currency
            ),
            makeDoubleRow(
                label: AppStrings.Labels.compareHomeownership,
                primaryName: primary.title,
                secondaryName: secondary?.title,
                primaryValue: primary.demographics?.ownerOccupiedPct,
                secondaryValue: secondary?.demographics?.ownerOccupiedPct,
                displayFormatter: { InsightsFormatting.percent($0, suffixCount: nil) },
                deltaFormatter: { String(format: AppStrings.Symbols.oneDecimalFormat, $0) + " pts" }
            ),
            makeDoubleRow(
                label: AppStrings.Labels.remoteWork,
                primaryName: primary.title,
                secondaryName: secondary?.title,
                primaryValue: primary.demographics?.workersWfhPct,
                secondaryValue: secondary?.demographics?.workersWfhPct,
                displayFormatter: { InsightsFormatting.percent($0, suffixCount: nil) },
                deltaFormatter: { String(format: AppStrings.Symbols.oneDecimalFormat, $0) + " pts" }
            ),
            makeDoubleRow(
                label: AppStrings.Labels.poverty,
                primaryName: primary.title,
                secondaryName: secondary?.title,
                primaryValue: primary.demographics?.povertyRatePct,
                secondaryValue: secondary?.demographics?.povertyRatePct,
                displayFormatter: { InsightsFormatting.percent($0, suffixCount: nil) },
                deltaFormatter: { String(format: AppStrings.Symbols.oneDecimalFormat, $0) + " pts" }
            )
        ]
    }

    private static func makeIntRow(
        label: String,
        primaryName: String,
        secondaryName: String?,
        primaryValue: Int?,
        secondaryValue: Int?,
        formatter: (Int?) -> String
    ) -> ComparisonMetricPresentation {
        ComparisonMetricPresentation(
            id: label,
            label: label,
            primaryValue: formatter(primaryValue),
            secondaryValue: secondaryValue.map { formatter($0) },
            deltaText: deltaText(
                primaryName: primaryName,
                secondaryName: secondaryName,
                primaryValue: primaryValue.map(Double.init),
                secondaryValue: secondaryValue.map(Double.init),
                tolerance: 0.5,
                valueFormatter: { formatter(Int($0.rounded())) }
            ),
            leadingSide: leadingSide(
                primary: primaryValue.map(Double.init),
                secondary: secondaryValue.map(Double.init),
                tolerance: 0.5
            )
        )
    }

    private static func makeDoubleRow(
        label: String,
        primaryName: String,
        secondaryName: String?,
        primaryValue: Double?,
        secondaryValue: Double?,
        displayFormatter: (Double?) -> String,
        deltaFormatter: (Double) -> String
    ) -> ComparisonMetricPresentation {
        ComparisonMetricPresentation(
            id: label,
            label: label,
            primaryValue: displayFormatter(primaryValue),
            secondaryValue: secondaryValue.map { displayFormatter($0) },
            deltaText: deltaText(
                primaryName: primaryName,
                secondaryName: secondaryName,
                primaryValue: primaryValue,
                secondaryValue: secondaryValue,
                tolerance: 0.05,
                valueFormatter: deltaFormatter
            ),
            leadingSide: leadingSide(
                primary: primaryValue,
                secondary: secondaryValue,
                tolerance: 0.05
            )
        )
    }

    private static func deltaText(
        primaryName: String,
        secondaryName: String?,
        primaryValue: Double?,
        secondaryValue: Double?,
        tolerance: Double,
        valueFormatter: (Double) -> String
    ) -> String? {
        guard let secondaryName, let primaryValue, let secondaryValue else { return nil }
        let delta = primaryValue - secondaryValue
        if abs(delta) <= tolerance {
            return AppStrings.Labels.compareNearlySame
        }

        let leader = delta > 0 ? primaryName : secondaryName
        return AppStrings.Formats.compareLeadsBy(leader, valueFormatter(abs(delta)))
    }

    private static func leadingSide(
        primary: Double?,
        secondary: Double?,
        tolerance: Double
    ) -> ComparisonLeadingSide {
        guard let primary, let secondary else { return .tied }
        if abs(primary - secondary) <= tolerance {
            return .tied
        }
        return primary > secondary ? .primary : .secondary
    }

    private static func buildSignals(
        primary: ComparablePlaceProfile,
        secondary: ComparablePlaceProfile
    ) -> [ComparisonSignal] {
        [
            buildAffordabilitySignal(primary: primary, secondary: secondary),
            buildHomeownershipSignal(primary: primary, secondary: secondary),
            buildWorkPatternSignal(primary: primary, secondary: secondary),
            buildPovertySignal(primary: primary, secondary: secondary),
            buildAgeSignal(primary: primary, secondary: secondary)
        ]
        .compactMap { $0 }
        .sorted { lhs, rhs in
            if lhs.importance == rhs.importance {
                return lhs.callout.title < rhs.callout.title
            }
            return lhs.importance > rhs.importance
        }
    }

    private static func buildAffordabilitySignal(
        primary: ComparablePlaceProfile,
        secondary: ComparablePlaceProfile
    ) -> ComparisonSignal? {
        let incomeLead = metricLead(
            label: AppStrings.Metrics.medianIncome.lowercased(),
            primaryName: primary.title,
            secondaryName: secondary.title,
            primaryValue: primary.metrics.medianIncome.map(Double.init),
            secondaryValue: secondary.metrics.medianIncome.map(Double.init),
            threshold: 10_000
        )
        let homeValueLead = metricLead(
            label: AppStrings.Labels.compareHomeValue.lowercased(),
            primaryName: primary.title,
            secondaryName: secondary.title,
            primaryValue: intToDouble(primary.demographics?.medianHomeValue),
            secondaryValue: intToDouble(secondary.demographics?.medianHomeValue),
            threshold: 50_000
        )
        let rentLead = metricLead(
            label: AppStrings.Labels.compareRent.lowercased(),
            primaryName: primary.title,
            secondaryName: secondary.title,
            primaryValue: intToDouble(primary.demographics?.medianGrossRent),
            secondaryValue: intToDouble(secondary.demographics?.medianGrossRent),
            threshold: 150
        )

        let components = [incomeLead, homeValueLead, rentLead].compactMap { $0 }
        guard let strongest = components.max(by: { $0.importance < $1.importance }) else { return nil }

        let primaryDrivers = components.filter { $0.leader == strongest.leader }
        let orderedDrivers = Array(primaryDrivers.sorted { $0.importance > $1.importance }.prefix(2))

        let detail: String
        if orderedDrivers.count >= 2 {
            detail = AppStrings.Formats.compareAffordabilityDetail(
                strongest.leader,
                orderedDrivers[0].label,
                orderedDrivers[1].label
            )
        } else {
            detail = AppStrings.Formats.compareSingleDriverDetail(strongest.leader, strongest.label)
        }

        return ComparisonSignal(
            importance: strongest.importance + (orderedDrivers.count > 1 ? orderedDrivers[1].importance * 0.25 : 0),
            summaryPhrase: AppStrings.Labels.compareAffordabilitySummaryPhrase,
            leader: strongest.leader,
            callout: ComparisonNarrativeCallout(
                id: "affordability",
                title: AppStrings.Labels.compareAffordabilityCalloutTitle,
                detail: detail,
                systemImage: "house.and.flag.fill",
                tone: .neutral
            )
        )
    }

    private static func buildHomeownershipSignal(
        primary: ComparablePlaceProfile,
        secondary: ComparablePlaceProfile
    ) -> ComparisonSignal? {
        guard
            let primaryValue = primary.demographics?.ownerOccupiedPct,
            let secondaryValue = secondary.demographics?.ownerOccupiedPct,
            abs(primaryValue - secondaryValue) >= 4
        else {
            return nil
        }

        let leader = primaryValue > secondaryValue ? primary.title : secondary.title
        let leaderValue = primaryValue > secondaryValue ? primaryValue : secondaryValue
        let otherValue = primaryValue > secondaryValue ? secondaryValue : primaryValue

        return ComparisonSignal(
            importance: abs(primaryValue - secondaryValue) / 8,
            summaryPhrase: AppStrings.Labels.compareHomeownershipSummaryPhrase,
            leader: leader,
            callout: ComparisonNarrativeCallout(
                id: "homeownership",
                title: AppStrings.Labels.compareHomeownershipCalloutTitle,
                detail: AppStrings.Formats.compareHomeownershipDetail(
                    leader,
                    InsightsFormatting.percent(leaderValue, suffixCount: nil),
                    InsightsFormatting.percent(otherValue, suffixCount: nil)
                ),
                systemImage: "key.fill",
                tone: .neutral
            )
        )
    }

    private static func buildWorkPatternSignal(
        primary: ComparablePlaceProfile,
        secondary: ComparablePlaceProfile
    ) -> ComparisonSignal? {
        guard
            let primaryValue = primary.demographics?.workersWfhPct,
            let secondaryValue = secondary.demographics?.workersWfhPct,
            abs(primaryValue - secondaryValue) >= 2
        else {
            return nil
        }

        let leader = primaryValue > secondaryValue ? primary.title : secondary.title
        let leaderValue = primaryValue > secondaryValue ? primaryValue : secondaryValue
        let otherValue = primaryValue > secondaryValue ? secondaryValue : primaryValue

        return ComparisonSignal(
            importance: abs(primaryValue - secondaryValue) / 4,
            summaryPhrase: AppStrings.Labels.compareWorkPatternSummaryPhrase,
            leader: leader,
            callout: ComparisonNarrativeCallout(
                id: "remote-work",
                title: AppStrings.Labels.compareWorkPatternCalloutTitle,
                detail: AppStrings.Formats.compareRemoteWorkDetail(
                    leader,
                    InsightsFormatting.percent(leaderValue, suffixCount: nil),
                    InsightsFormatting.percent(otherValue, suffixCount: nil)
                ),
                systemImage: "laptopcomputer",
                tone: .positive
            )
        )
    }

    private static func buildPovertySignal(
        primary: ComparablePlaceProfile,
        secondary: ComparablePlaceProfile
    ) -> ComparisonSignal? {
        guard
            let primaryValue = primary.demographics?.povertyRatePct,
            let secondaryValue = secondary.demographics?.povertyRatePct,
            abs(primaryValue - secondaryValue) >= 1.5
        else {
            return nil
        }

        let higherPlace = primaryValue > secondaryValue ? primary.title : secondary.title
        let higherValue = max(primaryValue, secondaryValue)
        let lowerValue = min(primaryValue, secondaryValue)

        return ComparisonSignal(
            importance: abs(primaryValue - secondaryValue) / 3,
            summaryPhrase: AppStrings.Labels.comparePovertySummaryPhrase,
            leader: higherPlace,
            callout: ComparisonNarrativeCallout(
                id: "poverty",
                title: AppStrings.Labels.comparePovertyCalloutTitle,
                detail: AppStrings.Formats.comparePovertyDetail(
                    higherPlace,
                    InsightsFormatting.percent(higherValue, suffixCount: nil),
                    InsightsFormatting.percent(lowerValue, suffixCount: nil)
                ),
                systemImage: "exclamationmark.triangle.fill",
                tone: .caution
            )
        )
    }

    private static func buildAgeSignal(
        primary: ComparablePlaceProfile,
        secondary: ComparablePlaceProfile
    ) -> ComparisonSignal? {
        guard
            let primaryValue = primary.metrics.medianAge,
            let secondaryValue = secondary.metrics.medianAge,
            abs(primaryValue - secondaryValue) >= 1.5
        else {
            return nil
        }

        let olderPlace = primaryValue > secondaryValue ? primary.title : secondary.title
        let olderValue = max(primaryValue, secondaryValue)
        let youngerValue = min(primaryValue, secondaryValue)

        return ComparisonSignal(
            importance: abs(primaryValue - secondaryValue) / 2.5,
            summaryPhrase: AppStrings.Labels.compareAgeSummaryPhrase,
            leader: olderPlace,
            callout: ComparisonNarrativeCallout(
                id: "age",
                title: AppStrings.Labels.compareAgeCalloutTitle,
                detail: AppStrings.Formats.compareAgeDetail(
                    olderPlace,
                    formatAge(olderValue),
                    formatAge(youngerValue)
                ),
                systemImage: "hourglass",
                tone: .neutral
            )
        )
    }

    private static func makeSummary(from signals: [ComparisonSignal]) -> String? {
        guard !signals.isEmpty else {
            return AppStrings.Labels.compareSimilarProfiles
        }

        let topSignals = Array(signals.prefix(3))
        let topLeader = topSignals.first?.leader ?? ""
        let allFavorSamePlace = topSignals.allSatisfy { $0.leader == topLeader }
        let details = joinPhrases(topSignals.map(\.summaryPhrase))

        if allFavorSamePlace {
            return AppStrings.Formats.compareSummaryFavoring(topLeader, details)
        }
        return AppStrings.Formats.compareSummaryMixed(details)
    }

    private static func joinPhrases(_ phrases: [String]) -> String {
        switch phrases.count {
        case 0:
            return ""
        case 1:
            return phrases[0]
        case 2:
            return "\(phrases[0]) and \(phrases[1])"
        default:
            let head = phrases.dropLast().joined(separator: ", ")
            return "\(head), and \(phrases.last ?? "")"
        }
    }

    private static func metricLead(
        label: String,
        primaryName: String,
        secondaryName: String,
        primaryValue: Double?,
        secondaryValue: Double?,
        threshold: Double
    ) -> MetricLead? {
        guard let primaryValue, let secondaryValue else { return nil }
        let delta = primaryValue - secondaryValue
        guard abs(delta) >= threshold else { return nil }

        return MetricLead(
            label: label,
            leader: delta > 0 ? primaryName : secondaryName,
            importance: abs(delta) / threshold
        )
    }

    private static func formatAge(_ value: Double?) -> String {
        guard let value else { return AppStrings.Symbols.emDash }
        return String(format: AppStrings.Symbols.oneDecimalFormat, value)
    }

    private static func intToDouble(_ value: Int?) -> Double? {
        value.map(Double.init)
    }
}

private struct ComparisonSignal {
    let importance: Double
    let summaryPhrase: String
    let leader: String
    let callout: ComparisonNarrativeCallout
}

private struct MetricLead {
    let label: String
    let leader: String
    let importance: Double
}
