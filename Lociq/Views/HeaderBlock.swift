//
//  HeaderBlock.swift
//  Lociq
//
//  Renders the city title and optional status line.
//
//  The header is intentionally sparse. It owns the city label anchor used by
//  the boundary connector and avoids extra metadata when there is no status to
//  show.
//

import SwiftUI

/// Top-right city title and optional secondary status label.
struct HeaderBlock: View {
    /// Display snapshot providing the title and status label.
    let snapshot: DemographicSnapshot

    /// Layout metrics for typography.
    let layout: MinimalLayout

    /// Renders the city title and optional status label.
    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(snapshot.market)
                .font(LociqTypeScale.city(layout))
                .foregroundStyle(Color.lociqText)
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.74)
                .allowsTightening(true)
                .anchorPreference(key: BoundaryCityConnectionPreferenceKey.self, value: .bounds) {
                    // Publish the city text bounds so `ContentView` can draw a
                    // faint connector from the boundary glyph to this label.
                    BoundaryCityConnectionAnchors(city: $0)
                }

            if !snapshot.dateLabel.isEmpty {
                Text(snapshot.dateLabel)
                    .font(LociqTypeScale.statusLabel(layout))
                    .foregroundStyle(Color.lociqText.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .allowsTightening(true)
                    .transition(.opacity)
            }
        }
        .multilineTextAlignment(.trailing)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("demographics.header")
    }
}
