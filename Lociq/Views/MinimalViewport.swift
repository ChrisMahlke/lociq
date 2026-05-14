//
//  MinimalViewport.swift
//  Lociq
//
//  Constrains large screens to the same minimal composition used on iPhone.
//
//  Supporting iPad does not mean creating a different dashboard-style tablet
//  UI. This helper centers the same phone-sized composition inside the larger
//  canvas so the product remains visually identical.
//

import SwiftUI

/// Computes the rendered app surface inside the available device screen.
///
/// On iPhone, the viewport is the full screen. On iPad, the viewport is capped
/// to a phone-like size and centered by `ContentView`.
struct MinimalViewport {
    /// Constants that define when and how the surface is constrained.
    private enum Constants {
        /// Shortest side threshold used to classify a tablet-sized canvas.
        static let tabletMinimumShortestSide: CGFloat = 600

        /// Maximum width of the phone-style app surface on iPad.
        static let maximumPhoneWidth: CGFloat = 430

        /// Maximum height of the phone-style app surface on iPad.
        static let maximumPhoneHeight: CGFloat = 932
    }

    /// Size of the rendered app surface.
    let size: CGSize

    /// Safe-area insets passed into `MinimalLayout`.
    let safeAreaInsets: EdgeInsets

    /// Creates a phone-style viewport inside the available screen.
    ///
    /// iPad uses zero safe-area insets inside the constrained surface because
    /// the surface itself is centered on a larger safe canvas.
    init(geometry: GeometryProxy) {
        let availableSize = geometry.size
        let isTabletCanvas = min(availableSize.width, availableSize.height) >= Constants.tabletMinimumShortestSide

        if isTabletCanvas {
            size = CGSize(
                width: min(availableSize.width, Constants.maximumPhoneWidth),
                height: min(availableSize.height, Constants.maximumPhoneHeight)
            )
            safeAreaInsets = EdgeInsets()
        } else {
            size = availableSize
            safeAreaInsets = geometry.safeAreaInsets
        }
    }
}
