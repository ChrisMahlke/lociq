//
//  DemographicContentStyle.swift
//  Lociq
//
//  Centralizes opacity constants for demographic text surfaces.
//
//  Minimal UI depends on small contrast differences. Keeping opacity constants
//  here prevents each view from inventing its own visual hierarchy.
//

/// Shared opacity values for demographic content.
enum DemographicContentStyle {
    /// Overall detail-panel opacity relative to the summary panel.
    static let detailPanelOpacity = 0.88

    /// Detail section title opacity.
    static let detailSectionTitleOpacity = 0.38

    /// Detail row label opacity.
    static let detailLabelOpacity = 0.52

    /// Detail row value opacity.
    static let detailValueOpacity = 0.88

    /// Optional detail progress line opacity.
    static let detailProgressOpacity = 0.48
}
