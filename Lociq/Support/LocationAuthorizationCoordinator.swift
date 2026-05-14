//
//  LocationAuthorizationCoordinator.swift
//  Lociq
//
//  Converts Core Location authorization state into profile ViewModel actions.
//

import CoreLocation

/// Action the ViewModel should take for one authorization state transition.
enum LocationAuthorizationAction: Sendable {
    case showPermissionPrompt
    case requestLocation
    case showLocationUnavailable
    case keepCurrentStateAndRequestLocation
    case none
}

/// Encapsulates Core Location authorization branching outside the root ViewModel.
struct LocationAuthorizationCoordinator: Sendable {
    /// Returns the action for an app activation with the supplied authorization status.
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
    func failureAction(for status: CLAuthorizationStatus) -> LocationAuthorizationAction {
        status == .denied || status == .restricted ? .showLocationUnavailable : .requestLocation
    }
}
