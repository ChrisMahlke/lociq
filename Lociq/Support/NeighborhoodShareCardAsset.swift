import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct NeighborhoodShareCardAsset: Transferable {
    let title: String
    let summary: String
    let imageData: Data

    var previewImage: Image {
        guard let uiImage = UIImage(data: imageData) else {
            return Image(systemName: "square.and.arrow.up")
        }

        return Image(uiImage: uiImage)
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { asset in
            let fileName = asset.title
                .lowercased()
                .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            let safeName = fileName.isEmpty ? "lociq-neighborhood-card" : "lociq-\(fileName)"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(safeName)-\(UUID().uuidString).png")

            try asset.imageData.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }

        ProxyRepresentation(exporting: \.summary)
    }
}

@MainActor
enum NeighborhoodShareCardExporter {
    static func makeAsset(
        areaTitle: String,
        areaSubtitle: String,
        boundaryScale: BoundaryOverlayScale,
        metricsSource: MetricsSource?,
        metrics: CensusMetrics?,
        demographics: Demographics?,
        insights: [Insight]
    ) -> NeighborhoodShareCardAsset? {
        let summary = NeighborhoodShareSummaryFormatter.makeSummary(
            areaTitle: areaTitle,
            areaSubtitle: areaSubtitle,
            boundaryScale: boundaryScale,
            metricsSource: metricsSource,
            metrics: metrics,
            demographics: demographics,
            insights: insights
        )

        let content = NeighborhoodShareCardView(
            areaTitle: areaTitle,
            areaSubtitle: areaSubtitle,
            boundaryScale: boundaryScale,
            metricsSource: metricsSource,
            metrics: metrics,
            demographics: demographics,
            insights: insights
        )
        .frame(width: 720)
        .preferredColorScheme(.light)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        renderer.isOpaque = false

        guard let uiImage = renderer.uiImage, let imageData = uiImage.pngData() else {
            return nil
        }

        return NeighborhoodShareCardAsset(
            title: areaTitle,
            summary: summary,
            imageData: imageData
        )
    }
}

private struct NeighborhoodShareCardView: View {
    let areaTitle: String
    let areaSubtitle: String
    let boundaryScale: BoundaryOverlayScale
    let metricsSource: MetricsSource?
    let metrics: CensusMetrics?
    let demographics: Demographics?
    let insights: [Insight]

    private var visibleInsights: [Insight] {
        Array(
            insights
                .filter { $0.category != .housing }
                .prefix(2)
        )
    }

    private var metricRows: [NeighborhoodShareMetricRow] {
        [
            NeighborhoodShareMetricRow(
                title: AppStrings.Metrics.population,
                value: InsightsFormatting.number(metrics?.population ?? demographics?.population),
                symbol: "person.2.fill"
            ),
            NeighborhoodShareMetricRow(
                title: AppStrings.Metrics.medianIncome,
                value: InsightsFormatting.currency(metrics?.medianIncome ?? demographics?.medianHouseholdIncome),
                symbol: "dollarsign.circle.fill"
            ),
            NeighborhoodShareMetricRow(
                title: AppStrings.Metrics.medianAge,
                value: formattedAge(metrics?.medianAge ?? demographics?.medianAge),
                symbol: "clock.fill"
            ),
            NeighborhoodShareMetricRow(
                title: AppStrings.Metrics.households,
                value: InsightsFormatting.number(metrics?.households),
                symbol: "house.fill"
            )
        ]
        .filter { $0.value != AppStrings.Symbols.emDash }
    }

    private var bannerColor: Color {
        boundaryScale.themeColor
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.98, blue: 1.0),
                    Color(red: 0.92, green: 0.97, blue: 0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(bannerColor.opacity(0.16))
                .frame(width: 320, height: 320)
                .offset(x: 230, y: -240)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(.white.opacity(0.75), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 24, y: 12)
                .padding(24)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(bannerColor.opacity(0.16))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: "location.magnifyingglass")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(bannerColor)
                                )

                            Text(AppStrings.Labels.appTitle)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }

                        Text(AppStrings.Labels.neighborhoodProfile)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 8) {
                        NeighborhoodSharePill(
                            text: boundaryScale.displayTitle,
                            tint: bannerColor
                        )

                        if let metricsSource {
                            NeighborhoodSharePill(
                                text: InsightsFormatting.dataSourceText(metricsSource),
                                tint: bannerColor.opacity(0.8)
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(areaTitle)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !areaSubtitle.isEmpty {
                        Text(areaSubtitle)
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !metricRows.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(metricRows) { row in
                            NeighborhoodShareMetricTile(row: row, tint: bannerColor)
                        }
                    }
                }

                if !visibleInsights.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppStrings.Labels.insights)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        ForEach(Array(visibleInsights.enumerated()), id: \.offset) { _, insight in
                            NeighborhoodShareInsightRow(insight: insight, tint: color(for: insight.category))
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    Text("\(AppStrings.Labels.latestACSDataset): \(AppStrings.Release.latestACS5YearDataset)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.8))

                    Text(AppStrings.More.officialPublicDataDetail)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(52)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 720, height: 920)
    }

    private func formattedAge(_ value: Double?) -> String {
        guard let value else { return AppStrings.Symbols.emDash }
        return String(format: AppStrings.Symbols.oneDecimalFormat, value)
    }

    private func color(for category: Insight.Category) -> Color {
        switch category {
        case .housing: return .blue
        case .affordability: return .orange
        case .mobility: return .mint
        case .demographics: return .purple
        case .governance: return .indigo
        case .geography: return .teal
        }
    }
}

private struct NeighborhoodShareMetricRow: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let symbol: String
}

private struct NeighborhoodShareMetricTile: View {
    let row: NeighborhoodShareMetricRow
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.14))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: row.symbol)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(tint)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(row.value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct NeighborhoodShareInsightRow: View {
    let insight: Insight
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(tint)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(insight.detail)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct NeighborhoodSharePill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
    }
}
