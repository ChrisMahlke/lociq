//
//  LociqTypeScale.swift
//  Lociq
//
//  Defines the minimal typography scale used across the app surface.
//
//  Minimal interfaces expose typography inconsistencies quickly. Centralizing
//  type choices keeps the city label, brand, metrics, and detail rows visually
//  related across iPhone and iPad.
//

import SwiftUI
import UIKit

/// Central typography scale for the app UI.
///
/// Each style keeps its original point size at the default text size and
/// grows with the user's text size setting, relative to a matching system text
/// style. Sizes are selected from `MinimalLayout` rather than raw screen width,
/// so on iPad the same scale grows with the window instead of needing a
/// separate type system.
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
            size: layout.scaled(layout.isCompactWidth ? 20 : 22, relativeTo: .title3, limit: 30),
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
        .system(size: metricLabelSize(layout), weight: .regular, design: .rounded)
    }

    /// Point size of the summary metric label.
    static func metricLabelSize(_ layout: MinimalLayout) -> CGFloat {
        layout.scaled(layout.isCompactWidth ? 13 : 14, relativeTo: .subheadline)
    }

    /// Cap height of the summary metric label, for aligning shapes with the
    /// top of its capitals.
    static func metricLabelCapHeight(_ layout: MinimalLayout) -> CGFloat {
        let size = metricLabelSize(layout)
        let font = UIFont.systemFont(ofSize: size, weight: .regular)
        let rounded = font.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? font
        return rounded.capHeight
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
        .system(size: layout.scaled(11, relativeTo: .caption2, limit: 22), weight: .medium, design: .rounded)
    }

    /// Returns the "DATA" hint font beside the bottom controls, capped so it never crowds them.
    static func dataHint(_ layout: MinimalLayout) -> Font {
        .system(size: layout.scaled(layout.isCompactWidth ? 11.5 : 12, relativeTo: .caption, limit: 17), weight: .regular, design: .rounded)
    }

    /// Returns the detail section label font.
    static func detailSectionLabel(_ layout: MinimalLayout) -> Font {
        .system(size: layout.scaled(12, relativeTo: .footnote), weight: .regular, design: .rounded)
    }

    /// Returns the detail row value font.
    ///
    /// - Parameter secondary: True when the details sit beside the summary,
    ///   where their values step down so Population and Income stay louder.
    static func detailValue(_ layout: MinimalLayout, secondary: Bool = false) -> Font {
        let size = layout.scaled(layout.isCompactWidth ? 16 : 17, relativeTo: .body)
        return .system(size: secondary ? size * 0.88 : size, weight: .light, design: .rounded)
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
        layout.scaled(base, relativeTo: .body, limit: base * 1.6)
    }
}
