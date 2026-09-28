//
//  MinimalLayoutTests.swift
//  LociqTests
//
//  Verifies Dynamic Type scaling and the single-column switch.
//

import SwiftUI
import Testing
@testable import Lociq

@MainActor
/// Tests for `MinimalLayout` text scaling.
struct MinimalLayoutTests {
    private let phone = CGSize(width: 375, height: 667)

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
}
