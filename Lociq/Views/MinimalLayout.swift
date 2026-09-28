//
//  MinimalLayout.swift
//  Lociq
//
//  Computes stable responsive measurements for the minimal layout.
//
//  Layout values are centralized so the individual SwiftUI views can stay
//  declarative. iPhone, and narrow iPad windows such as Slide Over, use the
//  original phone composition. Larger iPad windows scale the same composition
//  to the canvas, and wide ones show the details beside the summary. Heights
//  are not computed here: the bottom bar sits below the content in the view
//  hierarchy, so content always ends above it.
//

import SwiftUI
import UIKit

/// Responsive measurements for the minimal app surface.
///
/// The type computes stable dimensions for recurring UI surfaces such as the
/// boundary preview and content columns, and scales type with the canvas and
/// the user's text size. That prevents text updates and animation states from
/// causing layout shifts.
struct MinimalLayout {
    /// How the composition uses the window.
    enum Canvas: Equatable {
        /// iPhone and narrow iPad windows: the original composition, unchanged.
        case phone

        /// iPad windows: the same composition, scaled to the window.
        case large

        /// Wide iPad windows: the large composition, with the details beside the summary.
        case spread
    }

    /// Smallest window that gets the large composition.
    ///
    /// Narrower windows (every iPhone, Slide Over, and narrow Split View)
    /// keep the phone composition the design was tuned for.
    static let largeCanvasMinimumSize = CGSize(width: 600, height: 500)

    /// Largest growth of the composition on a large canvas (a 13-inch iPad in portrait).
    static let maximumCanvasScale: CGFloat = 1.45

    /// Canvas class for the window.
    let canvas: Canvas

    /// Growth of the composition over the phone design: 1 on phones,
    /// up to `maximumCanvasScale` on large iPads.
    let canvasScale: CGFloat

    /// True for narrow phone-sized surfaces.
    let isCompactWidth: Bool

    /// True when vertical space is limited.
    let isShortHeight: Bool

    /// The user's text size.
    let dynamicTypeSize: DynamicTypeSize

    /// True when large text needs a single-column composition.
    ///
    /// The phone composition is sized for the default text sizes, so its
    /// single column starts at xxxL, before the accessibility sizes. Large
    /// canvases keep two columns until the accessibility sizes, and wide
    /// ones (1,000 pt or more) at every size.
    let usesSingleColumn: Bool

    /// Top inset for the city header and content stack.
    let topInset: CGFloat

    /// Bottom inset for the brand/action surface.
    let bottomInset: CGFloat

    /// Width of the right-aligned content column.
    let contentWidth: CGFloat

    /// Width of the details content column.
    let detailContentWidth: CGFloat

    /// Width of the details column beside the summary; zero unless the canvas is a spread.
    let detailSidebarWidth: CGFloat

    /// Space between the summary column and the details beside it.
    let columnGap: CGFloat

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

    /// Widest the bottom bar grows.
    let bottomBarMaxWidth: CGFloat

    /// Growth of the diagonal background plane.
    let backgroundScale: CGFloat

    /// Growth of spacing between elements, matching body text.
    let spacingScale: CGFloat

    /// True when the details appear beside the summary instead of replacing it.
    var showsDetailsBeside: Bool {
        canvas == .spread
    }

    /// Growth of hairlines, dots, and the location marker in the boundary glyph.
    ///
    /// Grows more slowly than text, so strokes stay fine on a larger glyph.
    var graphicScale: CGFloat {
        canvasScale.squareRoot()
    }

    /// Computes stable responsive measurements for a window.
    ///
    /// - Parameters:
    ///   - viewportSize: Size of the app surface inside the safe area.
    ///   - safeAreaInsets: Safe area insets that should influence top and bottom padding.
    ///   - dynamicTypeSize: The user's text size.
    init(
        viewportSize: CGSize,
        safeAreaInsets: EdgeInsets = EdgeInsets(),
        dynamicTypeSize: DynamicTypeSize = .large
    ) {
        let width = viewportSize.width
        let height = viewportSize.height
        self.dynamicTypeSize = dynamicTypeSize
        isShortHeight = height < 700

        guard width >= Self.largeCanvasMinimumSize.width, height >= Self.largeCanvasMinimumSize.height else {
            // The original phone composition, unchanged.
            canvas = .phone
            canvasScale = 1
            spacingScale = 1
            isCompactWidth = width < 380
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
            detailSidebarWidth = 0
            columnGap = 0
            boundarySize = CGSize(
                width: min(max(width * (isCompactWidth ? 0.25 : 0.28), isCompactWidth ? 82 : 96), isCompactWidth ? 118 : 142),
                height: min(max(height * (isShortHeight ? 0.16 : 0.19), isShortHeight ? 92 : 112), isShortHeight ? 132 : 158)
            )
            boundaryTop = topInset + (isShortHeight ? 78 : 96)
            boundaryLeading = isCompactWidth ? 24 : 30
            detailRowSpacing = isCompactWidth ? 10 : 12
            detailSectionSpacing = isShortHeight ? 16 : 20
            bottomBarMaxWidth = 520
            backgroundScale = 1
            return
        }

        // A large canvas: the phone composition, grown to the window. Widths
        // grow with the text they hold, so columns always fit their type.
        let scale = Self.canvasScale(for: viewportSize)
        let bodyScale = Self.canvasMultiplier(for: .body, canvasScale: scale)
        let smallScale = Self.canvasMultiplier(for: .caption, canvasScale: scale)
        let margin = min(max(40, width * 0.055), 80)
        let boundaryGap = 48 * bodyScale
        canvasScale = scale
        // Vertical rhythm follows the window's height as well as the type, so
        // the composition fills a tall iPad about as much as it fills a phone.
        spacingScale = max(bodyScale, (bodyScale + min(height / 874, 1.6)) / 2)
        isCompactWidth = false
        usesSingleColumn = dynamicTypeSize >= .accessibility1 && width < 1000
        topInset = max(56, height * 0.1)
        bottomInset = max(40, height * 0.05)
        trailingInset = margin
        horizontalInset = margin

        // A spread needs room for the geography, the summary, and the details
        // side by side, and the height to show the details whole. Its columns
        // are sized for the standard text sizes; at the accessibility sizes
        // the details take turns with the summary instead.
        let summaryWidth = 320 * bodyScale
        let sidebarWidth = 280 * smallScale
        let sidebarGap = 72 * bodyScale
        let spreadGeographyWidth = width - 2 * margin - boundaryGap - summaryWidth - sidebarGap - sidebarWidth
        let isSpread = !usesSingleColumn
            && dynamicTypeSize < .accessibility1
            && height >= 720
            && spreadGeographyWidth >= 200 * bodyScale

        let geographyWidth: CGFloat
        if isSpread {
            canvas = .spread
            contentWidth = summaryWidth
            detailSidebarWidth = sidebarWidth
            columnGap = sidebarGap
            detailContentWidth = sidebarWidth
            geographyWidth = spreadGeographyWidth
        } else {
            canvas = .large
            contentWidth = usesSingleColumn
                ? max(220, width - 2 * margin)
                : min(max(width * 0.42, 300 * bodyScale), 560)
            detailSidebarWidth = 0
            columnGap = 0
            detailContentWidth = usesSingleColumn
                ? contentWidth
                : min(contentWidth, max(width * 0.36, 300 * smallScale))
            geographyWidth = usesSingleColumn ? width - 2 * margin : width - 2 * margin - boundaryGap - contentWidth
        }

        // The outline is the anchor of the left side: centered in its zone,
        // as large as the zone allows, and never taller than a third of the window.
        let glyphWidth = max(96, min(geographyWidth * (usesSingleColumn ? 0.5 : 0.78), 320 * scale, height * 0.3))
        boundarySize = CGSize(width: glyphWidth, height: (glyphWidth * 1.1).rounded())
        boundaryLeading = margin + max(0, (geographyWidth - glyphWidth) / 2)
        boundaryTop = topInset + 96 * spacingScale
        detailRowSpacing = 12 * bodyScale
        detailSectionSpacing = 20 * bodyScale
        bottomBarMaxWidth = .infinity
        backgroundScale = max(1, min(width / 402, height / 874))
    }

    /// Growth of the composition for a large canvas.
    ///
    /// Relative to a 700 x 820 pt window, the smallest iPad canvas the design
    /// is scaled from; limited by whichever side is shorter.
    static func canvasScale(for size: CGSize) -> CGFloat {
        min(max(min(size.width / 700, size.height / 820), 1), maximumCanvasScale)
    }

    /// Scales spacing between elements for the canvas.
    ///
    /// Returns the value unchanged on phones.
    func space(_ value: CGFloat) -> CGFloat {
        value * spacingScale
    }

    /// Scales a default-size point value with the canvas and the user's text size.
    ///
    /// On phones at the default size (Large) the value is returned unchanged,
    /// so the default composition is pixel-identical to the original fixed sizes.
    func scaled(_ value: CGFloat, relativeTo textStyle: Font.TextStyle) -> CGFloat {
        Self.scaledValue(value, relativeTo: textStyle, dynamicTypeSize: dynamicTypeSize, canvasScale: canvasScale)
    }

    /// Returns `value` scaled for the text size and canvas, but no larger than
    /// `limit`, itself grown for the canvas.
    ///
    /// Limits keep secondary text, such as the wordmark, from outgrowing the
    /// content at the largest text sizes.
    func scaled(_ value: CGFloat, relativeTo textStyle: Font.TextStyle, limit: CGFloat) -> CGFloat {
        min(scaled(value, relativeTo: textStyle), limit * Self.canvasMultiplier(for: textStyle, canvasScale: canvasScale))
    }

    /// Growth of a text style on a canvas at the default text size.
    ///
    /// Display styles grow with the canvas; body and caption styles grow
    /// less, which keeps hierarchy and keeps small text from looking inflated.
    static func canvasMultiplier(for textStyle: Font.TextStyle, canvasScale: CGFloat) -> CGFloat {
        let share: CGFloat
        switch textStyle {
        case .largeTitle, .title, .title2, .title3:
            share = 1
        case .footnote, .caption, .caption2:
            share = 0.6
        default:
            share = 0.8
        }
        return 1 + (canvasScale - 1) * share
    }

    /// Scales a point value for a text style, text size, and canvas, like `@ScaledMetric`.
    ///
    /// The value is multiplied by the style's growth relative to the default
    /// size (Large). `UIFontMetrics` alone snaps some sizes that are not on its
    /// grid, such as 11.5 pt, even at Large; the ratio keeps Large exact.
    ///
    /// On a large canvas, the canvas growth fades out as the text size grows,
    /// so the accessibility sizes match iPhone. Text never gets smaller when
    /// the user makes it larger.
    static func scaledValue(
        _ value: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        dynamicTypeSize: DynamicTypeSize,
        canvasScale: CGFloat = 1
    ) -> CGFloat {
        let metrics = fontMetrics(for: textStyle, dynamicTypeSize: dynamicTypeSize)
        let canvasGrowth = canvasMultiplier(for: textStyle, canvasScale: canvasScale)
        guard canvasGrowth > 1 else {
            guard let metrics, metrics.base > 0 else { return value }
            return value * metrics.target / metrics.base
        }
        let textGrowth = metrics.map { $0.base > 0 ? $0.target / $0.base : 1 } ?? 1
        let fade = min(max(2 - textGrowth, 0), 1)
        return value * textGrowth * (1 + (canvasGrowth - 1) * fade)
    }

    /// `UIFontMetrics` sizes of a 100 pt reference at the text size and at
    /// Large; `nil` at Large, where nothing scales.
    private static func fontMetrics(
        for textStyle: Font.TextStyle,
        dynamicTypeSize: DynamicTypeSize
    ) -> (target: CGFloat, base: CGFloat)? {
        guard dynamicTypeSize != .large else { return nil }
        let metrics = UIFontMetrics(forTextStyle: textStyle.uiTextStyle)
        let reference: CGFloat = 100
        let target = metrics.scaledValue(
            for: reference,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        )
        let base = metrics.scaledValue(for: reference, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        return (target, base)
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
