//
//  MetricBar.swift
//  Lociq
//
//  Draws the thin percentage bar used by the owner-occupied and education metrics.
//
//  The bar is drawn from the same rounded percentage the text shows, so the
//  graphic and the number never disagree. It is shared by the iPhone, iPad,
//  and Apple Watch apps.
//

import SwiftUI

/// Thin horizontal bar: a faint full-width track and a quiet fill.
struct MetricBar: View {
    /// Filled share in `0...1`.
    let fraction: Double

    /// Uses stronger contrast (Reduce Transparency).
    let isEmphasized: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.lociqBarTrack(emphasized: isEmphasized))
                Rectangle()
                    .fill(Color.lociqBarFill(emphasized: isEmphasized))
                    .frame(width: geometry.size.width * fraction)
            }
        }
        .accessibilityHidden(true)
    }
}
