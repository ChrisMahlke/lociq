import SwiftUI

enum LociqMotion {
    static let quickDuration = 0.18
    static let contentDuration = 0.58
    static let settleDuration = 0.32
    static let boundaryTraceDuration = 2.2
    static let boundaryTraceDelay = 0.18
    static let connectorDuration = 1.05
    static let connectorDelay = 2.55
    static let pulseDuration = 1.75
    static let loadingSweepDuration = 0.82
    static let loadingSweepPauseNanoseconds: UInt64 = 860_000_000
    static let phaseDelay = 0.22
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

    /// Returns the loading sweep animation unless reduced motion is enabled.
    static func loadingSweep(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : loadingSweep
    }

    /// Returns the first phase delay adjusted for reduced-motion users.
    static func phaseDelay(reduceMotion: Bool) -> Double {
        reduceMotion ? 0.05 : phaseDelay
    }

    /// Returns the total content-cycle duration adjusted for reduced-motion users.
    static func contentCycleDuration(reduceMotion: Bool) -> Double {
        reduceMotion ? 0.18 : contentCycleDuration
    }
}
