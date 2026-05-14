//
//  HeaderBlock.swift
//  Lociq
//
//  Renders the city title and optional status line.
//

import SwiftUI

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
