//
//  PulsingLocationDot.swift
//  Lociq
//
//  Renders the approximate in-boundary location marker.
//

import CoreLocation
import SwiftUI

struct LocationDotStyle {
    let tintOpacity: Double
    let ringOpacity: Double
    let coreDiameter: CGFloat
    let ringDiameter: CGFloat
    let pulseScale: CGFloat
    let isVisible: Bool

    /// Derives dot and ring appearance from Core Location horizontal accuracy.
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

struct PulsingLocationDot: View {
    let style: LocationDotStyle
    let reduceMotion: Bool
    @State private var isPulsing = false
    private let locationTint = Color(red: 1.0, green: 0.82, blue: 0.22)

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
