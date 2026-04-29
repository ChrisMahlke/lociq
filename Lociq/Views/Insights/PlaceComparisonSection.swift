import SwiftUI

struct PlaceComparisonSection: View {
    let primary: ComparablePlaceProfile
    let secondary: ComparablePlaceProfile?
    let pendingSecondaryTitle: String?
    let isLoadingSecondary: Bool
    let comparisonErrorMessage: String?
    let boundaryScale: BoundaryOverlayScale
    let onReplaceComparison: () -> Void
    let onClearComparison: () -> Void
    let isComparisonSaved: Bool
    let onSaveComparison: () -> Void
    let shareAsset: ComparisonShareCardAsset?

    private let primaryTint: Color = .blue
    private let secondaryTint: Color = .orange

    private var presentation: PlaceComparisonPresentation {
        PlaceComparisonInsightsBuilder.make(primary: primary, secondary: secondary)
    }

    private var scaleDetail: String {
        switch boundaryScale {
        case .zip:
            return AppStrings.Labels.compareZipDetail
        case .tract:
            return AppStrings.Labels.compareTractDetail
        }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                comparisonHeader
                comparisonSummary
                comparisonHighlights

                if let comparisonErrorMessage {
                    ComparisonErrorBanner(message: comparisonErrorMessage)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(spacing: 10) {
                            ForEach(presentation.metricRows) { row in
                                ComparisonMetricRow(
                                    row: row,
                                    primaryTint: primaryTint,
                                    secondaryTint: secondaryTint,
                                    isSecondaryLoading: isLoadingSecondary && secondary == nil
                                )
                            }
                        }

                        if !presentation.callouts.isEmpty {
                            comparisonCallouts
                        }
                    }
                }
            }
        }
    }

    private var comparisonHighlights: some View {
        Group {
            if let summary = presentation.summary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppStrings.Labels.compareHighlightsTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.9)
                )
            }
        }
    }

    private var comparisonCallouts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppStrings.Labels.compareWhyDiffersTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(presentation.callouts) { callout in
                    ComparisonCalloutCard(callout: callout)
                }
            }
        }
    }

    private var comparisonHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                comparisonHeaderCopy
                Spacer(minLength: 0)
                comparisonHeaderActions
            }

            VStack(alignment: .leading, spacing: 12) {
                comparisonHeaderCopy
                comparisonHeaderActions
            }
        }
    }

    private var comparisonHeaderCopy: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(AppStrings.Labels.compareModeTitle)
                .font(.headline)
            Text(scaleDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var comparisonHeaderActions: some View {
        HStack(spacing: 8) {
            Button(action: onReplaceComparison) {
                Label(AppStrings.Labels.compareReplace, systemImage: "magnifyingglass")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("compare.replace")

            Button(action: onSaveComparison) {
                Image(systemName: isComparisonSaved ? "bookmark.fill" : "bookmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.orange)
                    .frame(width: 34, height: 34)
                    .background(Color.orange.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("compare.save")
            .accessibilityLabel(isComparisonSaved ? AppStrings.Labels.removeSavedComparison : AppStrings.Labels.saveComparison)

            if let shareAsset {
                ShareLink(
                    item: shareAsset,
                    subject: Text(AppStrings.Labels.compareModeTitle),
                    preview: SharePreview(shareAsset.title, image: shareAsset.previewImage)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.orange)
                        .frame(width: 34, height: 34)
                        .background(Color.orange.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("compare.share")
                .accessibilityLabel(AppStrings.Labels.comparisonShare)
            }

            Button(action: onClearComparison) {
                Image(systemName: "xmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("compare.clear")
            .accessibilityLabel(AppStrings.Labels.compareDone)
        }
    }

    private var comparisonSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                primarySummaryCard
                ComparisonVersusBadge()
                secondarySummaryCard
            }

            VStack(spacing: 10) {
                primarySummaryCard
                ComparisonVersusBadge()
                secondarySummaryCard
            }
        }
    }

    private var primarySummaryCard: some View {
        ComparisonPlaceCard(
            title: primary.title,
            subtitle: primary.subtitle,
            sourceText: InsightsFormatting.dataSourceText(primary.metricsSource),
            tint: primaryTint
        )
    }

    private var secondarySummaryCard: some View {
        ComparisonPlaceCard(
            title: secondary?.title ?? pendingSecondaryTitle ?? AppStrings.Labels.compareLoadingTitle,
            subtitle: secondary?.subtitle ?? "",
            sourceText: secondary.map { InsightsFormatting.dataSourceText($0.metricsSource) },
            tint: secondaryTint,
            isLoading: isLoadingSecondary && secondary == nil
        )
    }
}

struct CollapsedComparisonPreviewCard: View {
    let primaryTitle: String
    let secondaryTitle: String?
    let isLoadingSecondary: Bool
    let boundaryScale: BoundaryOverlayScale

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.split.2x1.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.indigo)
                .frame(width: 28, height: 28)
                .background(Color.indigo.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(AppStrings.Labels.compareModeTitle)
                    .font(.subheadline.weight(.semibold))
                Text(summaryLine)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Text(boundaryScale.displayTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(boundaryScale.themeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(boundaryScale.themeColor.opacity(0.12), in: Capsule())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.indigo.opacity(0.14), lineWidth: 0.9)
        )
    }

    private var summaryLine: String {
        if isLoadingSecondary {
            return AppStrings.Formats.compareLoadingInline(primaryTitle)
        }

        return "\(primaryTitle) \(AppStrings.Labels.compareVersus) \(secondaryTitle ?? AppStrings.Labels.compareLoadingTitle)"
    }
}

private struct ComparisonPlaceCard: View {
    let title: String
    let subtitle: String
    let sourceText: String?
    let tint: Color
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 10, height: 10)

                if let sourceText {
                    Text(sourceText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tint)
                }
            }

            if isLoading {
                ProgressView()
                    .tint(tint)
                    .padding(.vertical, 6)
            } else {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(14)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.16), Color(.secondarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct ComparisonMetricRow: View {
    let row: ComparisonMetricPresentation
    let primaryTint: Color
    let secondaryTint: Color
    let isSecondaryLoading: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                ComparisonValuePill(
                    value: row.primaryValue,
                    tint: primaryTint,
                    alignment: .leading,
                    isLeading: row.leadingSide == .primary
                )

                VStack(spacing: 3) {
                    Text(row.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let deltaText = row.deltaText, !isSecondaryLoading {
                        Text(deltaText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(deltaColor)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(width: 108)

                secondaryValueView(alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 8) {
                rowLabelStack

                HStack(spacing: 10) {
                    ComparisonValuePill(
                        value: row.primaryValue,
                        tint: primaryTint,
                        alignment: .center,
                        isLeading: row.leadingSide == .primary
                    )

                    secondaryValueView(alignment: .center)
                }
            }
        }
    }

    private var rowLabelStack: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(row.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let deltaText = row.deltaText, !isSecondaryLoading {
                Text(deltaText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(deltaColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var deltaColor: Color {
        switch row.leadingSide {
        case .primary:
            return primaryTint
        case .secondary:
            return secondaryTint
        case .tied:
            return .secondary
        }
    }

    @ViewBuilder
    private func secondaryValueView(alignment: Alignment) -> some View {
        if isSecondaryLoading {
            HStack {
                Spacer(minLength: 0)
                ProgressView()
                    .scaleEffect(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        } else {
            ComparisonValuePill(
                value: row.secondaryValue ?? AppStrings.Symbols.emDash,
                tint: secondaryTint,
                alignment: alignment,
                isLeading: row.leadingSide == .secondary
            )
        }
    }
}

private struct ComparisonValuePill: View {
    let value: String
    let tint: Color
    let alignment: Alignment
    var isLeading: Bool = false

    var body: some View {
        Text(value)
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: alignment)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(tint.opacity(isLeading ? 0.22 : 0.14))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(isLeading ? 0.34 : 0.2), lineWidth: isLeading ? 1.1 : 0.9)
            )
    }
}

private struct ComparisonVersusBadge: View {
    var body: some View {
        Text(AppStrings.Labels.compareVersus)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
    }
}

private struct ComparisonErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.orange)
                .frame(width: 28, height: 28)
                .background(Color.orange.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(AppStrings.Labels.compareUnavailableTitle)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.16), lineWidth: 0.9)
        )
    }
}

private struct ComparisonCalloutCard: View {
    let callout: ComparisonNarrativeCallout

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: callout.systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(callout.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(callout.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 0.9)
        )
    }

    private var tint: Color {
        switch callout.tone {
        case .neutral:
            return .indigo
        case .positive:
            return .green
        case .caution:
            return .orange
        }
    }
}
