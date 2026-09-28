//
//  HeaderBlock.swift
//  Lociq
//
//  Renders the city title and its status line.
//
//  The header is intentionally sparse. It owns the city label anchor used by
//  the boundary connector. The status line keeps its height even when empty,
//  so a status appearing or clearing never shifts the metrics below.
//

import SwiftUI

/// Top-right city title and status line.
struct HeaderBlock: View {
    /// Display snapshot providing the title and status line.
    let snapshot: DemographicSnapshot

    /// Layout metrics for typography.
    let layout: MinimalLayout

    /// Moves VoiceOver focus to the title after the first reveal.
    var titleFocus: AccessibilityFocusState<Bool>.Binding

    /// Renders the city title and status line.
    var body: some View {
        VStack(alignment: .trailing, spacing: layout.space(6)) {
            Text(snapshot.market)
                .font(LociqTypeScale.city(layout))
                .foregroundStyle(Color.lociq(.primary))
                .monospacedDigit()
                .lineLimit(layout.usesSingleColumn ? 4 : 2)
                .minimumScaleFactor(layout.usesSingleColumn ? 1 : 0.74)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .anchorPreference(key: BoundaryCityConnectionPreferenceKey.self, value: .bounds) {
                    // Publish the city text bounds so `ContentView` can draw a
                    // faint connector from the boundary glyph to this label.
                    BoundaryCityConnectionAnchors(city: $0)
                }
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused(titleFocus)
                .accessibilityIdentifier("demographics.title")

            // In the two-column layout an empty status line keeps its height,
            // so a status appearing or clearing never shifts the metrics. In the
            // single column, where text is large, it takes no space when empty.
            if !snapshot.statusLine.isEmpty || !layout.usesSingleColumn {
                statusLine
            }
        }
        .multilineTextAlignment(.trailing)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("demographics.header")
    }

    private var statusLine: some View {
        Text(snapshot.statusLine.isEmpty ? " " : snapshot.statusLine)
            .font(LociqTypeScale.statusLabel(layout))
            .foregroundStyle(Color.lociq(.status))
            .lineLimit(2)
            .minimumScaleFactor(layout.usesSingleColumn ? 1 : 0.86)
            .allowsTightening(true)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(snapshot.statusLine.isEmpty ? 0 : 1)
            .accessibilityHidden(snapshot.statusLine.isEmpty)
            .accessibilityIdentifier("demographics.status")
            .animation(LociqMotion.quick, value: snapshot.statusLine)
    }
}
