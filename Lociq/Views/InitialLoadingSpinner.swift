//
//  InitialLoadingSpinner.swift
//  Lociq
//
//  Renders the initial minimal loading indicator before profile data is ready.
//
//  The launch state shows motion and one stage line, never placeholder
//  numbers. This prevents users from reading fake demographic content while
//  location and Census services are still resolving, and tells them what the
//  wait is for.
//

import SwiftUI

/// Large thin spinner with a stage line, shown during the initial data wait.
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

        /// Seconds per fade cycle under Reduce Motion.
        static let fadeDuration: TimeInterval = 1.6
    }

    /// Canvas size used to choose a responsive spinner diameter.
    let canvasSize: CGSize

    /// Current stage, shown as one line under the spinner.
    let stage: WaitStage

    /// Layout metrics for the stage line's type.
    let layout: MinimalLayout

    /// Accessibility reduced-motion flag.
    var reduceMotion = false

    /// Drives the slow fade used instead of rotation under Reduce Motion.
    @State private var isDimmed = false

    /// Diameter derived from the smaller canvas dimension and clamped to a quiet range.
    private var spinnerSize: CGFloat {
        min(
            Constants.maximumSize,
            max(Constants.minimumSize, min(canvasSize.width, canvasSize.height) * 0.22)
        )
    }

    /// Renders the spinner and stage line.
    var body: some View {
        VStack(spacing: 28) {
            // The timeline pauses under Reduce Motion, so the arc stops
            // redrawing; a slow fade keeps the wait visibly in progress.
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { timeline in
                arc(rotation: reduceMotion ? 0 : rotationDegrees(at: timeline.date))
            }
            .frame(width: spinnerSize, height: spinnerSize)
            .opacity(isDimmed ? 0.4 : 1)
            .accessibilityHidden(true)

            Text(stage.label)
                .font(LociqTypeScale.stageLabel(layout))
                .foregroundStyle(Color.lociq(.status))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .animation(LociqMotion.quick(reduceMotion: reduceMotion), value: stage)
        }
        .padding(.horizontal, layout.horizontalInset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stage.spokenLabel)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("loading.stage")
        .task(id: reduceMotion) {
            guard reduceMotion else {
                isDimmed = false
                return
            }
            withAnimation(.easeInOut(duration: Constants.fadeDuration).repeatForever(autoreverses: true)) {
                isDimmed = true
            }
        }
    }

    /// The static track and trimmed arc at one rotation.
    private func arc(rotation: Double) -> some View {
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
