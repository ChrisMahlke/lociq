//
//  LociqThemePreference.swift
//  Lociq
//
//  Stores the user's explicit light or dark appearance choice.
//

import SwiftUI

/// User-selectable app appearance.
enum LociqThemePreference: String {
    case dark
    case light

    /// SwiftUI color scheme applied to the root view.
    var colorScheme: ColorScheme {
        switch self {
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }

    /// Theme selected by the single appearance toggle.
    var toggled: LociqThemePreference {
        switch self {
        case .dark:
            return .light
        case .light:
            return .dark
        }
    }

    /// Icon for the target appearance.
    var toggleIconName: String {
        switch self {
        case .dark:
            return "sun.max"
        case .light:
            return "moon"
        }
    }

    /// Accessibility label for the target appearance.
    var toggleAccessibilityLabel: String {
        switch self {
        case .dark:
            return "Switch to light theme"
        case .light:
            return "Switch to dark theme"
        }
    }
}
