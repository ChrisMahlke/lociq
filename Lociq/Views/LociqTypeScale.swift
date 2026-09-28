//
//  LociqTypeScale.swift
//  Lociq
//
//  Defines the minimal typography scale used across the app surface.
//
//  Minimal interfaces expose typography inconsistencies quickly. Centralizing
//  type choices keeps the city label, brand, metrics, and detail rows visually
//  related across iPhone and the constrained iPad viewport.
//

import SwiftUI

/// Central typography scale for the app UI.
///
/// Each style keeps its original point size at the default text size and
/// grows with the user's text size setting, relative to a matching system text
/// style. Sizes are selected from `MinimalLayout` rather than raw screen width
/// so iPad can use the same phone-style composition without a separate type
/// system.
enum LociqTypeScale {
    /// Returns the city label font for the current viewport.
    ///
    /// The city label is the dominant text element.
    static func city(_ layout: MinimalLayout) -> Font {
        .system(size: layout.scaled(layout.isCompactWidth ? 24 : 28, relativeTo: .title), weight: .light, design: .rounded)
            .leading(.tight)
    }

    /// Returns the quieter bottom brand font for the current viewport.
    ///
    /// Brand text is intentionally smaller and lighter than the city label, and
    /// its growth is capped so the wordmark never crowds the controls.
    static func brand(_ layout: MinimalLayout) -> Font {
        .system(
            size: min(layout.scaled(layout.isCompactWidth ? 20 : 22, relativeTo: .title3), 30),
            weight: .ultraLight,
            design: .rounded
        )
    }

    /// Returns the small status line font below the city.
    static func statusLabel(_ layout: MinimalLayout) -> Font {
        .system(size: layout.scaled(layout.isCompactWidth ? 12 : 13, relativeTo: .footnote), weight: .medium, design: .rounded)
    }

    /// Returns the summary metric label font.
    static func metricLabel(_ layout: MinimalLayout) -> Font {
        .system(size: layout.scaled(layout.isCompactWidth ? 13 : 14, relativeTo: .subheadline), weight: .regular, design: .rounded)
    }

    /// Returns the summary metric value font.
    static func metricValue(_ layout: MinimalLayout) -> Font {
        .system(size: layout.scaled(layout.isCompactWidth ? 17 : 18, relativeTo: .body), weight: .light, design: .rounded)
    }

    /// Returns the population value font, one step above the other values.
    static func primaryMetricValue(_ layout: MinimalLayout) -> Font {
        .system(size: layout.scaled(layout.isCompactWidth ? 21 : 22, relativeTo: .title3), weight: .light, design: .rounded)
    }

    /// Returns the secondary summary metric detail font.
    static func metricDetail(_ layout: MinimalLayout) -> Font {
        .system(size: layout.scaled(layout.isCompactWidth ? 11.5 : 12, relativeTo: .caption), weight: .regular, design: .rounded)
    }

    /// Returns the density label font under the boundary glyph.
    ///
    /// Growth stops at twice the default size so the label stays secondary to
    /// the city name and population, as the design brief requires.
    static func densityLabel(_ layout: MinimalLayout) -> Font {
        .system(size: min(layout.scaled(11, relativeTo: .caption2), 22), weight: .medium, design: .rounded)
    }

    /// Returns the "DATA" hint font beside the bottom controls, capped so it never crowds them.
    static func dataHint(_ layout: MinimalLayout) -> Font {
        .system(size: min(layout.scaled(layout.isCompactWidth ? 11.5 : 12, relativeTo: .caption), 17), weight: .regular, design: .rounded)
    }

    /// Returns the detail section label font.
    static func detailSectionLabel(_ layout: MinimalLayout) -> Font {
        .system(size: layout.scaled(12, relativeTo: .footnote), weight: .regular, design: .rounded)
    }

    /// Returns the detail row value font.
    static func detailValue(_ layout: MinimalLayout) -> Font {
        .system(size: layout.scaled(layout.isCompactWidth ? 16 : 17, relativeTo: .body), weight: .light, design: .rounded)
    }

    /// Returns the word portion of compound age labels.
    static func detailLabelWord(_ layout: MinimalLayout) -> Font {
        .system(size: layout.scaled(11, relativeTo: .caption2), weight: .regular, design: .rounded)
    }

    /// Returns the numeric portion of compound age labels.
    static func detailLabelNumber(_ layout: MinimalLayout) -> Font {
        .system(size: layout.scaled(layout.isCompactWidth ? 12 : 12.5, relativeTo: .footnote), weight: .regular, design: .rounded)
    }

    /// Returns the default detail label font.
    static func detailLabel(_ layout: MinimalLayout) -> Font {
        .system(size: layout.scaled(layout.isCompactWidth ? 11.5 : 12, relativeTo: .footnote), weight: .regular, design: .rounded)
    }

    /// Returns the smallest footnote font, used for the source notice.
    static func footnote(_ layout: MinimalLayout) -> Font {
        .system(size: layout.scaled(11, relativeTo: .caption2), weight: .regular, design: .rounded)
    }

    /// Returns the stage line font under the initial spinner.
    static func stageLabel(_ layout: MinimalLayout) -> Font {
        .system(size: layout.scaled(12, relativeTo: .footnote), weight: .medium, design: .rounded)
    }

    /// Returns the glyph size for bottom-bar icons.
    static func iconSize(_ layout: MinimalLayout, base: CGFloat = 16) -> CGFloat {
        min(layout.scaled(base, relativeTo: .body), base * 1.6)
    }
}
