//
//  MinimalBackground.swift
//  Lociq
//
//  Draws the restrained dark background used by the app shell.
//
//  The background carries the visual identity without adding content. It is
//  shared by the app surface, the iPad outer canvas, and launch/loading states.
//

import SwiftUI

/// Dark minimal background with a subtle diagonal light plane.
struct MinimalBackground: View {
    /// Whether the background should extend beyond safe areas.
    var ignoresSafeArea = true

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
                .fill(Color.lociqText.opacity(0.045))
                .frame(width: 260)
                .rotationEffect(.degrees(-31))
                .offset(x: 84, y: -150)

            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        .clear,
                        Color.lociqText.opacity(0.035),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 142)
            }
        }
        .accessibilityHidden(true)
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

    /// Geography outline color tuned separately from text for light-mode legibility.
    static let lociqBoundaryStroke = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.46)
                : UIColor(red: 0.075, green: 0.075, blue: 0.072, alpha: 0.68)
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
