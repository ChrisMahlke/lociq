//
//  LocationAuthorizationCoordinator.swift
//  Lociq
//
//  Converts Core Location authorization state into profile ViewModel actions.
//
//  Authorization branching is deliberately isolated from the view model. This
//  keeps location permission policy testable and avoids duplicating Core
//  Location status switches in multiple methods.
//

import CoreLocation

/// Action the ViewModel should take for one authorization state transition.
///
/// Actions describe intent, not implementation. The view model is responsible
/// for mutating state and making Core Location calls after receiving an action.
enum LocationAuthorizationAction: Sendable {
    /// Show the minimal location-access prompt state.
    case showPermissionPrompt

    /// Ask Core Location for the current location.
    case requestLocation

    /// Show the minimal location-unavailable state.
    case showLocationUnavailable

    /// Keep visible cached data while requesting a fresh location.
    case keepCurrentStateAndRequestLocation

    /// Leave the current state unchanged.
    case none
}

/// Encapsulates Core Location authorization branching outside the root ViewModel.
///
/// The coordinator takes `hasLoadedProfile` so cached data can remain visible
/// when authorization changes would otherwise produce an empty state.
struct LocationAuthorizationCoordinator: Sendable {
    /// Returns the action for an app activation with the supplied authorization status.
    ///
    /// Activation happens on launch and when the scene returns to the foreground.
    /// If a profile is already visible, the coordinator prefers keeping it
    /// visible while requesting a fresh location.
    func activationAction(for status: CLAuthorizationStatus, hasLoadedProfile: Bool) -> LocationAuthorizationAction {
        switch status {
        case .notDetermined:
            return hasLoadedProfile ? .none : .showPermissionPrompt
        case .authorizedAlways, .authorizedWhenInUse:
            return hasLoadedProfile ? .keepCurrentStateAndRequestLocation : .requestLocation
        case .denied, .restricted:
            return hasLoadedProfile ? .none : .showLocationUnavailable
        @unknown default:
            return hasLoadedProfile ? .none : .showLocationUnavailable
        }
    }

    /// Returns the action for an authorization callback from Core Location.
    ///
    /// Authorization callbacks happen after the user responds to the system
    /// prompt or changes permission in Settings.
    func changeAction(for status: CLAuthorizationStatus, hasLoadedProfile: Bool) -> LocationAuthorizationAction {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return hasLoadedProfile ? .keepCurrentStateAndRequestLocation : .requestLocation
        case .denied, .restricted:
            return hasLoadedProfile ? .none : .showLocationUnavailable
        case .notDetermined:
            return hasLoadedProfile ? .none : .showPermissionPrompt
        @unknown default:
            return hasLoadedProfile ? .none : .showLocationUnavailable
        }
    }

    /// Returns the fallback action for a Core Location failure.
    ///
    /// Denied and restricted states should not keep requesting location. Other
    /// failures can reasonably retry a one-shot location request.
    func failureAction(for status: CLAuthorizationStatus) -> LocationAuthorizationAction {
        status == .denied || status == .restricted ? .showLocationUnavailable : .requestLocation
    }
}
