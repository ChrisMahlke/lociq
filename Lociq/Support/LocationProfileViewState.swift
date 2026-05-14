//
//  LocationProfileViewState.swift
//  Lociq
//
//  Projects location profile state into view-facing display values.
//

import CoreLocation
import Foundation

/// Immutable display state consumed by the root SwiftUI view.
struct LocationProfileViewState: Sendable {
    let snapshot: DemographicSnapshot
    let boundary: GeoJSONFeatureCollection?
    let coordinate: CLLocationCoordinate2D?
    let horizontalAccuracy: CLLocationAccuracy?
    let isLoading: Bool
    let isWaitingForInitialData: Bool
    let canRetry: Bool
    let needsLocationPermissionPrompt: Bool
    let shareText: String?

    /// Returns true when boundary geometry is available for a complete demographic profile.
    var canShowBoundary: Bool {
        boundary != nil && !isWaitingForInitialData && snapshot.hasDemographicData
    }

    /// Returns true when the current loaded city can be refreshed without changing UI structure.
    var canRefresh: Bool {
        snapshot.hasDemographicData && !isLoading
    }
}

/// Converts the ViewModel's state machine into simple view-facing values.
enum LocationProfileViewStateMapper {
    /// Builds a view state for the supplied profile state and optional debug coordinate.
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
    private static func isLoading(_ state: LocationProfileViewModel.State) -> Bool {
        switch state {
        case .idle, .requestingLocation, .loading, .refreshing:
            return true
        case .needsLocationPermission, .loaded, .locationUnavailable, .profileUnavailable:
            return false
        }
    }

    /// Returns true before any displayable data or fallback state is ready.
    private static func isWaitingForInitialData(_ state: LocationProfileViewModel.State) -> Bool {
        switch state {
        case .idle, .requestingLocation, .loading:
            return true
        case .needsLocationPermission, .refreshing, .loaded, .locationUnavailable, .profileUnavailable:
            return false
        }
    }

    /// Returns true when the bottom action can retry a recoverable state.
    private static func canRetry(_ state: LocationProfileViewModel.State) -> Bool {
        switch state {
        case .needsLocationPermission, .locationUnavailable, .profileUnavailable:
            return true
        case .idle, .requestingLocation, .loading, .refreshing, .loaded:
            return false
        }
    }

    /// Returns true when the app should ask the user to enable location access.
    private static func needsLocationPermissionPrompt(_ state: LocationProfileViewModel.State) -> Bool {
        if case .needsLocationPermission = state {
            return true
        }
        return false
    }
}
