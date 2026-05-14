//
//  DetailContent.swift
//  Lociq
//
//  Renders the secondary demographic detail rows.
//

import SwiftUI

struct DetailContent: View {
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

private struct DetailRowLabel: View {
    let label: String
    let layout: MinimalLayout

    var body: some View {
        labelText
            .foregroundStyle(.white.opacity(DemographicContentStyle.detailLabelOpacity))
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
