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
            tintOpacity = 0.86
            ringOpacity = 0.38
            coreDiameter = 3.2
            ringDiameter = 12
            pulseScale = 2.1
            isVisible = true
            return
        }

        if accuracy <= 100 {
            tintOpacity = 0.95
            ringOpacity = 0.52
            coreDiameter = 3.8
            ringDiameter = 10
            pulseScale = 1.85
            isVisible = true
        } else if accuracy <= 1_000 {
            tintOpacity = 0.82
            ringOpacity = 0.34
            coreDiameter = 3.2
            ringDiameter = 13
            pulseScale = 2.35
            isVisible = true
        } else if accuracy <= 5_000 {
            tintOpacity = 0.64
            ringOpacity = 0.22
            coreDiameter = 2.8
            ringDiameter = 15
            pulseScale = 2.75
            isVisible = true
        } else {
            tintOpacity = 0.64
            ringOpacity = 0.22
            coreDiameter = 2.8
            ringDiameter = 15
            pulseScale = 2.75
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

    /// Yellow location accent used consistently with the app icon.
    private let locationTint = Color(red: 1.0, green: 0.82, blue: 0.22)

    /// Renders the pulsing ring and center dot.
    var body: some View {
        ZStack {
            Circle()
                .stroke(locationTint.opacity(isPulsing ? 0.0 : style.ringOpacity), lineWidth: 0.8)
                .frame(width: style.ringDiameter, height: style.ringDiameter)
                .scaleEffect(isPulsing ? style.pulseScale : 0.55)

            Circle()
                .fill(locationTint.opacity(style.tintOpacity))
                .frame(width: style.coreDiameter, height: style.coreDiameter)
        }
        .frame(width: 30, height: 30)
        .onAppear {
            guard let animation = LociqMotion.pulse(reduceMotion: reduceMotion) else { return }
            withAnimation(animation) {
                isPulsing.toggle()
            }
        }
    }
}
