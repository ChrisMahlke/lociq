//
//  BoundaryCityConnectorLine.swift
//  Lociq
//
//  Draws the animated connector from the boundary center to the city label.
//

import SwiftUI

struct BoundaryCityConnectorLine: View {
    let start: CGPoint
    let end: CGPoint
    let traceToken: Int
    let reduceMotion: Bool
    @State private var progress: CGFloat = 0

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

private struct BoundaryCityConnectorShape: Shape {
    let start: CGPoint
    let end: CGPoint

    /// Draws a straight connector between the boundary and city label.
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}
