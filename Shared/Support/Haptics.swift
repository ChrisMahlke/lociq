//
//  Haptics.swift
//  Lociq
//
//  Provides small haptic feedback helpers for minimal UI interactions.
//
//  LOC IQ uses haptics as a quiet interaction cue. The helpers keep UIKit and
//  WatchKit feedback details out of SwiftUI views.
//

#if os(watchOS)
import WatchKit
#else
import UIKit
#endif

/// Thin wrapper around the platform's feedback generators.
///
/// Haptics are intentionally limited to explicit user actions: toggles, a
/// completed refresh, and the first profile the user asked for. Passive
/// loading, such as the refresh when the app opens, does not vibrate. Apple
/// Watch plays its lightest system haptic, the click, for the same moments.
enum Haptics {
    /// Plays the standard selection-change haptic for lightweight mode switches.
    ///
    /// Used by the home/details toggle and retry-style interactions.
    static func selectionChanged() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #else
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }

    /// Plays a soft impact haptic for subtle one-off confirmations.
    ///
    /// Used when a user-initiated refresh completes with fresh data.
    static func softImpact() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #else
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.8)
        #endif
    }

    /// Plays a very soft confirmation when the first user-requested city profile resolves.
    ///
    /// The view model guards this so it happens at most once per app session,
    /// and only after the user granted access or tapped Try Again.
    static func profileResolved() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #else
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.35)
        #endif
    }
}
