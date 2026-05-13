//
//  DemographicContentViews.swift
//  Lociq
//
//  Renders the minimal city title, summary metrics, and detail rows.
//

import SwiftUI

private enum DemographicContentConstants {
    static let detailPanelOpacity = 0.88
    static let detailSectionTitleOpacity = 0.38
    static let detailLabelOpacity = 0.52
    static let detailValueOpacity = 0.88
    static let detailProgressOpacity = 0.48
}

struct HeaderBlock: View {
    let snapshot: DemographicSnapshot
    let layout: MinimalLayout

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(snapshot.market)
                .font(LociqTypeScale.city(layout))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.74)
                .allowsTightening(true)
                .anchorPreference(key: BoundaryCityConnectionPreferenceKey.self, value: .bounds) {
                    BoundaryCityConnectionAnchors(city: $0)
                }

            if !snapshot.dateLabel.isEmpty {
                Text(snapshot.dateLabel)
                    .font(LociqTypeScale.statusLabel(layout))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
        .multilineTextAlignment(.trailing)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("demographics.header")
    }
}

struct FadingContentPanel: View {
    let snapshot: DemographicSnapshot
    let isShowingDetails: Bool
    let layout: MinimalLayout
    let reduceMotion: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isShowingDetails {
                DetailContent(snapshot: snapshot, layout: layout)
                    .opacity(DemographicContentConstants.detailPanelOpacity)
                    .transition(contentTransition)
            } else {
                MetricContent(metrics: snapshot.metrics, layout: layout)
                    .transition(contentTransition)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topTrailing)
        .animation(LociqMotion.content(reduceMotion: reduceMotion), value: isShowingDetails)
    }

    private var contentTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .topTrailing)),
            removal: .opacity
        )
    }
}

private struct MetricContent: View {
    let metrics: [DemographicMetric]
    let layout: MinimalLayout

    var body: some View {
        VStack(alignment: .trailing, spacing: layout.isShortHeight ? 18 : 22) {
            ForEach(metrics) { metric in
                MetricBlock(metric: metric, layout: layout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct MetricBlock: View {
    let metric: DemographicMetric
    let layout: MinimalLayout

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(metric.title)
                .font(LociqTypeScale.metricLabel(layout))
                .foregroundStyle(.white.opacity(0.78))

            Text(metric.primaryValue)
                .font(LociqTypeScale.metricValue(layout))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)

            Text(metric.detail)
                .font(LociqTypeScale.metricDetail(layout))
                .foregroundStyle(.white.opacity(0.54))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DetailContent: View {
    let snapshot: DemographicSnapshot
    let layout: MinimalLayout

    var body: some View {
        VStack(alignment: .trailing, spacing: layout.detailSectionSpacing) {
            ForEach(snapshot.detailSections) { section in
                DetailSectionView(section: section, layout: layout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct DetailSectionView: View {
    let section: DemographicDetailSection
    let layout: MinimalLayout

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text(section.title)
                .font(LociqTypeScale.detailSectionLabel(layout))
                .foregroundStyle(.white.opacity(DemographicContentConstants.detailSectionTitleOpacity))

            VStack(alignment: .trailing, spacing: layout.detailRowSpacing) {
                ForEach(section.rows) { row in
                    VStack(alignment: .trailing, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            DetailRowLabel(label: row.label, layout: layout)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .allowsTightening(true)
                                .frame(width: layout.detailLabelColumnWidth, alignment: .leading)
                                .layoutPriority(1)

                            Spacer(minLength: 8)

                            Text(row.value)
                                .font(LociqTypeScale.detailValue(layout))
                                .foregroundStyle(.white.opacity(DemographicContentConstants.detailValueOpacity))
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)
                                .allowsTightening(true)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                        }
                        .frame(maxWidth: .infinity)
                        .monospacedDigit()

                        if let progress = row.progress {
                            ProgressLine(progress: progress)
                                .opacity(DemographicContentConstants.detailProgressOpacity)
                                .frame(maxWidth: max(64, layout.detailContentWidth - layout.detailLabelColumnWidth - 20))
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DetailRowLabel: View {
    let label: String
    let layout: MinimalLayout

    var body: some View {
        labelText
            .foregroundStyle(.white.opacity(DemographicContentConstants.detailLabelOpacity))
    }

    private var labelText: Text {
        switch label {
        case "UNDER 18":
            return word("UNDER") + space + number("18")
        case "18 TO 34":
            return number("18") + space + word("TO") + space + number("34")
        case "35 TO 64":
            return number("35") + space + word("TO") + space + number("64")
        case "65 PLUS":
            return number("65") + space + word("PLUS")
        default:
            return Text(label)
                .font(LociqTypeScale.detailLabel(layout))
        }
    }

    private var space: Text {
        Text(" ")
            .font(LociqTypeScale.detailLabel(layout))
    }

    /// Formats the word portion of compound age labels.
    private func word(_ text: String) -> Text {
        Text(text)
            .font(LociqTypeScale.detailLabelWord(layout))
    }

    /// Formats the numeric portion of compound age labels.
    private func number(_ text: String) -> Text {
        Text(text)
            .font(LociqTypeScale.detailLabelNumber(layout))
    }
}
