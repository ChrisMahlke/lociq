import SwiftUI

struct CollapsedInsightsHeaderRow: View {
    let areaTitle: String
    let areaSubtitle: String
    let zipLine: String
    @Binding var boundaryScale: BoundaryOverlayScale
    let hintVisible: Bool
    let hasActiveSelection: Bool

    private var contextItems: [String] {
        if hasActiveSelection {
            return areaSubtitle
                .split(separator: "·")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        return ["Tap the map", "Expand for more"]
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(hasActiveSelection ? areaTitle : AppStrings.Labels.noSelectionTitle)
                    .font(.headline)
                    .bold()
                    .foregroundStyle(.primary)
                Text(hasActiveSelection ? AppStrings.Labels.neighborhoodProfile : AppStrings.Labels.collapsedHint)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.72))
                ContextPillRow(items: contextItems, tint: hasActiveSelection ? boundaryScale.themeColor : .blue)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                BoundaryScaleIconToggle(scale: $boundaryScale)
                SwipeUpHint()
                    .opacity(hintVisible ? 1 : 0)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.25), value: hintVisible)
            }
        }
    }
}

struct CollapsedInsightsMetricsGrid: View {
    let metrics: CensusMetrics?

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            CollapsedMetricChip(
                icon: IconNames.personFilled,
                label: AppStrings.Metrics.population,
                value: InsightsFormatting.number(metrics?.population),
                loading: metrics == nil
            )
            CollapsedMetricChip(
                icon: IconNames.money,
                label: AppStrings.Metrics.medianIncome,
                value: metrics?.medianIncome.map { InsightsFormatting.currency($0) },
                loading: metrics == nil
            )
            CollapsedMetricChip(
                icon: IconNames.clock,
                label: AppStrings.Metrics.medianAge,
                value: metrics?.medianAge.map { String(format: AppStrings.Symbols.oneDecimalFormat, $0) },
                loading: metrics == nil
            )
            CollapsedMetricChip(
                icon: IconNames.house,
                label: AppStrings.Metrics.households,
                value: InsightsFormatting.number(metrics?.households),
                loading: metrics == nil
            )
        }
    }
}

struct ExpandedInsightsHeaderRow: View {
    let areaTitle: String
    let areaSubtitle: String
    let zipCode: String?
    let metricsSource: MetricsSource?
    @Binding var boundaryScale: BoundaryOverlayScale

    private var contextItems: [String] {
        let base = areaSubtitle.isEmpty ? (zipCode.map { ["ZIP \($0)"] } ?? []) : areaSubtitle
            .split(separator: "·")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let src = metricsSource {
            return base + [InsightsFormatting.dataSourceText(src)]
        }

        return base
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(areaTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(AppStrings.Labels.profileSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.72))
                }

                Spacer()
            }

            ContextPillRow(items: contextItems, tint: boundaryScale.themeColor)
            ScaleStatusBanner(boundaryScale: $boundaryScale)
        }
    }
}

struct HousingAffordabilitySection: View {
    let demographics: Demographics
    let themeTint: Color

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                InsightSectionHeader(
                    title: AppStrings.Labels.housingAffordabilityTitle,
                    subtitle: "Home prices, rent, and how occupancy is split",
                    icon: "house.and.flag.fill",
                    tint: themeTint
                )

                HStack(spacing: 10) {
                    InfographicBadge(
                        icon: IconNames.houseFilled,
                        title: AppStrings.Labels.homeValue,
                        value: InsightsFormatting.currency(demographics.medianHomeValue),
                        tint: themeTint
                    )

                    InfographicBadge(
                        icon: IconNames.keyFilled,
                        title: AppStrings.Labels.grossRent,
                        value: InsightsFormatting.currency(demographics.medianGrossRent),
                        tint: themeTint.opacity(0.78)
                    )
                }

                OccupancySplitBar(
                    ownerText: InsightsFormatting.percent(demographics.ownerOccupiedPct, suffixCount: demographics.ownerOccupied),
                    renterText: InsightsFormatting.percent(demographics.renterOccupiedPct, suffixCount: demographics.renterOccupied),
                    ownerShare: InsightsFormatting.normalizedPercent(demographics.ownerOccupiedPct)
                )
            }
        }
    }
}

struct QuickSignalsSection: View {
    let demographics: Demographics
    let themeTint: Color

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                InsightSectionHeader(
                    title: AppStrings.Labels.quickSignals,
                    subtitle: "Fast read on work patterns and economic pressure",
                    icon: "waveform.path.ecg.rectangle.fill",
                    tint: themeTint
                )

                HStack(spacing: 10) {
                    MiniRingStat(
                        label: AppStrings.Labels.remoteWork,
                        value: InsightsFormatting.percent(demographics.workersWfhPct, suffixCount: demographics.workersWfh),
                        progress: InsightsFormatting.normalizedPercent(demographics.workersWfhPct),
                        tint: themeTint
                    )

                    MiniRingStat(
                        label: AppStrings.Labels.poverty,
                        value: InsightsFormatting.percent(demographics.povertyRatePct, suffixCount: demographics.povertyBelow),
                        progress: InsightsFormatting.normalizedPercent(demographics.povertyRatePct),
                        tint: themeTint.opacity(0.72)
                    )
                }
            }
        }
    }
}

struct DemographicCompositionSection: View {
    let demographics: Demographics
    let totalPopulation: Int?
    let themeTint: Color

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                InsightSectionHeader(
                    title: AppStrings.Labels.demographicCompositionVisual,
                    subtitle: "Relative group sizes within the selected geography",
                    icon: "person.3.sequence.fill",
                    tint: themeTint
                )

                CompositionRow(
                    label: AppStrings.Labels.white,
                    countText: InsightsFormatting.number(demographics.whiteAlone),
                    progress: InsightsFormatting.demographicShare(demographics.whiteAlone, totalPopulation: totalPopulation),
                    tint: themeTint
                )
                CompositionRow(
                    label: AppStrings.Labels.black,
                    countText: InsightsFormatting.number(demographics.blackAlone),
                    progress: InsightsFormatting.demographicShare(demographics.blackAlone, totalPopulation: totalPopulation),
                    tint: themeTint.opacity(0.84)
                )
                CompositionRow(
                    label: AppStrings.Labels.asian,
                    countText: InsightsFormatting.number(demographics.asianAlone),
                    progress: InsightsFormatting.demographicShare(demographics.asianAlone, totalPopulation: totalPopulation),
                    tint: themeTint.opacity(0.70)
                )
                CompositionRow(
                    label: AppStrings.Labels.hispanicLatino,
                    countText: InsightsFormatting.number(demographics.hispanicOrLatino),
                    progress: InsightsFormatting.demographicShare(demographics.hispanicOrLatino, totalPopulation: totalPopulation),
                    tint: themeTint.opacity(0.58)
                )
            }
        }
    }
}

struct GeneratedInsightsSection: View {
    let insights: [Insight]
    let isLoading: Bool

    private var visibleInsights: [Insight] {
        insights.filter { $0.title != "Housing snapshot" }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                InsightSectionHeader(
                    title: AppStrings.Labels.insights,
                    subtitle: "Plain-English takeaways generated from the active profile",
                    icon: "text.bubble.fill",
                    tint: .indigo
                )
                if isLoading {
                    InsightLoadingPanel()
                } else if visibleInsights.isEmpty {
                    Text(AppStrings.Labels.noGeneratedInsights)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.8)
                        .clipped()
                } else {
                    InsightRedesignPanel(insights: visibleInsights)
                }
            }
        }
    }
}
