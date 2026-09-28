//
//  ProgressLine.swift
//  Lociq
//
//  Renders the minimal one-pixel loading line.
//
//  At rest the line is a neutral, uniform rule. While work is in progress a
//  short segment sweeps across it. The line never shows a partial fill, which
//  would read as progress that stopped.
//

import SwiftUI

/// One-pixel rule with a sweeping segment while loading.
struct ProgressLine: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Whether to show a sweeping loading segment.
    var isLoading = false

    /// Accessibility reduced-motion flag.
    var reduceMotion = false

    /// Horizontal loading segment offset expressed as a fraction of width.
    @State private var loadingOffset: CGFloat = -0.28

    /// Draws the rule plus the sweep while loading.
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.lociqText.opacity(reduceTransparency ? 0.48 : 0.30))
                    .frame(height: 1)

                if isLoading {
                    Rectangle()
                        .fill(Color.lociqText.opacity(reduceTransparency ? 0.92 : 0.78))
                        .frame(
                            width: reduceMotion ? geometry.size.width : max(68, geometry.size.width * 0.34),
                            height: 1
                        )
                        .offset(x: reduceMotion ? 0 : geometry.size.width * loadingOffset)
                        .transition(.opacity)
                }
            }
            .clipped()
        }
        .frame(height: 1)
        .task(id: isLoading) {
            // The task restarts when loading changes. It loops until SwiftUI
            // cancels it because the view disappeared or loading ended.
            guard isLoading else {
                loadingOffset = -0.28
                return
            }
            guard !reduceMotion else {
                loadingOffset = 0
                return
            }

            while !Task.isCancelled {
                // Reset slightly offscreen so the sweep appears to enter the line.
                loadingOffset = -0.28
                try? await Task.sleep(nanoseconds: 80_000_000)
                guard let animation = LociqMotion.loadingSweep(reduceMotion: reduceMotion) else { return }
                withAnimation(animation) {
                    // Move past the far edge so the segment exits cleanly.
                    loadingOffset = 1.02
                }
                try? await Task.sleep(nanoseconds: LociqMotion.loadingSweepPauseNanoseconds)
            }
        }
        .accessibilityHidden(true)
    }
}
