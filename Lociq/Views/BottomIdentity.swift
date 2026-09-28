//
//  BottomIdentity.swift
//  Lociq
//
//  Renders the LOC IQ mark, bottom actions, and loading line.
//
//  This is the only persistent control area in the app. It carries brand,
//  loading feedback, the single primary action, refresh and share, and a
//  context menu for secondary actions without adding visible chrome.
//

import SwiftUI

/// Bottom brand and action surface for the minimal interface.
///
/// One primary button represents the current primary action: the
/// summary/details toggle when data is shown, otherwise the one step that
/// helps (allow location, open Settings, or try again). Actions are typed, so
/// the view never inspects display strings to decide what a tap does.
struct BottomIdentity: View {
    @AppStorage("lociq.hasDiscoveredDataView") private var hasDiscoveredDataView = false
    @Environment(\.accessibilityShowButtonShapes) private var showButtonShapes

    /// Current demographic display snapshot.
    let snapshot: DemographicSnapshot

    /// Whether the details view is currently visible.
    let isShowingDetails: Bool

    /// Whether a location or profile request is in flight (drives the loading line).
    let isBusy: Bool

    /// Whether the summary/details swap is mid-animation.
    let isInteractionLocked: Bool

    /// Whether the initial spinner-only state is active.
    let isWaitingForInitialData: Bool

    /// What the primary button does.
    let primaryAction: PrimaryAction

    /// What the refresh button does.
    let refreshControl: RefreshControl

    /// Optional share payload.
    let shareText: String?

    /// Whether the summary/details toggle shows. It is hidden when the
    /// details are already beside the summary, on a wide iPad window.
    let showsDetailsToggle: Bool

    /// Layout metrics for the window.
    let layout: MinimalLayout

    /// Current appearance choice.
    let themePreference: LociqThemePreference

    /// Accessibility reduced-motion flag passed from the root view.
    var reduceMotion = false

    /// Primary action handler.
    let onPrimaryAction: () -> Void

    /// Refresh handler.
    let onRefresh: () -> Void

    /// Appearance handler.
    let onSelectTheme: (LociqThemePreference) -> Void

    /// Drives the quiet missing-location permission pulse.
    @State private var isLocationPermissionPulsing = false

    /// Draws the brand, current actions, and loading line.
    var body: some View {
        VStack(alignment: .leading, spacing: layout.space(12)) {
            HStack(alignment: .center, spacing: layout.space(18)) {
                brand
                    .fixedSize()

                Spacer(minLength: layout.space(20))

                if !isWaitingForInitialData {
                    controls
                        .layoutPriority(1)
                }
            }
            // Same height with or without controls, so the wordmark never moves.
            .frame(minHeight: 44)

            ProgressLine(isLoading: isBusy, reduceMotion: reduceMotion)
        }
        .frame(maxWidth: layout.bottomBarMaxWidth)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("demographics.summary")
    }

    // MARK: - Brand

    private var brand: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("LOC")
            Text("IQ")
        }
        .font(LociqTypeScale.brand(layout))
        .foregroundStyle(Color.lociq(.brand))
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LOC IQ")
        .accessibilityIdentifier("app.brand")
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        if snapshot.hasDemographicData {
            HStack(alignment: .center, spacing: 0) {
                if refreshControl != .hidden {
                    refreshButton
                }

                if let shareText {
                    ShareLink(item: shareText) {
                        icon("square.and.arrow.up")
                    }
                    .buttonStyle(QuietIconButtonStyle(showsShape: showButtonShapes))
                    .accessibilityLabel("Share city snapshot")
                    .accessibilityHint("Opens the share sheet with this city snapshot")
                    .accessibilityInputLabels(["Share"])
                    .accessibilityIdentifier("action.share")
                }

                // The hint teaches the toggle at typical text sizes. In the
                // single-column layout there is no room for it beside the
                // controls; the toggle's label and hint still say "details".
                if showsDetailsToggle && !hasDiscoveredDataView && !isShowingDetails && !layout.usesSingleColumn {
                    Text("DATA")
                        .font(LociqTypeScale.dataHint(layout))
                        .foregroundStyle(Color.lociq(.hint))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.leading, layout.space(8))
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }

                if showsDetailsToggle {
                    detailsToggle
                }
            }
        } else {
            switch primaryAction {
            case .requestPermission:
                labeledActionButton(
                    title: "LOCATION REQUIRED",
                    subtitle: "ENABLE TO VIEW YOUR CITY",
                    systemImage: "location",
                    emphasized: true,
                    accessibilityLabel: "Allow location access",
                    accessibilityHint: "Shows the system prompt. LOC IQ uses your location to find your city's Census data.",
                    inputLabels: ["Location", "Allow location", "Enable location"],
                    identifier: "action.allowLocation"
                )
            case .openSettings:
                labeledActionButton(
                    title: "OPEN SETTINGS",
                    subtitle: nil,
                    systemImage: "gearshape",
                    emphasized: false,
                    accessibilityLabel: "Open Settings",
                    accessibilityHint: "Opens LOC IQ settings, where you can allow location access",
                    inputLabels: ["Settings", "Open Settings"],
                    identifier: "action.openSettings"
                )
            case .retry:
                labeledActionButton(
                    title: "TRY AGAIN",
                    subtitle: nil,
                    systemImage: "arrow.clockwise",
                    emphasized: false,
                    accessibilityLabel: "Try again",
                    accessibilityHint: "Attempts to load the city profile again",
                    inputLabels: ["Try again", "Retry"],
                    identifier: "action.retry"
                )
            case .toggleDetails, .none:
                EmptyView()
            }
        }
    }

    /// Refresh button, kept in place (disabled) while a refresh runs.
    private var refreshButton: some View {
        Button(action: onRefresh) {
            icon(refreshControl == .openSettings ? "location.slash" : "arrow.clockwise")
                .opacity(isBusy ? 0.42 : 1)
        }
        .buttonStyle(QuietIconButtonStyle(showsShape: showButtonShapes))
        .disabled(isBusy)
        .accessibilityLabel(refreshControl == .openSettings ? "Turn on location" : "Refresh")
        .accessibilityHint(refreshHint)
        .accessibilityInputLabels(refreshControl == .openSettings ? ["Turn on location", "Settings"] : ["Refresh"])
        .accessibilityIdentifier("action.refresh")
    }

    private var refreshHint: String {
        switch refreshControl {
        case .refresh:
            return "Finds your location and reloads Census data"
        case .requestPermissionAndRefresh:
            return "Asks for location access, then loads Census data for where you are"
        case .openSettings:
            return "Opens LOC IQ settings, where you can allow location access"
        case .hidden:
            return ""
        }
    }

    /// Summary/details toggle. Never locked by a background refresh.
    private var detailsToggle: some View {
        Button {
            hasDiscoveredDataView = true
            onPrimaryAction()
        } label: {
            Image(systemName: isShowingDetails ? "square.split.1x2.fill" : "square.split.1x2")
                .font(.system(size: LociqTypeScale.iconSize(layout, base: 17), weight: .regular))
                .foregroundStyle(Color.lociq(.brand))
                .frame(width: max(44, LociqTypeScale.iconSize(layout, base: 17) + 26), height: max(44, LociqTypeScale.iconSize(layout, base: 17) + 26))
                .id(isShowingDetails)
                .transition(.opacity)
                .overlay(alignment: .bottom) {
                    if isShowingDetails {
                        Rectangle()
                            .fill(Color.lociq(.hint))
                            .frame(width: 16, height: 1)
                    }
                }
        }
        .buttonStyle(QuietIconButtonStyle(showsShape: showButtonShapes))
        .disabled(isInteractionLocked)
        .accessibilityLabel(isShowingDetails ? "Show summary" : "Show details")
        .accessibilityHint(isShowingDetails ? "Returns to the summary statistics" : "Shows detailed demographic statistics and the data source")
        .accessibilityInputLabels(isShowingDetails ? ["Summary", "Home"] : ["Data", "Details", "Show data"])
        .accessibilityIdentifier("action.toggleDetails")
        .accessibilityAction(named: "Refresh") {
            if refreshControl != .hidden, !isBusy { onRefresh() }
        }
        .modifier(AppearanceActions(current: themePreference, onSelect: onSelectTheme))
        .animation(LociqMotion.quick(reduceMotion: reduceMotion), value: isShowingDetails)
        .contextMenu {
            if refreshControl != .hidden {
                Button(action: onRefresh) {
                    Label(refreshControl == .openSettings ? "Turn On Location" : "Refresh",
                          systemImage: refreshControl == .openSettings ? "location.slash" : "arrow.clockwise")
                }
                .disabled(isBusy)
            }
            if let shareText {
                ShareLink(item: shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            Picker(selection: Binding(get: { themePreference }, set: onSelectTheme)) {
                ForEach(LociqThemePreference.allCases) { preference in
                    Label(preference.label, systemImage: preference.iconName).tag(preference)
                }
            } label: {
                Label("Appearance", systemImage: "circle.lefthalf.filled")
            }
            .pickerStyle(.menu)
        }
    }

    /// One button made of an icon and its short explanation.
    ///
    /// The whole group is the hit target and a single accessibility element,
    /// so the text that explains the action also performs it.
    private func labeledActionButton(
        title: String,
        subtitle: String?,
        systemImage: String,
        emphasized: Bool,
        accessibilityLabel: String,
        accessibilityHint: String,
        inputLabels: [String],
        identifier: String
    ) -> some View {
        Button(action: onPrimaryAction) {
            HStack(alignment: .center, spacing: layout.space(10)) {
                VStack(alignment: .trailing, spacing: layout.space(3)) {
                    Text(title)
                        .font(LociqTypeScale.metricLabel(layout))
                        .foregroundStyle(Color.lociq(.metricLabel))
                    if let subtitle {
                        Text(subtitle)
                            .font(LociqTypeScale.metricDetail(layout))
                            .foregroundStyle(Color.lociq(.secondary))
                    }
                }
                .lineLimit(layout.usesSingleColumn ? 2 : 1)
                .minimumScaleFactor(layout.usesSingleColumn ? 1 : 0.82)
                .multilineTextAlignment(.trailing)

                ZStack {
                    if emphasized {
                        Circle()
                            .fill(Color.lociqLocationTint.opacity(reduceMotion ? 0.16 : 0.12))
                            .frame(width: 32, height: 32)
                            .scaleEffect(reduceMotion ? 1 : (isLocationPermissionPulsing ? 1.74 : 0.72))
                            .opacity(reduceMotion ? 1 : (isLocationPermissionPulsing ? 0 : 1))

                        Circle()
                            .stroke(Color.lociqLocationTint.opacity(reduceMotion ? 0.48 : 0.72), lineWidth: 1.4)
                            .frame(width: 30, height: 30)
                            .scaleEffect(reduceMotion ? 1 : (isLocationPermissionPulsing ? 1.36 : 0.9))
                            .opacity(reduceMotion ? 1 : (isLocationPermissionPulsing ? 0.22 : 1))
                    }

                    Image(systemName: systemImage)
                        .font(.system(size: LociqTypeScale.iconSize(layout, base: 17), weight: .medium))
                        .foregroundStyle(emphasized ? Color.lociqLocationTint : Color.lociq(.brand))
                }
                .frame(width: 44, height: 44)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuietIconButtonStyle(showsShape: showButtonShapes))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityInputLabels(inputLabels)
        .accessibilityIdentifier(identifier)
        .modifier(AppearanceActions(current: themePreference, onSelect: onSelectTheme))
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        .task(id: emphasized) {
            await runLocationPermissionPulse(active: emphasized)
        }
    }

    /// One icon glyph in a 44-point target that grows with the text size.
    private func icon(_ systemName: String) -> some View {
        let size = LociqTypeScale.iconSize(layout)
        return Image(systemName: systemName)
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(Color.lociq(.hint))
            .frame(width: max(44, size + 28), height: max(44, size + 28))
    }

    /// Runs a few restrained pulses while location permission is the primary action.
    private func runLocationPermissionPulse(active: Bool) async {
        guard active, !reduceMotion else {
            isLocationPermissionPulsing = false
            return
        }

        for _ in 0..<LociqMotion.permissionPulseCount {
            guard !Task.isCancelled else { return }
            isLocationPermissionPulsing = false
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard let animation = LociqMotion.permissionPulse(reduceMotion: reduceMotion) else { return }
            withAnimation(animation) {
                isLocationPermissionPulsing = true
            }
            try? await Task.sleep(nanoseconds: UInt64(LociqMotion.permissionPulseDuration * 1_000_000_000))
            try? await Task.sleep(nanoseconds: LociqMotion.permissionPulsePauseNanoseconds)
        }
        // Settle on the static ring.
        withAnimation(LociqMotion.quick(reduceMotion: reduceMotion)) {
            isLocationPermissionPulsing = false
        }
    }
}

/// Adds one accessibility action per other appearance, so VoiceOver, Voice
/// Control, and Switch Control users can change it without a long press.
private struct AppearanceActions: ViewModifier {
    let current: LociqThemePreference
    let onSelect: (LociqThemePreference) -> Void

    func body(content: Content) -> some View {
        let others = LociqThemePreference.allCases.filter { $0 != current }
        return content
            .accessibilityAction(named: others[0].accessibilityActionName) { onSelect(others[0]) }
            .accessibilityAction(named: others[1].accessibilityActionName) { onSelect(others[1]) }
    }
}

/// Immediate one-pixel feedback for the otherwise chromeless icon controls.
///
/// With Button Shapes on, a faint rounded outline marks every button. With a
/// pointer on iPad, hovering highlights the button's rounded target.
private struct QuietIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    /// Draws an outline because the user turned on Button Shapes.
    var showsShape = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.48 : 1)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.lociqText.opacity(configuration.isPressed ? 0.5 : 0))
                    .frame(width: 18, height: 1)
            }
            .overlay {
                if showsShape {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.lociq(.hint).opacity(isEnabled ? 1 : 0.5), lineWidth: 1)
                        .padding(4)
                }
            }
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 10, style: .continuous))
            .hoverEffect(.highlight)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
