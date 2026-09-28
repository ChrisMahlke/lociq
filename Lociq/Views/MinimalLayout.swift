//
//  MinimalLayout.swift
//  Lociq
//
//  Computes stable responsive measurements for the minimal phone-style layout.
//
//  Layout values are centralized so the individual SwiftUI views can stay
//  declarative. The same layout is used on iPhone and inside the constrained
//  iPad viewport. Heights are not computed here: the bottom bar sits below the
//  content in the view hierarchy, so content always ends above it.
//

import SwiftUI
import UIKit

/// Responsive measurements for the minimal app surface.
///
/// The type computes stable dimensions for recurring UI surfaces such as the
/// boundary preview and content columns, and scales type with the user's text
/// size. That prevents text updates and animation states from causing layout
/// shifts.
struct MinimalLayout {
    /// True for narrow phone-sized surfaces.
    let isCompactWidth: Bool

    /// True when vertical space is limited.
    let isShortHeight: Bool

    /// The user's text size.
    let dynamicTypeSize: DynamicTypeSize

    /// True when large text needs a single-column composition.
    ///
    /// The two-column layout is sized for the default text sizes, so the
    /// single column starts at xxxL, before the accessibility sizes.
    let usesSingleColumn: Bool

    /// Top inset for the city header and content stack.
    let topInset: CGFloat

    /// Bottom inset for the brand/action surface.
    let bottomInset: CGFloat

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

    /// Top position for the boundary preview in the two-column layout.
    let boundaryTop: CGFloat

    /// Leading position for the boundary preview in the two-column layout.
    let boundaryLeading: CGFloat

    /// Vertical spacing between detail rows.
    let detailRowSpacing: CGFloat

    /// Vertical spacing between detail sections.
    let detailSectionSpacing: CGFloat

    /// Computes stable responsive measurements for a constrained app viewport.
    ///
    /// - Parameters:
    ///   - viewportSize: Size of the app surface, not necessarily the full device screen.
    ///   - safeAreaInsets: Safe area insets that should influence top and bottom padding.
    ///   - dynamicTypeSize: The user's text size.
    init(
        viewportSize: CGSize,
        safeAreaInsets: EdgeInsets = EdgeInsets(),
        dynamicTypeSize: DynamicTypeSize = .large
    ) {
        let width = viewportSize.width
        let height = viewportSize.height
        isCompactWidth = width < 380
        isShortHeight = height < 700
        self.dynamicTypeSize = dynamicTypeSize
        usesSingleColumn = dynamicTypeSize >= .xxxLarge
        topInset = max(isShortHeight ? 44 : 54, safeAreaInsets.top + (isShortHeight ? 24 : 34))
        bottomInset = max(isShortHeight ? 22 : 30, safeAreaInsets.bottom + (isShortHeight ? 14 : 20))
        trailingInset = isCompactWidth ? 22 : 28
        horizontalInset = isCompactWidth ? 20 : 24
        contentWidth = usesSingleColumn
            ? max(220, width - trailingInset - horizontalInset)
            : min(width * (isCompactWidth ? 0.68 : 0.64), isCompactWidth ? 292 : 340)
        detailContentWidth = usesSingleColumn
            ? contentWidth
            : min(width * (isCompactWidth ? 0.55 : 0.50), isCompactWidth ? 214 : 246)
        boundarySize = CGSize(
            width: min(max(width * (isCompactWidth ? 0.25 : 0.28), isCompactWidth ? 82 : 96), isCompactWidth ? 118 : 142),
            height: min(max(height * (isShortHeight ? 0.16 : 0.19), isShortHeight ? 92 : 112), isShortHeight ? 132 : 158)
        )
        boundaryTop = topInset + (isShortHeight ? 78 : 96)
        boundaryLeading = isCompactWidth ? 24 : 30
        detailRowSpacing = isCompactWidth ? 10 : 12
        detailSectionSpacing = isShortHeight ? 16 : 20
    }

    /// Scales a default-size point value with the user's text size.
    ///
    /// At the default size (Large) the value is returned unchanged, so the
    /// default composition is pixel-identical to the original fixed sizes.
    func scaled(_ value: CGFloat, relativeTo textStyle: Font.TextStyle) -> CGFloat {
        Self.scaledValue(value, relativeTo: textStyle, dynamicTypeSize: dynamicTypeSize)
    }

    /// Scales a point value for a text style and text size, like `@ScaledMetric`.
    ///
    /// The value is multiplied by the style's growth relative to the default
    /// size (Large). `UIFontMetrics` alone snaps some sizes that are not on its
    /// grid, such as 11.5 pt, even at Large; the ratio keeps Large exact.
    static func scaledValue(_ value: CGFloat, relativeTo textStyle: Font.TextStyle, dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        guard dynamicTypeSize != .large else { return value }
        let metrics = UIFontMetrics(forTextStyle: textStyle.uiTextStyle)
        let reference: CGFloat = 100
        let target = metrics.scaledValue(
            for: reference,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        )
        let base = metrics.scaledValue(for: reference, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        return base > 0 ? value * target / base : value
    }
}

private extension Font.TextStyle {
    /// Matching UIKit text style for `UIFontMetrics`.
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
}
