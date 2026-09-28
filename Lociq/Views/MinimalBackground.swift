//
//  MinimalBackground.swift
//  Lociq
//
//  Draws the restrained background used by the app shell.
//
//  The background carries the visual identity without adding content. It is
//  shared by the app surface and launch/loading states. The palette lives in
//  `LociqPalette.swift`, which the Apple Watch app shares.
//

import SwiftUI

/// Dark minimal background with a subtle diagonal light plane.
struct MinimalBackground: View {
    /// Whether the background should extend beyond safe areas.
    var ignoresSafeArea = true

    /// True on screens without data (first run, permission, failures), where
    /// the plane would otherwise be the largest shape and read as a wedge.
    var isSparse = false

    /// Growth of the plane on large iPad canvases, so it keeps its place in
    /// the composition. 1 on phones.
    var scale: CGFloat = 1

    /// Renders the background either safe-area-aware or full bleed.
    var body: some View {
        if ignoresSafeArea {
            content
                .ignoresSafeArea()
        } else {
            content
        }
    }

    /// The actual background drawing used by both safe-area modes.
    private var content: some View {
        ZStack {
            Color.lociqInk

            Rectangle()
                .fill(Color.lociqText.opacity(isSparse ? 0.022 : 0.045))
                .frame(width: 260 * scale)
                .rotationEffect(.degrees(-31))
                .offset(x: 84 * scale, y: -150 * scale)
        }
        .accessibilityHidden(true)
    }
}
