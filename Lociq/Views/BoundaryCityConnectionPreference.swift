//
//  BoundaryCityConnectionPreference.swift
//  Lociq
//
//  Shares boundary and city-label anchors for connector drawing.
//

import SwiftUI

struct BoundaryCityConnectionAnchors: Equatable {
    var boundary: Anchor<CGRect>?
    var boundaryCenter: CGPoint?
    var city: Anchor<CGRect>?
}

struct BoundaryCityConnectionPreferenceKey: PreferenceKey {
    static var defaultValue = BoundaryCityConnectionAnchors()

    /// Merges boundary and city anchors emitted by separate views.
    static func reduce(value: inout BoundaryCityConnectionAnchors, nextValue: () -> BoundaryCityConnectionAnchors) {
        let next = nextValue()
        value.boundary = next.boundary ?? value.boundary
        value.boundaryCenter = next.boundaryCenter ?? value.boundaryCenter
        value.city = next.city ?? value.city
    }
}
