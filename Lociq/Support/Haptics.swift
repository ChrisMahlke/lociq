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
/// Haptics are intentionally limited to explicit user actions: toggles, a
/// completed refresh, and the first profile the user asked for. Passive
/// loading, such as the refresh when the app opens, does not vibrate.
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
    /// Used when a user-initiated refresh completes with fresh data.
    static func softImpact() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.8)
    }

    /// Plays a very soft confirmation when the first user-requested city profile resolves.
    ///
    /// The view model guards this so it happens at most once per app session,
    /// and only after the user granted access or tapped Try Again.
    static func profileResolved() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.35)
    }
}
