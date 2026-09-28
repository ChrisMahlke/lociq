//
//  DetailContent.swift
//  Lociq
//
//  Renders the secondary demographic detail rows and the source footer.
//
//  The details view keeps the same minimal vocabulary as the home view. It
//  groups values by section and uses quiet typography instead of adding charts
//  or explanatory panels. The footer names the source and vintage, carries the
//  Census Data API notice, and offers the appearance choice.
//

import SwiftUI

/// Detail panel for the secondary demographic view.
struct DetailContent: View {
    /// Snapshot containing display-ready detail sections.
    let snapshot: DemographicSnapshot

    /// Layout metrics for spacing, column width, and typography.
    let layout: MinimalLayout

    /// Current appearance.
    var themePreference: LociqThemePreference = .dark

    /// Changes the appearance.
    var onSelectTheme: (LociqThemePreference) -> Void = { _ in }

    /// Renders all available detail sections aligned to the right edge.
    var body: some View {
        VStack(alignment: .trailing, spacing: layout.detailSectionSpacing) {
            ForEach(snapshot.detailSections) { section in
                DetailSectionView(section: section, layout: layout)
            }

            DetailFooter(
                snapshot: snapshot,
                layout: layout,
                themePreference: themePreference,
                onSelectTheme: onSelectTheme
            )
            .padding(.top, 6)
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
                .foregroundStyle(Color.lociq(.sectionTitle))
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .trailing, spacing: layout.detailRowSpacing) {
                ForEach(section.rows) { row in
                    DetailRowView(row: row, layout: layout)
                }
            }
        }
    }
}

/// One label/value row.
///
/// Values always stay on one line. When label and value do not fit side by
/// side, as at large text sizes, the label stacks above the value instead of
/// the number breaking mid-value.
private struct DetailRowView: View {
    let row: DemographicDetailRow
    let layout: MinimalLayout

    var body: some View {
        ViewThatFits(in: .horizontal) {
            // Labels align to the leading edge and values to the trailing
            // edge, so natural widths line up without a fixed label column.
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                DetailRowLabel(row: row, layout: layout)
                    .lineLimit(1)
                    .fixedSize()
                value
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            VStack(alignment: .trailing, spacing: 2) {
                DetailRowLabel(row: row, layout: layout)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                value
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityValue(row.accessibilityValue)
    }

    private var value: some View {
        Text(row.value)
            .font(LociqTypeScale.detailValue(layout))
            .foregroundStyle(Color.lociq(.detailValue))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

/// Specialized label renderer for detail rows.
///
/// Age bands use smaller words and larger numbers so strings such as
/// `18 TO 34` remain compact but readable in the narrow details column.
private struct DetailRowLabel: View {
    let row: DemographicDetailRow
    let layout: MinimalLayout

    var body: some View {
        labelText
            .foregroundStyle(Color.lociq(.detailLabel))
    }

    /// Returns a composed text value with age-band typography.
    private var labelText: Text {
        guard row.resolvedKind?.isAgeBand == true else {
            return Text(row.label).font(LociqTypeScale.detailLabel(layout))
        }
        let tokens = row.label.split(separator: " ").map(String.init)
        return tokens.enumerated().reduce(Text("")) { text, element in
            let (index, token) = element
            let styled = Text(token).font(
                token.allSatisfy(\.isNumber) ? LociqTypeScale.detailLabelNumber(layout) : LociqTypeScale.detailLabelWord(layout)
            )
            let separator = index == 0 ? Text("") : Text(" ").font(LociqTypeScale.detailLabel(layout))
            return text + separator + styled
        }
    }
}

/// Source, vintage, Census API notice, and appearance choice.
private struct DetailFooter: View {
    let snapshot: DemographicSnapshot
    let layout: MinimalLayout
    let themePreference: LociqThemePreference
    let onSelectTheme: (LociqThemePreference) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            VStack(alignment: .trailing, spacing: 4) {
                Text("SOURCE · U.S. CENSUS BUREAU")
                    .font(LociqTypeScale.detailLabel(layout))
                    .foregroundStyle(Color.lociq(.detailLabel))
                Text(vintage?.sourceLabel ?? "ACS 5-YEAR ESTIMATES")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .font(LociqTypeScale.detailLabel(layout))
                    .foregroundStyle(Color.lociq(.detailLabel))
                Text(CensusAttribution.apiNotice)
                    .font(LociqTypeScale.footnote(layout))
                    .foregroundStyle(Color.lociq(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .multilineTextAlignment(.trailing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(sourceAccessibilityLabel)
            .accessibilityIdentifier("details.source")

            Menu {
                Picker("Appearance", selection: themeBinding) {
                    ForEach(LociqThemePreference.allCases) { preference in
                        Label(preference.label, systemImage: preference.iconName)
                            .tag(preference)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("APPEARANCE")
                        .foregroundStyle(Color.lociq(.detailLabel))
                    Text(themePreference.label.uppercased())
                        .foregroundStyle(Color.lociq(.detailValue))
                }
                .font(LociqTypeScale.detailLabel(layout))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Appearance")
            .accessibilityValue(themePreference.label)
            .accessibilityInputLabels(["Appearance", "Theme"])
            .accessibilityIdentifier("details.appearance")
        }
    }

    private var vintage: CensusDataVintage? {
        CensusDataVintage(identifier: snapshot.dataVintage)
    }

    private var sourceAccessibilityLabel: String {
        let period = vintage.map { "\($0.acsYear - 4) to \($0.acsYear) " } ?? ""
        return "Source: U.S. Census Bureau, American Community Survey \(period)5-year estimates. \(CensusAttribution.apiNotice)"
    }

    private var themeBinding: Binding<LociqThemePreference> {
        Binding(get: { themePreference }, set: { onSelectTheme($0) })
    }
}
