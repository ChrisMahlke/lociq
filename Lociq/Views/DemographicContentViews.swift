import SwiftUI

struct HeaderBlock: View {
    let snapshot: DemographicSnapshot
    let layout: MinimalLayout

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(snapshot.market)
                .font(.system(size: layout.cityFontSize, weight: .light, design: .rounded))
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
                    .font(.system(size: 13, weight: .medium, design: .rounded))
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
                    .opacity(0.9)
                    .offset(y: reduceMotion ? 0 : (layout.isShortHeight ? -2 : 2))
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
            insertion: .opacity.combined(with: .move(edge: .trailing)),
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
                .font(.system(size: layout.metricTitleSize, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))

            Text(metric.primaryValue)
                .font(.system(size: layout.metricValueSize, weight: .light, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)

            Text(metric.detail)
                .font(.system(size: layout.metricDetailSize, weight: .regular, design: .rounded))
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
        VStack(alignment: .trailing, spacing: layout.isShortHeight ? 14 : 18) {
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
        VStack(alignment: .trailing, spacing: 10) {
            Text(section.title)
                .font(.system(size: 13, weight: .ultraLight, design: .rounded))
                .foregroundStyle(.white.opacity(0.54))

            VStack(alignment: .trailing, spacing: 7) {
                ForEach(section.rows) { row in
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            DetailRowLabel(label: row.label, layout: layout)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .allowsTightening(true)
                                .padding(.leading, 2)
                                .layoutPriority(1)

                            Spacer(minLength: 10)

                            Text(row.value)
                                .font(.system(size: layout.detailValueSize, weight: .light, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
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
                                .opacity(0.78)
                                .frame(maxWidth: 220)
                        }
                    }
                    .padding(.vertical, 3)
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
            .foregroundStyle(.white.opacity(0.46))
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
                .font(.system(size: layout.detailLabelNumberSize - 0.5, weight: .regular, design: .rounded))
        }
    }

    private var space: Text {
        Text(" ")
            .font(.system(size: layout.detailLabelNumberSize - 0.5, weight: .regular, design: .rounded))
    }

    /// Formats the word portion of compound age labels.
    private func word(_ text: String) -> Text {
        Text(text)
            .font(.system(size: layout.detailLabelWordSize, weight: .regular, design: .rounded))
    }

    /// Formats the numeric portion of compound age labels.
    private func number(_ text: String) -> Text {
        Text(text)
            .font(.system(size: layout.detailLabelNumberSize, weight: .regular, design: .rounded))
    }
}
