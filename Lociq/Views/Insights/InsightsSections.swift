import SwiftUI

struct CollapsedInsightsHeaderRow: View {
    let zipLine: String
    @Binding var boundaryScale: BoundaryOverlayScale
    let hintVisible: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(zipLine)
                    .font(.headline).bold()
                Text(AppStrings.Labels.collapsedHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("ZIP shows the broader area. Tract shows more local detail.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
    let zipCode: String?
    let metricsSource: MetricsSource?
    @Binding var boundaryScale: BoundaryOverlayScale

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(zipCode ?? AppStrings.Symbols.emDash).font(.title2).bold()
                Text(AppStrings.Labels.profileSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Use ZIP for the broader area or Tract for more local detail.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            BoundaryScaleIconToggle(scale: $boundaryScale)
            if let src = metricsSource {
                Text(InsightsFormatting.dataSourceText(src))
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    .foregroundColor(.accentColor)
            }
        }
    }
}

struct HousingAffordabilitySection: View {
    let demographics: Demographics
    let themeTint: Color

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(AppStrings.Labels.housingAffordabilityTitle).font(.headline)

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

struct WorkAndHouseholdSection: View {
    let demographics: Demographics
    let themeTint: Color

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(AppStrings.Labels.workAndHouseholdSnapshot).font(.headline)

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
            VStack(alignment: .leading, spacing: 12) {
                Text(AppStrings.Labels.demographicCompositionVisual).font(.headline)

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
            VStack(alignment: .leading, spacing: 6) {
                Text(AppStrings.Labels.insights)
                    .font(.headline)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .minimumScaleFactor(0.9)
                    .clipped()
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
