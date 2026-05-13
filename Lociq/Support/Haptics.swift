//
//  Haptics.swift
//  Lociq
//
//  Provides small haptic feedback helpers for minimal UI interactions.
//

import UIKit

enum Haptics {
    /// Plays the standard selection-change haptic for lightweight mode switches.
    static func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// Plays a soft impact haptic for subtle one-off confirmations.
    static func softImpact() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.8)
    }
}
