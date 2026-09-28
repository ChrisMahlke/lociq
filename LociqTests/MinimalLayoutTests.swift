//
//  MinimalLayoutTests.swift
//  LociqTests
//
//  Verifies Dynamic Type scaling, the single-column switch, and the iPad canvases.
//

import SwiftUI
import Testing
@testable import Lociq

@MainActor
/// Tests for `MinimalLayout` text scaling and canvas classes.
struct MinimalLayoutTests {
    private let phone = CGSize(width: 375, height: 667)

    /// Safe-area sizes of iPad windows, in points.
    private let pad13Portrait = CGSize(width: 1032, height: 1332)
    private let pad13Landscape = CGSize(width: 1376, height: 988)
    private let pad11Portrait = CGSize(width: 834, height: 1166)
    private let pad11Landscape = CGSize(width: 1210, height: 790)
    private let miniLandscape = CGSize(width: 1133, height: 700)

    /// A11Y-001: the default text size keeps the original point sizes.
    @Test func defaultTextSizeKeepsOriginalPointSizes() {
        let layout = MinimalLayout(viewportSize: phone, dynamicTypeSize: .large)

        #expect(layout.scaled(24, relativeTo: .title) == 24)
        #expect(layout.scaled(17, relativeTo: .body) == 17)
        #expect(layout.scaled(11.5, relativeTo: .caption) == 11.5)
        #expect(layout.usesSingleColumn == false)
    }

    /// A11Y-001: at AX3, titles and values render at least 1.5 times their default size.
    @Test func accessibilitySizesScaleTextAtLeast1_5x() {
        let large = MinimalLayout(viewportSize: phone, dynamicTypeSize: .large)
        let ax3 = MinimalLayout(viewportSize: phone, dynamicTypeSize: .accessibility3)

        #expect(ax3.scaled(24, relativeTo: .title) >= large.scaled(24, relativeTo: .title) * 1.5)
        #expect(ax3.scaled(17, relativeTo: .body) >= large.scaled(17, relativeTo: .body) * 1.5)
        #expect(ax3.scaled(11.5, relativeTo: .caption) >= large.scaled(11.5, relativeTo: .caption) * 1.5)
    }

    /// Large text switches to one column from xxxL, before the accessibility sizes.
    @Test func singleColumnStartsAtXXXL() {
        #expect(MinimalLayout(viewportSize: phone, dynamicTypeSize: .xxLarge).usesSingleColumn == false)
        #expect(MinimalLayout(viewportSize: phone, dynamicTypeSize: .xxxLarge).usesSingleColumn)
        #expect(MinimalLayout(viewportSize: phone, dynamicTypeSize: .accessibility5).usesSingleColumn)
    }

    /// iPad: every iPhone keeps the original composition, with nothing scaled.
    @Test func iPhonesKeepThePhoneComposition() {
        for size in [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874), CGSize(width: 440, height: 956)] {
            let layout = MinimalLayout(viewportSize: size, dynamicTypeSize: .large)
            #expect(layout.canvas == .phone)
            #expect(layout.canvasScale == 1)
            #expect(layout.space(34) == 34)
            #expect(layout.scaled(28, relativeTo: .title) == 28)
            #expect(layout.bottomBarMaxWidth == 520)
            #expect(layout.showsDetailsBeside == false)
        }
    }

    /// iPad: Slide Over and narrow Split View windows use the phone composition.
    @Test func narrowIPadWindowsUseThePhoneComposition() {
        #expect(MinimalLayout(viewportSize: CGSize(width: 320, height: 1332)).canvas == .phone)
        #expect(MinimalLayout(viewportSize: CGSize(width: 507, height: 1332)).canvas == .phone)
    }

    /// iPad: portrait windows scale the composition and keep the details toggle.
    @Test func iPadPortraitScalesTheComposition() {
        let layout = MinimalLayout(viewportSize: pad13Portrait, dynamicTypeSize: .large)

        #expect(layout.canvas == .large)
        #expect(layout.canvasScale == MinimalLayout.maximumCanvasScale)
        #expect(layout.scaled(28, relativeTo: .title) > 28 * 1.4)
        #expect(layout.scaled(12, relativeTo: .caption) > 12)
        #expect(layout.scaled(12, relativeTo: .caption) < layout.scaled(12, relativeTo: .title))
        #expect(layout.boundarySize.width > 142)
        #expect(MinimalLayout(viewportSize: pad11Portrait).canvas == .large)
    }

    /// iPad: wide windows show the details beside the summary, and everything fits.
    @Test func wideIPadWindowsSpreadTheDetails() {
        for size in [pad13Landscape, pad11Landscape] {
            let layout = MinimalLayout(viewportSize: size, dynamicTypeSize: .large)
            #expect(layout.canvas == .spread)
            #expect(layout.showsDetailsBeside)
            #expect(layout.detailSidebarWidth > 0)

            let textColumnsStart = size.width - layout.trailingInset - layout.detailSidebarWidth - layout.columnGap - layout.contentWidth
            #expect(layout.boundaryLeading >= layout.horizontalInset)
            #expect(layout.boundaryLeading + layout.boundarySize.width < textColumnsStart)

            // One row: the outline's zone, the summary, and the details fill the width exactly.
            let row = layout.horizontalInset + layout.geographyWidth + layout.boundaryGap
                + layout.contentWidth + layout.columnGap + layout.detailSidebarWidth + layout.trailingInset
            #expect(abs(row - size.width) < 0.001)
            #expect(layout.boundarySize.width <= layout.geographyWidth)
        }
    }

    /// iPad: a short window, such as iPad mini in landscape, takes turns instead.
    @Test func shortWideWindowsDoNotSpread() {
        #expect(MinimalLayout(viewportSize: miniLandscape).canvas == .large)
    }

    /// iPad: at the accessibility sizes, wide windows keep two columns without a spread,
    /// and narrower ones switch to one column.
    @Test func accessibilitySizesOnIPad() {
        let wide = MinimalLayout(viewportSize: pad13Landscape, dynamicTypeSize: .accessibility1)
        #expect(wide.canvas == .large)
        #expect(wide.usesSingleColumn == false)
        #expect(MinimalLayout(viewportSize: pad13Portrait, dynamicTypeSize: .accessibility5).usesSingleColumn == false)

        #expect(MinimalLayout(viewportSize: pad11Portrait, dynamicTypeSize: .xxxLarge).usesSingleColumn == false)
        #expect(MinimalLayout(viewportSize: pad11Portrait, dynamicTypeSize: .accessibility1).usesSingleColumn)
    }

    /// iPad: making text larger never makes any text smaller, for every style.
    @Test func canvasTextNeverShrinksAsTextSizeGrows() {
        let styles: [Font.TextStyle] = [.title, .title3, .body, .subheadline, .footnote, .caption, .caption2]
        for style in styles {
            var previous: CGFloat = 0
            for size in DynamicTypeSize.allCases {
                let value = MinimalLayout(viewportSize: pad13Portrait, dynamicTypeSize: size).scaled(20, relativeTo: style)
                #expect(value >= previous, "\(style) shrank at \(size)")
                previous = value
            }
        }
    }

    /// iPad: the canvas growth fades out at the largest sizes, which match iPhone.
    @Test func largestTextSizesMatchIPhone() {
        let pad = MinimalLayout(viewportSize: pad13Portrait, dynamicTypeSize: .accessibility3)
        let iPhone = MinimalLayout(viewportSize: phone, dynamicTypeSize: .accessibility3)

        #expect(abs(pad.scaled(17, relativeTo: .body) - iPhone.scaled(17, relativeTo: .body)) < 0.001)
    }
}
