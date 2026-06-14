//
//  LociqMotion.swift
//  Lociq
//
//  Centralizes animation timings and reduced-motion variants.
//
//  Minimal UI depends heavily on timing. This file keeps durations and
//  reduced-motion behavior consistent across boundary tracing, content swaps,
//  loading lines, and location pulses.
//

import SwiftUI

/// Shared motion constants and helpers for the LOC IQ interface.
enum LociqMotion {
    /// Fast duration for icon and small opacity changes.
    static let quickDuration = 0.18

    /// Primary content transition duration.
    static let contentDuration = 0.58

    /// Duration used when settling after a staged interaction.
    static let settleDuration = 0.32

    /// Duration for tracing the city boundary.
    static let boundaryTraceDuration = 2.2

    /// Delay before boundary tracing starts.
    static let boundaryTraceDelay = 0.18

    /// Duration for the boundary-to-city connector line.
    static let connectorDuration = 1.05

    /// Delay that lets the boundary finish before the connector appears.
    static let connectorDelay = 2.55

    /// Duration for one approximate-location pulse cycle.
    static let pulseDuration = 1.75

    /// Duration for one missing-permission icon pulse.
    static let permissionPulseDuration = 0.95

    /// Pause between missing-permission icon pulses.
    static let permissionPulsePauseNanoseconds: UInt64 = 260_000_000

    /// Duration for one loading-line sweep.
    static let loadingSweepDuration = 0.82

    /// Pause between loading-line sweeps.
    static let loadingSweepPauseNanoseconds: UInt64 = 520_000_000

    /// Delay before first loaded content begins revealing.
    static let firstDataRevealDelay = 0.28

    /// Duration for first loaded content reveal.
    static let firstDataRevealDuration = 0.44

    /// Delay between boundary reveal and content reveal.
    static let contentRevealAfterBoundaryDelay = 1.45

    /// Delay before the approximate-location dot appears.
    static let locationDotRevealDelay = 1.9

    /// Duration for approximate-location dot reveal.
    static let locationDotRevealDuration = 0.38

    /// Delay between content-cycle phases.
    static let phaseDelay = 0.22

    /// Total duration during which the content-cycle loading line remains active.
    static let contentCycleDuration = 1.05

    /// Standard quick animation for small state changes.
    static var quick: Animation { .easeInOut(duration: quickDuration) }
    /// Standard content animation for view swaps.
    static var content: Animation { .easeInOut(duration: contentDuration) }
    /// Standard settling animation after a content swap.
    static var settle: Animation { .easeInOut(duration: settleDuration) }
    /// Boundary tracing animation.
    static var boundaryTrace: Animation { .easeInOut(duration: boundaryTraceDuration).delay(boundaryTraceDelay) }
    /// Connector-line tracing animation.
    static var connector: Animation { .easeOut(duration: connectorDuration).delay(connectorDelay) }
    /// Approximate-location pulse animation.
    static var pulse: Animation { .easeOut(duration: pulseDuration).repeatForever(autoreverses: false) }
    /// Missing-permission icon pulse animation.
    static var permissionPulse: Animation { .easeOut(duration: permissionPulseDuration) }
    /// Loading-line sweep animation.
    static var loadingSweep: Animation { .linear(duration: loadingSweepDuration) }

    /// Returns the quick animation adjusted for reduced-motion users.
    static func quick(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : quick
    }

    /// Returns the content transition animation adjusted for reduced-motion users.
    static func content(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.12) : content
    }

    /// Returns the settle animation adjusted for reduced-motion users.
    static func settle(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : settle
    }

    /// Returns the boundary trace animation unless reduced motion is enabled.
    static func boundaryTrace(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : boundaryTrace
    }

    /// Returns the connector trace animation unless reduced motion is enabled.
    static func connector(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : connector
    }

    /// Returns the location pulse animation unless reduced motion is enabled.
    static func pulse(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : pulse
    }

    /// Returns the missing-permission icon pulse animation unless reduced motion is enabled.
    static func permissionPulse(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : permissionPulse
    }

    /// Returns the loading sweep animation unless reduced motion is enabled.
    static func loadingSweep(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : loadingSweep
    }

    /// Returns the total content-cycle duration adjusted for reduced-motion users.
    static func contentCycleDuration(reduceMotion: Bool) -> Double {
        reduceMotion ? 0.18 : contentCycleDuration
    }

    /// Returns the first phase delay adjusted for reduced-motion users.
    static func phaseDelay(reduceMotion: Bool) -> Double {
        reduceMotion ? 0.05 : phaseDelay
    }

    /// Returns the first-data reveal delay adjusted for reduced-motion users.
    static func firstDataRevealDelay(reduceMotion: Bool) -> Double {
        reduceMotion ? 0.04 : firstDataRevealDelay
    }

    /// Returns the first-data reveal animation adjusted for reduced-motion users.
    static func firstDataReveal(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: firstDataRevealDuration)
    }

    /// Returns the delay between boundary reveal and content reveal.
    static func contentRevealAfterBoundaryDelay(reduceMotion: Bool) -> Double {
        reduceMotion ? 0.04 : contentRevealAfterBoundaryDelay
    }

    /// Returns the approximate-location reveal delay adjusted for reduced-motion users.
    static func locationDotRevealDelay(reduceMotion: Bool) -> Double {
        reduceMotion ? 0.04 : locationDotRevealDelay
    }

    /// Returns the approximate-location reveal animation adjusted for reduced-motion users.
    static func locationDotReveal(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: locationDotRevealDuration)
    }
}
