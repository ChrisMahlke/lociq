//
//  MinimalLayout.swift
//  Lociq
//
//  Computes stable responsive measurements for the iPhone-only layout.
//

import SwiftUI

struct MinimalLayout {
    let isCompactWidth: Bool
    let isShortHeight: Bool
    let topInset: CGFloat
    let bottomInset: CGFloat
    let bottomReserve: CGFloat
    let detailHeight: CGFloat
    let contentWidth: CGFloat
    let detailContentWidth: CGFloat
    let trailingInset: CGFloat
    let horizontalInset: CGFloat
    let boundarySize: CGSize
    let boundaryTop: CGFloat
    let boundaryLeading: CGFloat
    let cityFontSize: CGFloat
    let metricTitleSize: CGFloat
    let metricValueSize: CGFloat
    let metricDetailSize: CGFloat
    let brandFontSize: CGFloat
    let detailValueSize: CGFloat
    let detailLabelWordSize: CGFloat
    let detailLabelNumberSize: CGFloat

    /// Computes stable responsive measurements for the current iPhone viewport.
    init(geometry: GeometryProxy) {
        let width = geometry.size.width
        let height = geometry.size.height
        isCompactWidth = width < 380
        isShortHeight = height < 700
        topInset = max(isShortHeight ? 44 : 54, geometry.safeAreaInsets.top + (isShortHeight ? 24 : 34))
        bottomInset = max(isShortHeight ? 22 : 30, geometry.safeAreaInsets.bottom + (isShortHeight ? 14 : 20))
        bottomReserve = height < 520 ? 168 : (isShortHeight ? 174 : 190)
        detailHeight = max(112, height - topInset - bottomReserve)
        trailingInset = isCompactWidth ? 22 : 28
        horizontalInset = isCompactWidth ? 20 : 24
        contentWidth = min(width * (isCompactWidth ? 0.68 : 0.64), isCompactWidth ? 292 : 340)
        detailContentWidth = min(width * (isCompactWidth ? 0.55 : 0.50), isCompactWidth ? 214 : 246)
        boundarySize = CGSize(
            width: min(max(width * (isCompactWidth ? 0.25 : 0.28), isCompactWidth ? 82 : 96), isCompactWidth ? 118 : 142),
            height: min(max(height * (isShortHeight ? 0.16 : 0.19), isShortHeight ? 92 : 112), isShortHeight ? 132 : 158)
        )
        boundaryTop = topInset + (isShortHeight ? 78 : 96)
        boundaryLeading = isCompactWidth ? 24 : 30
        cityFontSize = isCompactWidth ? 24 : 28
        metricTitleSize = isCompactWidth ? 13 : 14
        metricValueSize = isCompactWidth ? 17 : 18
        metricDetailSize = isCompactWidth ? 11.5 : 12
        brandFontSize = isCompactWidth ? 22 : 24
        detailValueSize = isCompactWidth ? 16 : 17
        detailLabelWordSize = isCompactWidth ? 9 : 9.5
        detailLabelNumberSize = isCompactWidth ? 12 : 12.5
    }
}
