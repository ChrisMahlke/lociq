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
/// Font sizes are selected from `MinimalLayout` rather than raw screen width so
/// iPad can use the same phone-style composition without a separate type system.
enum LociqTypeScale {
    /// Returns the city label font for the current viewport.
    ///
    /// The city label is the dominant text element.
    static func city(_ layout: MinimalLayout) -> Font {
        .system(size: layout.isCompactWidth ? 24 : 28, weight: .light, design: .rounded)
    }

    /// Returns the quieter bottom brand font for the current viewport.
    ///
    /// Brand text is intentionally smaller and lighter than the city label.
    static func brand(_ layout: MinimalLayout) -> Font {
        .system(size: layout.isCompactWidth ? 20 : 22, weight: .ultraLight, design: .rounded)
    }

    /// Returns the small status/date label font below the city.
    ///
    /// Used mostly for permission, loading, and failure status text.
    static func statusLabel(_ layout: MinimalLayout) -> Font {
        .system(size: layout.isCompactWidth ? 12 : 13, weight: .medium, design: .rounded)
    }

    /// Returns the summary metric label font.
    static func metricLabel(_ layout: MinimalLayout) -> Font {
        .system(size: layout.isCompactWidth ? 13 : 14, weight: .medium, design: .rounded)
    }

    /// Returns the summary metric value font.
    static func metricValue(_ layout: MinimalLayout) -> Font {
        .system(size: layout.isCompactWidth ? 17 : 18, weight: .light, design: .rounded)
    }

    /// Returns the secondary summary metric detail font.
    static func metricDetail(_ layout: MinimalLayout) -> Font {
        .system(size: layout.isCompactWidth ? 11.5 : 12, weight: .regular, design: .rounded)
    }

    /// Returns the detail section label font.
    static func detailSectionLabel(_ layout: MinimalLayout) -> Font {
        .system(size: 12, weight: .light, design: .rounded)
    }

    /// Returns the detail row value font.
    static func detailValue(_ layout: MinimalLayout) -> Font {
        .system(size: layout.isCompactWidth ? 16 : 17, weight: .light, design: .rounded)
    }

    /// Returns the word portion of compound detail labels.
    static func detailLabelWord(_ layout: MinimalLayout) -> Font {
        .system(size: layout.isCompactWidth ? 9 : 9.5, weight: .regular, design: .rounded)
    }

    /// Returns the numeric portion of compound detail labels.
    static func detailLabelNumber(_ layout: MinimalLayout) -> Font {
        .system(size: layout.isCompactWidth ? 12 : 12.5, weight: .regular, design: .rounded)
    }

    /// Returns the default detail label font.
    static func detailLabel(_ layout: MinimalLayout) -> Font {
        .system(size: (layout.isCompactWidth ? 12 : 12.5) - 0.5, weight: .regular, design: .rounded)
    }
}
