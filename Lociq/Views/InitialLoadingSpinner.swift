//
//  InitialLoadingSpinner.swift
//  Lociq
//
//  Renders the initial minimal loading indicator before profile data is ready.
//
//  The launch state intentionally shows only motion, not placeholder strings.
//  This prevents users from reading fake demographic content while location and
//  Census services are still resolving.
//

import SwiftUI

/// Large thin spinner shown during the initial data wait.
struct InitialLoadingSpinner: View {
    /// Visual constants for the quiet circular loader.
    private enum Constants {
        /// Stroke width in points.
        static let lineWidth: CGFloat = 2

        /// Smallest spinner diameter.
        static let minimumSize: CGFloat = 108

        /// Largest spinner diameter.
        static let maximumSize: CGFloat = 148

        /// Start of the visible trimmed arc.
        static let visibleArcStart = 0.08

        /// End of the visible trimmed arc.
        static let visibleArcEnd = 0.78

        /// Seconds per full rotation.
        static let rotationDuration: TimeInterval = 1.05
    }

    /// Canvas size used to choose a responsive spinner diameter.
    let canvasSize: CGSize

    /// Accessibility reduced-motion flag.
    var reduceMotion = false

    /// Diameter derived from the smaller canvas dimension and clamped to a quiet range.
    private var spinnerSize: CGFloat {
        min(
            Constants.maximumSize,
            max(Constants.minimumSize, min(canvasSize.width, canvasSize.height) * 0.22)
        )
    }

    /// Renders the static track and rotating trimmed arc.
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let rotation = reduceMotion ? 0 : rotationDegrees(at: timeline.date)

            ZStack {
                Circle()
                    .stroke(
                        Color.lociqText.opacity(0.13),
                        lineWidth: Constants.lineWidth
                    )

                Circle()
                    .trim(from: Constants.visibleArcStart, to: Constants.visibleArcEnd)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.lociqText.opacity(0.20),
                                Color.lociqText.opacity(0.88),
                                Color.lociqText.opacity(0.20)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(
                            lineWidth: Constants.lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .rotationEffect(.degrees(rotation))
            }
            .frame(width: spinnerSize, height: spinnerSize)
            .accessibilityLabel("Loading")
        }
    }

    /// Returns a deterministic rotation angle for the current animation time.
    ///
    /// `TimelineView` provides dates rather than mutable animation state. Using
    /// reference time keeps the spinner smooth and deterministic.
    private func rotationDegrees(at date: Date) -> Double {
        let progress = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: Constants.rotationDuration)
            / Constants.rotationDuration
        return progress * 360
    }
}
