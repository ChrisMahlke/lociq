//
//  BottomIdentity.swift
//  Lociq
//
//  Renders the LOC IQ mark, bottom action, and loading line.
//
//  This is the only persistent control area in the app. It carries brand,
//  loading feedback, retry/location actions, the home/details toggle, and a
//  context menu for secondary actions without adding visible chrome.
//

import SwiftUI

/// Bottom brand and action surface for the minimal interface.
///
/// The component uses one icon button to represent the current primary action.
/// It changes between location, retry, details, and home based on the view
/// state supplied by `LocationProfileViewModel`.
struct BottomIdentity: View {
    /// Static strings and SF Symbols used by the bottom surface.
    private enum Constants {
        static let brandLeading = "LOC"
        static let brandTrailing = "IQ"
        static let brandAccessibilityLabel = "LOCIQ"
        static let brandAccessibilityIdentifier = "app.brand"
        static let summaryAccessibilityIdentifier = "demographics.summary"
        static let locationIcon = "location"
        static let retryIcon = "arrow.clockwise"
        static let shareIcon = "square.and.arrow.up"
        static let homeIcon = "house"
        static let detailIcon = "list.bullet.rectangle"
        static let enableLocationLabel = "Enable location access"
        static let retryLabel = "Retry loading data"
        static let showHomeLabel = "Show home view"
        static let showDataLabel = "Show data view"
        static let refreshLabel = "Refresh data"
        static let shareLabel = "Share city snapshot"
    }

    /// Current demographic display snapshot.
    let snapshot: DemographicSnapshot

    /// Whether the details view is currently visible.
    let isShowingDetails: Bool

    /// Whether profile loading or content cycling is active.
    let isLoading: Bool

    /// Whether the initial spinner-only state is active.
    let isWaitingForInitialData: Bool

    /// Whether the primary action should retry or request access.
    let canRetry: Bool

    /// Whether the retry state specifically represents missing location permission.
    let needsLocationPermission: Bool

    /// Whether the context menu can expose refresh.
    let canRefresh: Bool

    /// Optional share payload for the context menu.
    let shareText: String?

    /// Layout metrics for the current constrained viewport.
    let layout: MinimalLayout

    /// Current app theme used to render the appearance toggle.
    let themePreference: LociqThemePreference

    /// Accessibility reduced-motion flag passed from the root view.
    var reduceMotion = false

    /// Primary bottom action handler.
    let onShowDetails: () -> Void

    /// Secondary refresh handler used from the context menu.
    let onRefresh: () -> Void

    /// Secondary theme handler used by the minimal appearance switch.
    let onToggleTheme: () -> Void

    /// Drives the quiet missing-location permission pulse.
    @State private var isLocationPermissionPulsing = false

    /// SF Symbol name for the current primary action.
    private var iconName: String {
        if !snapshot.hasDemographicData {
            return needsLocationPermission ? Constants.locationIcon : Constants.retryIcon
        }
        return isShowingDetails ? Constants.homeIcon : Constants.detailIcon
    }

    /// Accessibility label for the current primary action.
    private var actionLabel: String {
        if !snapshot.hasDemographicData {
            return needsLocationPermission ? Constants.enableLocationLabel : Constants.retryLabel
        }
        return isShowingDetails ? Constants.showHomeLabel : Constants.showDataLabel
    }

    /// True when the primary action should call attention to location permission.
    private var shouldEmphasizeLocationPermission: Bool {
        !snapshot.hasDemographicData && needsLocationPermission && !isWaitingForInitialData && !isLoading
    }

    /// Foreground opacity for the primary action icon.
    private var primaryIconOpacity: Double {
        shouldEmphasizeLocationPermission ? 1 : 0.68
    }

    /// Draws the brand, current action icon, and progress/loading line.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 18) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(Constants.brandLeading)
                        Text(Constants.brandTrailing)
                    }
                    .font(LociqTypeScale.brand(layout))
                    .foregroundStyle(Color.lociqText.opacity(0.74))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Constants.brandAccessibilityLabel)
                    .accessibilityIdentifier(Constants.brandAccessibilityIdentifier)

                    Spacer(minLength: 28)

                    HStack(alignment: .center, spacing: 0) {
                        Button(action: onToggleTheme) {
                            Image(systemName: themePreference.toggleIconName)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(Color.lociqText.opacity(0.58))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(themePreference.toggleAccessibilityLabel)

                        if !isWaitingForInitialData && (snapshot.hasDemographicData || canRetry) {
                            if canRefresh {
                                Button(action: onRefresh) {
                                    Image(systemName: Constants.retryIcon)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundStyle(Color.lociqText.opacity(0.58))
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .disabled(isLoading)
                                .accessibilityLabel(Constants.refreshLabel)
                            }

                            if let shareText {
                                ShareLink(item: shareText) {
                                    Image(systemName: Constants.shareIcon)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundStyle(Color.lociqText.opacity(0.58))
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Constants.shareLabel)
                            }

                            primaryActionButton
                        }
                    }

                    if !isWaitingForInitialData && shouldEmphasizeLocationPermission {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(snapshot.market)
                                .font(LociqTypeScale.metricLabel(layout))
                                .foregroundStyle(Color.lociqText.opacity(0.82))

                            Text(snapshot.dateLabel)
                                .font(LociqTypeScale.metricDetail(layout))
                                .foregroundStyle(Color.lociqText.opacity(0.62))
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .multilineTextAlignment(.trailing)
                        .accessibilityHidden(true)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }

                ProgressLine(progress: snapshot.confidence, isLoading: isLoading, reduceMotion: reduceMotion)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // The line doubles as the retry target in unavailable
                        // states, preserving the one-control minimalist surface.
                        if canRetry {
                            onShowDetails()
                        }
                    }
            }
            .frame(maxWidth: 520)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(Constants.summaryAccessibilityIdentifier)
    }

    /// Primary mode, retry, or permission button.
    private var primaryActionButton: some View {
        Button(action: onShowDetails) {
            ZStack {
                if shouldEmphasizeLocationPermission {
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

                Image(systemName: iconName)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(
                        shouldEmphasizeLocationPermission
                            ? Color.lociqLocationTint.opacity(primaryIconOpacity)
                            : Color.lociqText.opacity(primaryIconOpacity)
                    )
                    .id(iconName)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
            .frame(width: 44, height: 44)
            .opacity(isLoading ? 0.42 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(actionLabel)
        .animation(LociqMotion.quick(reduceMotion: reduceMotion), value: iconName)
        .animation(LociqMotion.quick(reduceMotion: reduceMotion), value: isLoading)
        .animation(LociqMotion.quick(reduceMotion: reduceMotion), value: shouldEmphasizeLocationPermission)
        .contextMenu {
            if canRefresh {
                Button("Refresh", systemImage: Constants.retryIcon, action: onRefresh)
            }
            if let shareText {
                ShareLink(item: shareText) {
                    Label("Share", systemImage: Constants.shareIcon)
                }
            }
        }
        .task(id: shouldEmphasizeLocationPermission) {
            await runLocationPermissionPulse()
        }
    }

    /// Runs a restrained pulse while location permission is the primary action.
    private func runLocationPermissionPulse() async {
        guard shouldEmphasizeLocationPermission else {
            isLocationPermissionPulsing = false
            return
        }
        guard !reduceMotion else {
            isLocationPermissionPulsing = false
            return
        }

        while !Task.isCancelled {
            isLocationPermissionPulsing = false
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard let animation = LociqMotion.permissionPulse(reduceMotion: reduceMotion) else { return }
            withAnimation(animation) {
                isLocationPermissionPulsing = true
            }
            try? await Task.sleep(nanoseconds: UInt64(LociqMotion.permissionPulseDuration * 1_000_000_000))
            try? await Task.sleep(nanoseconds: LociqMotion.permissionPulsePauseNanoseconds)
        }
    }
}
