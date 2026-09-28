//
//  MinimalLayout.swift
//  Lociq
//
//  Computes stable responsive measurements for the minimal phone-style layout.
//
//  Layout values are centralized so the individual SwiftUI views can stay
//  declarative. The same layout is used on iPhone and inside the constrained
//  iPad viewport.
//

import SwiftUI

/// Responsive measurements for the minimal app surface.
///
/// The type intentionally computes fixed, stable dimensions for recurring UI
/// surfaces such as boundary preview, content columns, and bottom identity. That
/// prevents text updates and animation states from causing layout shifts.
struct MinimalLayout {
    /// True for narrow phone-sized surfaces.
    let isCompactWidth: Bool

    /// True when vertical space is limited.
    let isShortHeight: Bool

    /// True when accessibility text sizes need a single-column composition.
    let usesAccessibilityLayout: Bool

    /// Top inset for the city header and content stack.
    let topInset: CGFloat

    /// Bottom inset for the brand/action surface.
    let bottomInset: CGFloat

    /// Reserved vertical space for the bottom identity area.
    let bottomReserve: CGFloat

    /// Maximum content height available for summary and details.
    let detailHeight: CGFloat

    /// Width of the right-aligned content column.
    let contentWidth: CGFloat

    /// Width of the details content column.
    let detailContentWidth: CGFloat

    /// Right inset for the content stack.
    let trailingInset: CGFloat

    /// Horizontal inset for the bottom identity area.
    let horizontalInset: CGFloat

    /// Size of the geographic boundary preview.
    let boundarySize: CGSize

    /// Top position for the boundary preview.
    let boundaryTop: CGFloat

    /// Leading position for the boundary preview.
    let boundaryLeading: CGFloat

    /// Fixed label column width in the details view.
    let detailLabelColumnWidth: CGFloat

    /// Vertical spacing between detail rows.
    let detailRowSpacing: CGFloat

    /// Vertical spacing between detail sections.
    let detailSectionSpacing: CGFloat

    /// Computes stable responsive measurements for the current rendered viewport.
    ///
    /// This initializer is convenient for direct use with `GeometryReader`.
    init(geometry: GeometryProxy) {
        self.init(viewportSize: geometry.size, safeAreaInsets: geometry.safeAreaInsets)
    }

    /// Computes stable responsive measurements for a constrained app viewport.
    ///
    /// - Parameters:
    ///   - viewportSize: Size of the app surface, not necessarily the full device screen.
    ///   - safeAreaInsets: Safe area insets that should influence top and bottom padding.
    init(
        viewportSize: CGSize,
        safeAreaInsets: EdgeInsets = EdgeInsets(),
        usesAccessibilityLayout: Bool = false
    ) {
        let width = viewportSize.width
        let height = viewportSize.height
        isCompactWidth = width < 380
        isShortHeight = height < 700
        self.usesAccessibilityLayout = usesAccessibilityLayout
        topInset = max(isShortHeight ? 44 : 54, safeAreaInsets.top + (isShortHeight ? 24 : 34))
        bottomInset = max(isShortHeight ? 22 : 30, safeAreaInsets.bottom + (isShortHeight ? 14 : 20))
        bottomReserve = height < 520 ? 168 : (isShortHeight ? 174 : 190)
        detailHeight = max(112, height - topInset - bottomReserve)
        trailingInset = isCompactWidth ? 22 : 28
        horizontalInset = isCompactWidth ? 20 : 24
        contentWidth = usesAccessibilityLayout
            ? max(220, width - (isCompactWidth ? 44 : 56))
            : min(width * (isCompactWidth ? 0.68 : 0.64), isCompactWidth ? 292 : 340)
        detailContentWidth = usesAccessibilityLayout
            ? contentWidth
            : min(width * (isCompactWidth ? 0.55 : 0.50), isCompactWidth ? 214 : 246)
        boundarySize = CGSize(
            width: min(max(width * (isCompactWidth ? 0.25 : 0.28), isCompactWidth ? 82 : 96), isCompactWidth ? 118 : 142),
            height: min(max(height * (isShortHeight ? 0.16 : 0.19), isShortHeight ? 92 : 112), isShortHeight ? 132 : 158)
        )
        boundaryTop = usesAccessibilityLayout ? topInset : topInset + (isShortHeight ? 78 : 96)
        boundaryLeading = usesAccessibilityLayout
            ? max(22, (width - boundarySize.width) / 2)
            : (isCompactWidth ? 24 : 30)
        detailLabelColumnWidth = usesAccessibilityLayout ? min(132, contentWidth * 0.46) : (isCompactWidth ? 100 : 108)
        detailRowSpacing = isCompactWidth ? 10 : 12
        detailSectionSpacing = isShortHeight ? 16 : 20
    }

    /// Top of content after the boundary in the accessibility single-column mode.
    var contentTopInset: CGFloat {
        usesAccessibilityLayout ? boundaryTop + boundarySize.height + 46 : topInset
    }
}
