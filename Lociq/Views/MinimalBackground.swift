//
//  MinimalBackground.swift
//  Lociq
//
//  Draws the restrained dark background used by the app shell, and defines the palette.
//
//  The background carries the visual identity without adding content. It is
//  shared by the app surface, the iPad outer canvas, and launch/loading states.
//

import SwiftUI

/// Dark minimal background with a subtle diagonal light plane.
struct MinimalBackground: View {
    /// Whether the background should extend beyond safe areas.
    var ignoresSafeArea = true

    /// True on screens without data (first run, permission, failures), where
    /// the plane would otherwise be the largest shape and read as a wedge.
    var isSparse = false

    /// Renders the background either safe-area-aware or full bleed.
    var body: some View {
        if ignoresSafeArea {
            content
                .ignoresSafeArea()
        } else {
            content
        }
    }

    /// The actual background drawing used by both safe-area modes.
    private var content: some View {
        ZStack {
            Color.lociqInk

            Rectangle()
                .fill(Color.lociqText.opacity(isSparse ? 0.022 : 0.045))
                .frame(width: 260)
                .rotationEffect(.degrees(-31))
                .offset(x: 84, y: -150)
        }
        .accessibilityHidden(true)
    }
}

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
    /// Primary LOC IQ ink color used across the app and launch screen.
    static let lociqInk = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.075, green: 0.075, blue: 0.072, alpha: 1)
                : UIColor(red: 0.955, green: 0.955, blue: 0.948, alpha: 1)
        }
    )

    /// Primary foreground color, inverted by the selected theme.
    static let lociqText = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white
                : UIColor(red: 0.075, green: 0.075, blue: 0.072, alpha: 1)
        }
    )

    /// Text colors for each role, resolved per theme and contrast setting.
    fileprivate static let lociqRoleColors: [LociqTextRole: Color] = Dictionary(
        uniqueKeysWithValues: LociqTextRole.allCases.map { role in
            let opacities = role.opacities
            return (role, Color(
                UIColor { traits in
                    let isDark = traits.userInterfaceStyle == .dark
                    let isIncreased = traits.accessibilityContrast == .high
                    let base = isDark ? UIColor.white : UIColor(red: 0.075, green: 0.075, blue: 0.072, alpha: 1)
                    let alpha = isDark
                        ? (isIncreased ? opacities.darkIncreased : opacities.dark)
                        : (isIncreased ? opacities.lightIncreased : opacities.light)
                    return base.withAlphaComponent(alpha)
                }
            ))
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
        Color(
            UIColor { traits in
                let isIncreased = traits.accessibilityContrast == .high
                return traits.userInterfaceStyle == .dark
                    ? UIColor.white.withAlphaComponent(isIncreased ? darkIncreased : dark)
                    : UIColor(red: 0.075, green: 0.075, blue: 0.072, alpha: isIncreased ? lightIncreased : light)
            }
        )
    }

    /// Geography outline color tuned separately from text for light-mode legibility.
    static let lociqBoundaryStroke = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(traits.accessibilityContrast == .high ? 0.70 : 0.46)
                : UIColor(red: 0.075, green: 0.075, blue: 0.072, alpha: traits.accessibilityContrast == .high ? 0.86 : 0.68)
        }
    )

    /// Soft geography under-stroke that keeps thin lines readable in glare.
    static let lociqBoundaryHalo = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.14)
                : UIColor(red: 0.075, green: 0.075, blue: 0.072, alpha: 0.18)
        }
    )

    /// Faint connector color tuned separately from text for light-mode legibility.
    static let lociqBoundaryConnector = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.34)
                : UIColor(red: 0.075, green: 0.075, blue: 0.072, alpha: 0.54)
        }
    )

    /// Soft connector under-stroke that keeps the animated line visible outdoors.
    static let lociqBoundaryConnectorHalo = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.12)
                : UIColor(red: 0.075, green: 0.075, blue: 0.072, alpha: 0.16)
        }
    )

    /// Location accent that stays visible on both dark and light backgrounds.
    static let lociqLocationTint = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.0, green: 0.82, blue: 0.22, alpha: 1)
                : UIColor(red: 0.58, green: 0.36, blue: 0.0, alpha: 1)
        }
    )
}
