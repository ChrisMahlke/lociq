//
//  LociqPalette.swift
//  Lociq
//
//  Defines the LOC IQ palette: ink, text roles, bars, geography, and the accent.
//
//  Colors are shared by the iPhone, iPad, and Apple Watch apps. On iOS each
//  color resolves per appearance and Increase Contrast. watchOS has no light
//  appearance and no trait-based colors, so it always uses the dark variant,
//  which is the product's original look.
//

import SwiftUI
import UIKit

/// Text roles with theme- and contrast-specific opacities.
///
/// Every role meets 4.5:1 against the background, including over the diagonal
/// plane, in both themes. With Increase Contrast on, each role gains at least
/// three contrast ratio points. The dark values are unchanged from the
/// original design; the light theme needed higher values.
enum LociqTextRole: CaseIterable {
    /// Titles and values.
    case primary

    /// The LOC IQ wordmark.
    case brand

    /// Summary metric labels such as `POPULATION`.
    case metricLabel

    /// Metric definitions and the density label.
    case secondary

    /// The "DATA" hint and bottom icons.
    case hint

    /// Details row labels.
    case detailLabel

    /// Details section titles.
    case sectionTitle

    /// Header status line.
    case status

    /// Density value.
    case densityValue

    /// Details row values.
    case detailValue

    /// Opacity of the text color for each theme and contrast setting.
    fileprivate var opacities: (dark: CGFloat, light: CGFloat, darkIncreased: CGFloat, lightIncreased: CGFloat) {
        switch self {
        case .primary: return (1, 1, 1, 1)
        case .brand: return (0.74, 0.74, 0.90, 0.90)
        case .metricLabel: return (0.78, 0.78, 0.90, 0.90)
        case .secondary: return (0.54, 0.64, 0.74, 0.80)
        case .hint: return (0.58, 0.64, 0.78, 0.80)
        case .detailLabel: return (0.58, 0.68, 0.78, 0.82)
        case .sectionTitle: return (0.51, 0.64, 0.74, 0.80)
        case .status: return (0.68, 0.70, 0.84, 0.86)
        case .densityValue: return (0.72, 0.74, 0.88, 0.88)
        case .detailValue: return (0.78, 0.80, 0.92, 0.92)
        }
    }

    /// Resolved color for the role.
    var color: Color {
        Color.lociqRoleColors[self] ?? Color.lociqText
    }
}

extension Color {
    /// Near-black ink of the dark appearance, with an alpha; also the light appearance's text.
    ///
    /// Nonisolated because colors resolve inside `@Sendable` providers.
    nonisolated private static func ink(alpha: CGFloat) -> UIColor {
        UIColor(red: 0.075, green: 0.075, blue: 0.072, alpha: alpha)
    }

    /// Resolves a color per appearance and contrast setting.
    ///
    /// iOS and iPadOS pick the variant for the current trait collection, so
    /// the color follows the appearance choice and Increase Contrast. watchOS
    /// always uses the dark, standard-contrast variant.
    ///
    /// - Parameter resolve: Returns the color for `isDark` and `isIncreased`
    ///   (Increase Contrast).
    nonisolated static func lociqResolved(_ resolve: @escaping @Sendable (_ isDark: Bool, _ isIncreased: Bool) -> UIColor) -> Color {
        #if os(watchOS)
        return Color(resolve(true, false))
        #else
        return Color(
            UIColor { traits in
                resolve(traits.userInterfaceStyle == .dark, traits.accessibilityContrast == .high)
            }
        )
        #endif
    }

    /// Primary LOC IQ ink color used across the app and launch screen.
    static let lociqInk = lociqResolved { isDark, _ in
        isDark
            ? ink(alpha: 1)
            : UIColor(red: 0.955, green: 0.955, blue: 0.948, alpha: 1)
    }

    /// Primary foreground color, inverted by the selected theme.
    static let lociqText = lociqResolved { isDark, _ in
        isDark ? UIColor.white : ink(alpha: 1)
    }

    /// Text colors for each role, resolved per theme and contrast setting.
    fileprivate static let lociqRoleColors: [LociqTextRole: Color] = Dictionary(
        uniqueKeysWithValues: LociqTextRole.allCases.map { role in
            let opacities = role.opacities
            return (role, lociqResolved { isDark, isIncreased in
                isDark
                    ? UIColor.white.withAlphaComponent(isIncreased ? opacities.darkIncreased : opacities.dark)
                    : ink(alpha: isIncreased ? opacities.lightIncreased : opacities.light)
            })
        }
    )

    /// Returns the color for a text role.
    static func lociq(_ role: LociqTextRole) -> Color {
        role.color
    }

    /// Bar track, quiet but visible enough to define 100%.
    ///
    /// - Parameter emphasized: Forces the higher-contrast values, for
    ///   Reduce Transparency. Increase Contrast applies them automatically.
    static func lociqBarTrack(emphasized: Bool = false) -> Color {
        emphasized ? barTrackEmphasized : barTrack
    }

    /// Bar fill, at least 3:1 against its track in both themes.
    static func lociqBarFill(emphasized: Bool = false) -> Color {
        emphasized ? barFillEmphasized : barFill
    }

    private static let barTrack = contrastAware(dark: 0.13, light: 0.20, darkIncreased: 0.26, lightIncreased: 0.30)
    private static let barTrackEmphasized = contrastAware(dark: 0.26, light: 0.30, darkIncreased: 0.26, lightIncreased: 0.30)
    private static let barFill = contrastAware(dark: 0.48, light: 0.60, darkIncreased: 0.72, lightIncreased: 0.80)
    private static let barFillEmphasized = contrastAware(dark: 0.72, light: 0.80, darkIncreased: 0.72, lightIncreased: 0.80)

    /// Text-colored fill whose opacity follows the theme and the contrast setting.
    static func contrastAware(dark: CGFloat, light: CGFloat, darkIncreased: CGFloat, lightIncreased: CGFloat) -> Color {
        lociqResolved { isDark, isIncreased in
            isDark
                ? UIColor.white.withAlphaComponent(isIncreased ? darkIncreased : dark)
                : ink(alpha: isIncreased ? lightIncreased : light)
        }
    }

    /// Geography outline color tuned separately from text for light-mode legibility.
    static let lociqBoundaryStroke = lociqResolved { isDark, isIncreased in
        isDark
            ? UIColor.white.withAlphaComponent(isIncreased ? 0.70 : 0.46)
            : ink(alpha: isIncreased ? 0.86 : 0.68)
    }

    /// Soft geography under-stroke that keeps thin lines readable in glare.
    static let lociqBoundaryHalo = lociqResolved { isDark, _ in
        isDark ? UIColor.white.withAlphaComponent(0.14) : ink(alpha: 0.18)
    }

    /// Faint connector color tuned separately from text for light-mode legibility.
    static let lociqBoundaryConnector = lociqResolved { isDark, _ in
        isDark ? UIColor.white.withAlphaComponent(0.34) : ink(alpha: 0.54)
    }

    /// Soft connector under-stroke that keeps the animated line visible outdoors.
    static let lociqBoundaryConnectorHalo = lociqResolved { isDark, _ in
        isDark ? UIColor.white.withAlphaComponent(0.12) : ink(alpha: 0.16)
    }

    /// Location accent that stays visible on both dark and light backgrounds.
    static let lociqLocationTint = lociqResolved { isDark, _ in
        isDark
            ? UIColor(red: 1.0, green: 0.82, blue: 0.22, alpha: 1)
            : UIColor(red: 0.58, green: 0.36, blue: 0.0, alpha: 1)
    }
}
