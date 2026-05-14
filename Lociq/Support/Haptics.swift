//
//  Haptics.swift
//  Lociq
//
//  Provides small haptic feedback helpers for minimal UI interactions.
//
//  LOC IQ uses haptics as a quiet interaction cue. The helpers keep UIKit
//  generator details out of SwiftUI views.
//

import UIKit

/// Thin wrapper around UIKit feedback generators.
///
/// Haptics are intentionally limited to explicit user actions or the first
/// successful profile resolution. Passive loading does not vibrate.
enum Haptics {
    /// Plays the standard selection-change haptic for lightweight mode switches.
    ///
    /// Used by the home/details toggle and retry-style interactions.
    static func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// Plays a soft impact haptic for subtle one-off confirmations.
    ///
    /// This is available for future interactions that need confirmation without
    /// adding visible UI.
    static func softImpact() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.8)
    }

    /// Plays a very soft confirmation when the first city profile resolves.
    ///
    /// The view model guards this so it happens at most once per app session.
    static func profileResolved() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.35)
    }
}
