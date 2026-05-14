//
//  BoundaryCityConnectionPreference.swift
//  Lociq
//
//  Shares boundary and city-label anchors for connector drawing.
//
//  The boundary preview and city header live in separate branches of the view
//  tree. A preference key lets both publish geometry up to `ContentView`, where
//  the connector line can be drawn in a shared coordinate space.
//

import SwiftUI

/// Anchor payload used to connect the boundary preview to the city label.
struct BoundaryCityConnectionAnchors: Equatable {
    /// Boundary view bounds anchor.
    var boundary: Anchor<CGRect>?

    /// Projected center of the actual boundary path inside the boundary view.
    var boundaryCenter: CGPoint?

    /// City label bounds anchor.
    var city: Anchor<CGRect>?
}

/// Preference key that merges boundary and city anchors emitted by different views.
struct BoundaryCityConnectionPreferenceKey: PreferenceKey {
    /// Empty anchor payload used before child views publish geometry.
    static var defaultValue = BoundaryCityConnectionAnchors()

    /// Merges boundary and city anchors emitted by separate views.
    ///
    /// Each child publishes only the anchor it owns. Reduction keeps previously
    /// collected values when the next payload does not include that anchor.
    static func reduce(value: inout BoundaryCityConnectionAnchors, nextValue: () -> BoundaryCityConnectionAnchors) {
        let next = nextValue()
        value.boundary = next.boundary ?? value.boundary
        value.boundaryCenter = next.boundaryCenter ?? value.boundaryCenter
        value.city = next.city ?? value.city
    }
}
