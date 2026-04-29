import Foundation

enum NeighborhoodShareSummaryFormatter {
    static func makeSummary(
        areaTitle: String,
        areaSubtitle: String,
        boundaryScale: BoundaryOverlayScale,
        metricsSource: MetricsSource?,
        metrics: CensusMetrics?,
        demographics: Demographics?,
        insights: [Insight]
    ) -> String {
        var lines: [String] = [AppStrings.Labels.neighborhoodProfile, areaTitle]

        if !areaSubtitle.isEmpty {
            lines.append(areaSubtitle)
        }

        lines.append("")
        lines.append("\(AppStrings.Labels.currentScale): \(boundaryScale.displayTitle)")

        if let metricsSource {
            lines.append(InsightsFormatting.dataSourceText(metricsSource))
        }

        appendMetric(
            label: AppStrings.Metrics.population,
            value: InsightsFormatting.number(metrics?.population ?? demographics?.population),
            to: &lines
        )
        appendMetric(
            label: AppStrings.Metrics.medianIncome,
            value: InsightsFormatting.currency(metrics?.medianIncome ?? demographics?.medianHouseholdIncome),
            to: &lines
        )
        appendMetric(
            label: AppStrings.Metrics.medianAge,
            value: formattedAge(metrics?.medianAge ?? demographics?.medianAge),
            to: &lines
        )
        appendMetric(
            label: AppStrings.Metrics.households,
            value: InsightsFormatting.number(metrics?.households),
            to: &lines
        )

        let visibleInsights = insights
            .filter { $0.category != .housing }
            .prefix(2)

        if !visibleInsights.isEmpty {
            lines.append("")
            lines.append(AppStrings.Labels.insights)

            for insight in visibleInsights {
                lines.append("• \(insight.title): \(insight.detail)")
            }
        }

        lines.append("")
        lines.append("\(AppStrings.Labels.latestACSDataset): \(AppStrings.Release.latestACS5YearDataset)")

        return lines.joined(separator: "\n")
    }

    private static func appendMetric(label: String, value: String, to lines: inout [String]) {
        guard value != AppStrings.Symbols.emDash else { return }
        lines.append("\(label): \(value)")
    }

    private static func formattedAge(_ value: Double?) -> String {
        guard let value else { return AppStrings.Symbols.emDash }
        return String(format: AppStrings.Symbols.oneDecimalFormat, value)
    }
}

enum ComparisonShareSummaryFormatter {
    static func makeSummary(
        title: String,
        boundaryScale: BoundaryOverlayScale,
        primary: ComparablePlaceProfile,
        secondary: ComparablePlaceProfile
    ) -> String {
        var lines: [String] = [
            AppStrings.Labels.compareModeTitle,
            title,
            "",
            "\(AppStrings.Labels.currentScale): \(boundaryScale.displayTitle)",
            ""
        ]

        appendMetric(
            label: AppStrings.Metrics.population,
            primaryValue: InsightsFormatting.number(primary.metrics.population),
            secondaryValue: InsightsFormatting.number(secondary.metrics.population),
            primaryTitle: primary.title,
            secondaryTitle: secondary.title,
            to: &lines
        )
        appendMetric(
            label: AppStrings.Metrics.medianIncome,
            primaryValue: InsightsFormatting.currency(primary.metrics.medianIncome),
            secondaryValue: InsightsFormatting.currency(secondary.metrics.medianIncome),
            primaryTitle: primary.title,
            secondaryTitle: secondary.title,
            to: &lines
        )
        appendMetric(
            label: AppStrings.Metrics.medianAge,
            primaryValue: formattedAge(primary.metrics.medianAge),
            secondaryValue: formattedAge(secondary.metrics.medianAge),
            primaryTitle: primary.title,
            secondaryTitle: secondary.title,
            to: &lines
        )
        appendMetric(
            label: AppStrings.Metrics.households,
            primaryValue: InsightsFormatting.number(primary.metrics.households),
            secondaryValue: InsightsFormatting.number(secondary.metrics.households),
            primaryTitle: primary.title,
            secondaryTitle: secondary.title,
            to: &lines
        )

        lines.append("")
        lines.append("\(AppStrings.Labels.latestACSDataset): \(AppStrings.Release.latestACS5YearDataset)")
        return lines.joined(separator: "\n")
    }

    private static func appendMetric(
        label: String,
        primaryValue: String,
        secondaryValue: String,
        primaryTitle: String,
        secondaryTitle: String,
        to lines: inout [String]
    ) {
        guard primaryValue != AppStrings.Symbols.emDash || secondaryValue != AppStrings.Symbols.emDash else {
            return
        }

        lines.append(label)
        lines.append("• \(primaryTitle): \(primaryValue)")
        lines.append("• \(secondaryTitle): \(secondaryValue)")
    }

    private static func formattedAge(_ value: Double?) -> String {
        guard let value else { return AppStrings.Symbols.emDash }
        return String(format: AppStrings.Symbols.oneDecimalFormat, value)
    }
}
