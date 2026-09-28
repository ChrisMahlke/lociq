//
//  LociqThemePreference.swift
//  Lociq
//
//  Stores the user's appearance choice and applies it to the app's windows.
//

import SwiftUI
import UIKit

/// User-selectable app appearance.
///
/// Dark is the default and the product's identity. Light and Match System are
/// offered in the details footer, the context menu, and as accessibility
/// actions, so the choice is discoverable without a long press.
enum LociqThemePreference: String, CaseIterable, Identifiable {
    case dark
    case light
    case system

    var id: String { rawValue }

    /// SwiftUI color scheme for the root view; `nil` follows the system.
    ///
    /// Used together with `LociqAppearance.apply`: the SwiftUI preference
    /// takes effect on the first frame, and the window style guarantees a
    /// return to the system setting after an explicit choice.
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }

    /// Interface style applied to the app's windows.
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return .unspecified
        }
    }

    /// Short label for the footer and menus.
    var label: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .system: return "Match System"
        }
    }

    /// SF Symbol for menus.
    var iconName: String {
        switch self {
        case .dark: return "moon"
        case .light: return "sun.max"
        case .system: return "circle.lefthalf.filled"
        }
    }

    /// Accessibility action name for choosing this appearance.
    var accessibilityActionName: String {
        switch self {
        case .dark: return "Use dark appearance"
        case .light: return "Use light appearance"
        case .system: return "Match system appearance"
        }
    }
}

/// Applies the appearance choice to every window of the app.
///
/// Setting the window's interface style, rather than `preferredColorScheme`,
/// lets "Match System" return reliably to the system setting at runtime, and
/// keeps UIKit-presented UI such as the share sheet in the same appearance.
enum LociqAppearance {
    /// Applies a preference, cross-fading unless Reduce Motion is on.
    @MainActor
    static func apply(_ preference: LociqThemePreference, animated: Bool, reduceMotion: Bool) {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows where window.overrideUserInterfaceStyle != preference.interfaceStyle {
            guard animated, !reduceMotion else {
                window.overrideUserInterfaceStyle = preference.interfaceStyle
                continue
            }
            UIView.transition(
                with: window,
                duration: LociqMotion.themeToggleDuration,
                options: [.transitionCrossDissolve, .allowUserInteraction]
            ) {
                window.overrideUserInterfaceStyle = preference.interfaceStyle
            }
        }
    }
}
