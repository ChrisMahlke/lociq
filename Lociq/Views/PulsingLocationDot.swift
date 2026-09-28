//
//  PulsingLocationDot.swift
//  Lociq
//
//  Renders the location marker inside the boundary glyph.
//
//  The marker is deliberately tiny. It indicates position within the city
//  boundary without turning the boundary preview into an interactive location
//  map. Its size follows the fix's real accuracy, and it never looks more
//  precise than the fix is.
//

import CoreLocation
import SwiftUI

/// How the location marker is drawn for one fix and glyph scale.
enum LocationMarkerStyle: Equatable {
    /// A small gold dot for a fix much smaller than the glyph's detail.
    case precise

    /// A static soft circle whose radius is the fix's uncertainty, in points.
    case area(radius: CGFloat)

    /// No marker: the fix is invalid, or its uncertainty covers the whole place.
    case hidden

    /// Largest uncertainty, in points, still drawn as a dot.
    static let preciseRadiusLimit: CGFloat = 7

    /// Chooses a marker for a fix.
    ///
    /// - Parameters:
    ///   - accuracyMeters: Fix accuracy in meters; `nil` when unknown (debug fixes).
    ///   - isApproximate: True for approximate location, which never gets a crisp dot.
    ///   - radiusPoints: Converts meters to glyph points at the fix's latitude.
    ///   - glyphSize: Size of the drawing, used to hide markers larger than the place.
    static func make(
        accuracyMeters: CLLocationAccuracy?,
        isApproximate: Bool,
        glyphSize: CGSize,
        radiusPoints: (Double) -> CGFloat
    ) -> LocationMarkerStyle {
        guard let accuracyMeters else { return isApproximate ? .hidden : .precise }
        guard accuracyMeters >= 0 else { return .hidden }
        let radius = radiusPoints(accuracyMeters)
        let largestUsefulRadius = min(glyphSize.width, glyphSize.height) / 2
        if !isApproximate, radius <= preciseRadiusLimit { return .precise }
        guard radius <= largestUsefulRadius else { return .hidden }
        return .area(radius: max(radius, preciseRadiusLimit))
    }
}

/// Location marker placed inside the projected boundary.
///
/// A precise fix draws a small gold dot that pulses twice when it appears, then
/// holds still: a single fix is not live tracking. An imprecise fix draws a
/// static soft circle the size of its uncertainty.
struct PulsingLocationDot: View {
    /// Marker style for the fix.
    let style: LocationMarkerStyle

    /// Accessibility reduced-motion flag.
    let reduceMotion: Bool

    /// Drives the brief ring pulse.
    @State private var isPulsing = false

    /// True once the pulses finish and the marker holds still.
    @State private var isSettled = false

    /// Renders the marker.
    var body: some View {
        switch style {
        case .precise:
            ZStack {
                Circle()
                    .fill(Color.lociqLocationTint.opacity(0.14))
                    .frame(width: 23, height: 23)

                if !isSettled, !reduceMotion {
                    Circle()
                        .stroke(Color.lociqLocationTint.opacity(isPulsing ? 0 : 0.72), lineWidth: 1.25)
                        .frame(width: 15, height: 15)
                        .scaleEffect(isPulsing ? 2.05 : 0.55)
                }

                // Resting ring, shown once the marker holds still.
                Circle()
                    .stroke(Color.lociqLocationTint.opacity(0.72), lineWidth: 1.25)
                    .frame(width: 8.25, height: 8.25)
                    .opacity(isSettled || reduceMotion ? 1 : 0)

                Circle()
                    .fill(Color.lociqLocationTint)
                    .frame(width: 5.8, height: 5.8)
            }
            .frame(width: 42, height: 42)
            .task {
                guard let animation = LociqMotion.pulse(reduceMotion: reduceMotion) else { return }
                withAnimation(animation) {
                    isPulsing = true
                }
                let pulseTime = LociqMotion.pulseDuration * Double(LociqMotion.pulseCount)
                try? await Task.sleep(nanoseconds: UInt64(pulseTime * 1_000_000_000))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    isSettled = true
                }
            }
        case .area(let radius):
            Circle()
                .fill(Color.lociqLocationTint.opacity(0.16))
                .overlay(Circle().stroke(Color.lociqLocationTint.opacity(0.42), lineWidth: 0.75))
                .frame(width: radius * 2, height: radius * 2)
        case .hidden:
            EmptyView()
        }
    }
}
