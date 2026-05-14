//
//  DetailContent.swift
//  Lociq
//
//  Renders the secondary demographic detail rows.
//
//  The details view keeps the same minimal vocabulary as the home view. It
//  groups values by section and uses quiet typography instead of adding charts
//  or explanatory panels.
//

import SwiftUI

/// Detail panel for the secondary demographic view.
struct DetailContent: View {
    /// Snapshot containing display-ready detail sections.
    let snapshot: DemographicSnapshot

    /// Layout metrics for spacing, column width, and typography.
    let layout: MinimalLayout

    /// Renders all available detail sections aligned to the right edge.
    var body: some View {
        VStack(alignment: .trailing, spacing: layout.detailSectionSpacing) {
            ForEach(snapshot.detailSections) { section in
                DetailSectionView(section: section, layout: layout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// One labeled group in the detail panel.
private struct DetailSectionView: View {
    /// Section title and rows to render.
    let section: DemographicDetailSection

    /// Layout metrics for row spacing and label/value sizing.
    let layout: MinimalLayout

    /// Renders the section title plus its rows.
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text(section.title)
                .font(LociqTypeScale.detailSectionLabel(layout))
                .foregroundStyle(.white.opacity(DemographicContentStyle.detailSectionTitleOpacity))

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
                                .foregroundStyle(.white.opacity(DemographicContentStyle.detailValueOpacity))
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
                            // Progress lines are optional and intentionally
                            // subtle. They add rhythm without turning the
                            // detail view into a chart surface.
                            ProgressLine(progress: progress)
                                .opacity(DemographicContentStyle.detailProgressOpacity)
                                .frame(maxWidth: max(64, layout.detailContentWidth - layout.detailLabelColumnWidth - 20))
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Specialized label renderer for detail rows.
///
/// Age labels use smaller words and larger numbers so strings such as
/// `18 TO 34` remain compact but readable in the narrow details column.
private struct DetailRowLabel: View {
    /// Raw uppercase label from the display model.
    let label: String

    /// Layout metrics that provide label fonts.
    let layout: MinimalLayout

    /// Renders the composed label text.
    var body: some View {
        labelText
            .foregroundStyle(.white.opacity(DemographicContentStyle.detailLabelOpacity))
    }

    /// Returns a composed text value with special age-label typography.
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

    /// Space using the default label font so composed labels align cleanly.
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
