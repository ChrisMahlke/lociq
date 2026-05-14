//
//  BoundaryCityConnectorLine.swift
//  Lociq
//
//  Draws the animated connector from the boundary center to the city label.
//
//  The connector is intentionally faint. It briefly explains the relationship
//  between the boundary glyph and the city title without becoming a permanent
//  visual element.
//

import SwiftUI

/// One-shot animated line connecting the boundary center to the city label.
struct BoundaryCityConnectorLine: View {
    /// Start point in root view coordinates.
    let start: CGPoint

    /// End point near the city label baseline.
    let end: CGPoint

    /// Token that restarts the animation when a new boundary is loaded.
    let traceToken: Int

    /// Accessibility reduced-motion flag.
    let reduceMotion: Bool

    /// Current trim progress for the line.
    @State private var progress: CGFloat = 0

    /// Draws and animates the connector shape.
    var body: some View {
        BoundaryCityConnectorShape(start: start, end: end)
            .trim(from: 0, to: progress)
            .stroke(
                Color.white.opacity(0.16),
                style: StrokeStyle(lineWidth: 0.7, lineCap: .round)
            )
            .onAppear {
                traceConnector()
            }
            .onChange(of: traceToken) { _ in
                traceConnector()
            }
    }

    /// Restarts the one-time connector line animation.
    ///
    /// Reduced-motion users receive the completed line immediately instead of a
    /// delayed trace animation.
    private func traceConnector() {
        withAnimation(.none) {
            progress = reduceMotion ? 1 : 0
        }

        guard let animation = LociqMotion.connector(reduceMotion: reduceMotion) else { return }
        withAnimation(animation) {
            progress = 1
        }
    }
}

/// Shape that renders a straight line between two points.
private struct BoundaryCityConnectorShape: Shape {
    /// Start point in the parent coordinate space.
    let start: CGPoint

    /// End point in the parent coordinate space.
    let end: CGPoint

    /// Draws a straight connector between the boundary and city label.
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}
