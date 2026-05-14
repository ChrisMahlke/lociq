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
                .fill(Color.white.opacity(0.045))
                .frame(width: 260)
                .rotationEffect(.degrees(-31))
                .offset(x: 84, y: -150)

            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.035),
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
    static let lociqInk = Color(red: 0.075, green: 0.075, blue: 0.072)
}
