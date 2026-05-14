//
//  LocationProfileViewState.swift
//  Lociq
//
//  Projects location profile state into view-facing display values.
//
//  This file keeps view-state derivation out of `ContentView`. SwiftUI reads a
//  simple immutable projection, while the view model keeps its richer internal
//  state machine.
//

import CoreLocation
import Foundation

/// Immutable display state consumed by the root SwiftUI view.
///
/// The values are already reduced to exactly what the view needs. This prevents
/// view code from switching over `LocationProfileViewModel.State` directly.
struct LocationProfileViewState: Sendable {
    /// Display snapshot for title, metrics, details, and share text.
    let snapshot: DemographicSnapshot

    /// Boundary geometry available to the boundary preview.
    let boundary: GeoJSONFeatureCollection?

    /// Coordinate used for the approximate-location dot.
    let coordinate: CLLocationCoordinate2D?

    /// Horizontal accuracy used to style the approximate-location dot.
    let horizontalAccuracy: CLLocationAccuracy?

    /// True while an active location or profile request is in flight.
    let isLoading: Bool

    /// True before the initial minimal loading screen can be replaced.
    let isWaitingForInitialData: Bool

    /// True when the bottom action can retry the current state.
    let canRetry: Bool

    /// True when the current state should ask for location permission.
    let needsLocationPermissionPrompt: Bool

    /// Optional text payload for the share sheet.
    let shareText: String?

    /// Returns true when boundary geometry is available for a complete demographic profile.
    ///
    /// Boundaries are hidden during initial loading and non-demographic states
    /// so the outline never implies unavailable demographic data exists.
    var canShowBoundary: Bool {
        boundary != nil && !isWaitingForInitialData && snapshot.hasDemographicData
    }

    /// Returns true when the current loaded city can be refreshed without changing UI structure.
    ///
    /// Refresh is intentionally unavailable while loading to prevent overlapping
    /// requests from the context menu.
    var canRefresh: Bool {
        snapshot.hasDemographicData && !isLoading
    }
}

/// Converts the ViewModel's state machine into simple view-facing values.
///
/// The mapper is pure. It does not mutate state, call services, or trigger
/// animation. That makes UI projection deterministic and easy to test.
enum LocationProfileViewStateMapper {
    /// Builds a view state for the supplied profile state and optional debug coordinate.
    ///
    /// - Parameters:
    ///   - state: Internal view-model state.
    ///   - debugCoordinate: Optional coordinate used by debug launches.
    /// - Returns: Immutable values needed by `ContentView`.
    static func make(
        from state: LocationProfileViewModel.State,
        debugCoordinate: CLLocationCoordinate2D?
    ) -> LocationProfileViewState {
        let snapshot = snapshot(from: state)

        return LocationProfileViewState(
            snapshot: snapshot,
            boundary: boundary(from: state),
            coordinate: coordinate(from: state, debugCoordinate: debugCoordinate),
            horizontalAccuracy: horizontalAccuracy(from: state),
            isLoading: isLoading(state),
            isWaitingForInitialData: isWaitingForInitialData(state),
            canRetry: canRetry(state),
            needsLocationPermissionPrompt: needsLocationPermissionPrompt(state),
            shareText: snapshot.shareText
        )
    }

    /// Returns the snapshot that should be displayed for a state-machine state.
    ///
    /// Initial request states use the loading snapshot, permission failures use
    /// the honest placeholder, and loaded states use cached profile content.
    private static func snapshot(from state: LocationProfileViewModel.State) -> DemographicSnapshot {
        switch state {
        case .idle, .requestingLocation, .loading:
            return .loading
        case .needsLocationPermission, .locationUnavailable:
            return .placeholder
        case .refreshing(let profile, let isStale), .loaded(let profile, let isStale):
            return isStale ? profile.snapshot.replacingDateLabel("") : profile.snapshot
        case .profileUnavailable(let snapshot, _, _, _, _):
            return snapshot
        }
    }

    /// Returns boundary geometry that should be visible for the current state.
    ///
    /// Unavailable states can carry a boundary so the app can show place context
    /// even when demographics are missing. `canShowBoundary` later decides
    /// whether that boundary should actually render.
    private static func boundary(from state: LocationProfileViewModel.State) -> GeoJSONFeatureCollection? {
        switch state {
        case .refreshing(let profile, _), .loaded(let profile, _):
            return profile.boundary
        case .profileUnavailable(_, let boundary, _, _, _):
            return boundary
        case .idle, .needsLocationPermission, .requestingLocation, .loading, .locationUnavailable:
            return nil
        }
    }

    /// Returns the coordinate attached to the current state, falling back to a debug coordinate for tests.
    ///
    /// Debug coordinates allow boundary and location-dot behavior to be tested
    /// without Core Location.
    private static func coordinate(
        from state: LocationProfileViewModel.State,
        debugCoordinate: CLLocationCoordinate2D?
    ) -> CLLocationCoordinate2D? {
        switch state {
        case .refreshing(let profile, _), .loaded(let profile, _):
            return profile.coordinate
        case .profileUnavailable(_, _, let coordinate, _, _):
            return coordinate
        case .idle, .needsLocationPermission, .requestingLocation, .loading, .locationUnavailable:
            return debugCoordinate
        }
    }

    /// Returns the horizontal accuracy attached to the current state.
    ///
    /// Accuracy is available only when it came from Core Location or a cached
    /// profile. Loading and permission states do not invent accuracy values.
    private static func horizontalAccuracy(from state: LocationProfileViewModel.State) -> CLLocationAccuracy? {
        switch state {
        case .refreshing(let profile, _), .loaded(let profile, _):
            return profile.horizontalAccuracy
        case .profileUnavailable(_, _, _, let horizontalAccuracy, _):
            return horizontalAccuracy
        case .idle, .needsLocationPermission, .requestingLocation, .loading, .locationUnavailable:
            return nil
        }
    }

    /// Returns true while a profile request or refresh is active.
    ///
    /// `refreshing` counts as loading even though data remains visible.
    private static func isLoading(_ state: LocationProfileViewModel.State) -> Bool {
        switch state {
        case .idle, .requestingLocation, .loading, .refreshing:
            return true
        case .needsLocationPermission, .loaded, .locationUnavailable, .profileUnavailable:
            return false
        }
    }

    /// Returns true before any displayable data or fallback state is ready.
    ///
    /// This drives the initial spinner-only launch state.
    private static func isWaitingForInitialData(_ state: LocationProfileViewModel.State) -> Bool {
        switch state {
        case .idle, .requestingLocation, .loading:
            return true
        case .needsLocationPermission, .refreshing, .loaded, .locationUnavailable, .profileUnavailable:
            return false
        }
    }

    /// Returns true when the bottom action can retry a recoverable state.
    ///
    /// Loaded and in-flight states do not expose retry through the primary
    /// action. Loaded refresh is exposed separately.
    private static func canRetry(_ state: LocationProfileViewModel.State) -> Bool {
        switch state {
        case .needsLocationPermission, .locationUnavailable, .profileUnavailable:
            return true
        case .idle, .requestingLocation, .loading, .refreshing, .loaded:
            return false
        }
    }

    /// Returns true when the app should ask the user to enable location access.
    ///
    /// This is separate from `canRetry` because the bottom icon and
    /// accessibility label differ for location permission.
    private static func needsLocationPermissionPrompt(_ state: LocationProfileViewModel.State) -> Bool {
        if case .needsLocationPermission = state {
            return true
        }
        return false
    }
}
