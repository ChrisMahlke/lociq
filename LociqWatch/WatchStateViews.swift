//
//  WatchStateViews.swift
//  LociqWatch
//
//  Renders the watch app's waiting, permission, and failure screens.
//
//  These screens use the same copy as the iPhone app. The one difference is
//  location that is off: watchOS apps cannot open Settings, so the watch says
//  where to allow location instead of showing a button that cannot help.
//

import SwiftUI

/// The initial wait: a thin arc and one stage line, never placeholder numbers.
struct WatchWaitingView: View {
    let stage: WaitStage
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 12) {
            WatchSpinner(reduceMotion: reduceMotion)
                .frame(width: 44, height: 44)

            Text(stage.label)
                .font(WatchTypeScale.status)
                .foregroundStyle(Color.lociq(.status))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stage.spokenLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// Thin rotating arc, matching the iPhone's loading spinner.
///
/// Under Reduce Motion the arc stays still and fades slowly instead.
private struct WatchSpinner: View {
    let reduceMotion: Bool

    @State private var isDimmed = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            ZStack {
                Circle()
                    .stroke(Color.lociqText.opacity(0.13), lineWidth: 1.5)
                Circle()
                    .trim(from: 0.08, to: 0.78)
                    .stroke(
                        AngularGradient(
                            colors: [Color.lociqText.opacity(0.2), Color.lociqText.opacity(0.88), Color.lociqText.opacity(0.2)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(reduceMotion ? 0 : rotation(at: timeline.date)))
            }
        }
        .opacity(isDimmed ? 0.4 : 1)
        .accessibilityHidden(true)
        .task(id: reduceMotion) {
            guard reduceMotion else {
                isDimmed = false
                return
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                isDimmed = true
            }
        }
    }

    private func rotation(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.05) / 1.05 * 360
    }
}

/// Permission, location, and failure states: a heading, a line, and the one step that helps.
struct WatchMessageView: View {
    let snapshot: DemographicSnapshot
    let primaryAction: PrimaryAction
    let onPrimaryAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if primaryAction == .requestPermission {
                    firstRun
                } else {
                    message
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }

    /// First run: what the app shows, and the button that asks for location.
    private var firstRun: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                Text("CITY DEMOGRAPHICS")
                    .font(WatchTypeScale.messageTitle)
                    .foregroundStyle(Color.lociq(.primary))
                Text("FOR WHERE YOU ARE, FROM THE U.S. CENSUS BUREAU")
                    .font(WatchTypeScale.status)
                    .foregroundStyle(Color.lociq(.status))
            }
            .accessibilityElement(children: .combine)

            Button(action: onPrimaryAction) {
                Label {
                    Text("Allow Location")
                } icon: {
                    Image(systemName: "location")
                        .foregroundStyle(Color.lociqLocationTint)
                }
            }
            .accessibilityHint("Shows the system prompt. LOC IQ uses your location to find your city's Census data.")
        }
    }

    /// A location or data failure, with Try Again only when it can help.
    private var message: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.market)
                    .font(WatchTypeScale.messageTitle)
                    .foregroundStyle(Color.lociq(.primary))
                    .accessibilityAddTraits(.isHeader)
                if !snapshot.statusLine.isEmpty {
                    Text(snapshot.statusLine)
                        .font(WatchTypeScale.status)
                        .foregroundStyle(Color.lociq(.status))
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            switch primaryAction {
            case .retry:
                Button(action: onPrimaryAction) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .accessibilityHint("Attempts to load the city profile again")
            case .openSettings:
                Text("On this watch, open Settings, then Privacy & Security › Location Services › LOC IQ.")
                    .font(WatchTypeScale.detail)
                    .foregroundStyle(Color.lociq(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
            case .requestPermission, .toggleDetails, .none:
                EmptyView()
            }
        }
    }
}
