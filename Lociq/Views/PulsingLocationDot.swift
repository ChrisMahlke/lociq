//
//  PulsingLocationDot.swift
//  Lociq
//
//  Renders the approximate in-boundary location marker.
//
//  The marker is deliberately tiny. It indicates approximate position within
//  the city boundary without turning the boundary preview into an interactive
//  location map.
//

import CoreLocation
import SwiftUI

/// Visual style for the approximate-location dot derived from accuracy.
///
/// Less accurate locations use a larger, softer ring. Extremely poor accuracy
/// hides the marker so the app does not overstate precision.
struct LocationDotStyle {
    /// Opacity of the center dot.
    let tintOpacity: Double

    /// Initial opacity of the pulsing ring.
    let ringOpacity: Double

    /// Diameter of the center dot.
    let coreDiameter: CGFloat

    /// Starting diameter of the ring.
    let ringDiameter: CGFloat

    /// Maximum pulse scale applied to the ring.
    let pulseScale: CGFloat

    /// Whether the marker should be rendered.
    let isVisible: Bool

    /// Derives dot and ring appearance from Core Location horizontal accuracy.
    ///
    /// The thresholds keep the marker visible for typical city-level accuracy
    /// while avoiding false precision for very broad approximate locations.
    init(accuracy: CLLocationAccuracy?) {
        guard let accuracy, accuracy >= 0 else {
            tintOpacity = 0.96
            ringOpacity = 0.62
            coreDiameter = 5.2
            ringDiameter = 16
            pulseScale = 2.25
            isVisible = true
            return
        }

        if accuracy <= 100 {
            tintOpacity = 1
            ringOpacity = 0.72
            coreDiameter = 5.8
            ringDiameter = 15
            pulseScale = 2.05
            isVisible = true
        } else if accuracy <= 1_000 {
            tintOpacity = 0.92
            ringOpacity = 0.56
            coreDiameter = 5.2
            ringDiameter = 17
            pulseScale = 2.45
            isVisible = true
        } else if accuracy <= 5_000 {
            tintOpacity = 0.78
            ringOpacity = 0.40
            coreDiameter = 4.6
            ringDiameter = 19
            pulseScale = 2.9
            isVisible = true
        } else {
            tintOpacity = 0.78
            ringOpacity = 0.40
            coreDiameter = 4.6
            ringDiameter = 19
            pulseScale = 2.9
            isVisible = false
        }
    }
}

/// Animated approximate-location marker placed inside the projected boundary.
struct PulsingLocationDot: View {
    /// Style derived from Core Location accuracy.
    let style: LocationDotStyle

    /// Accessibility reduced-motion flag.
    let reduceMotion: Bool

    /// Drives the repeating ring scale and fade.
    @State private var isPulsing = false

    /// Renders the pulsing ring and center dot.
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.lociqLocationTint.opacity(0.14))
                .frame(width: style.ringDiameter + 8, height: style.ringDiameter + 8)

            Circle()
                .stroke(Color.lociqLocationTint.opacity(isPulsing ? 0.0 : style.ringOpacity), lineWidth: 1.25)
                .frame(width: style.ringDiameter, height: style.ringDiameter)
                .scaleEffect(isPulsing ? style.pulseScale : 0.55)

            Circle()
                .fill(Color.lociqLocationTint.opacity(style.tintOpacity))
                .frame(width: style.coreDiameter, height: style.coreDiameter)
        }
        .frame(width: 42, height: 42)
        .onAppear {
            guard let animation = LociqMotion.pulse(reduceMotion: reduceMotion) else { return }
            withAnimation(animation) {
                isPulsing.toggle()
            }
        }
    }
}
