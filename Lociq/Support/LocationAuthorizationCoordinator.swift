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

/// Why the app cannot get a location.
nonisolated enum LocationUnavailableReason: Equatable, Sendable {
    /// Location access was denied, or Location Services are off. The user can fix this in Settings.
    case denied

    /// Location access is restricted, for example by Screen Time. The user cannot change it.
    case restricted

    /// Access is allowed, but no usable fix arrived within the attempt budget.
    case noFix
}

/// Action the ViewModel should take for one authorization state transition.
///
/// Actions describe intent, not implementation. The view model is responsible
/// for mutating state and making Core Location calls after receiving an action.
nonisolated enum LocationAuthorizationAction: Equatable, Sendable {
    /// Show the minimal location-access prompt state.
    case showPermissionPrompt

    /// Ask Core Location for the current location while showing the locating state.
    case requestLocation

    /// Show why location is unavailable.
    case showLocationUnavailable(LocationUnavailableReason)

    /// Keep the visible profile while requesting a fresh location.
    case keepProfileAndRequestLocation

    /// Keep the visible profile, and label it because location cannot be read.
    case markProfile(ProfileStatus)
}

/// Encapsulates Core Location authorization branching outside the root ViewModel.
///
/// The coordinator takes `hasLoadedProfile` so cached data can remain visible
/// when authorization changes would otherwise produce an empty state. A profile
/// shown without authorization is always labeled, never presented as current.
nonisolated struct LocationAuthorizationCoordinator: Sendable {
    /// Maximum location attempts before the no-fix state is shown.
    let maxLocationAttempts: Int

    /// Creates a coordinator with a location attempt budget.
    init(maxLocationAttempts: Int = 2) {
        self.maxLocationAttempts = max(1, maxLocationAttempts)
    }

    /// Returns the action for an app activation with the supplied authorization status.
    ///
    /// Activation happens on launch and when the scene returns to the
    /// foreground. Permission is never requested here; it waits for a tap.
    func activationAction(for status: CLAuthorizationStatus, hasLoadedProfile: Bool) -> LocationAuthorizationAction {
        switch status {
        case .notDetermined:
            // "Allow Once" reverts to not-determined when the app stops being
            // used, so a cached city here is the user's last location.
            return hasLoadedProfile ? .markProfile(.lastLocation) : .showPermissionPrompt
        case .authorizedAlways, .authorizedWhenInUse:
            return hasLoadedProfile ? .keepProfileAndRequestLocation : .requestLocation
        case .denied:
            return hasLoadedProfile ? .markProfile(.locationOff(restricted: false)) : .showLocationUnavailable(.denied)
        case .restricted:
            return hasLoadedProfile ? .markProfile(.locationOff(restricted: true)) : .showLocationUnavailable(.restricted)
        @unknown default:
            return hasLoadedProfile ? .markProfile(.locationOff(restricted: true)) : .showLocationUnavailable(.restricted)
        }
    }

    /// Returns the action for an authorization callback from Core Location.
    ///
    /// Authorization callbacks happen after the user responds to the system
    /// prompt or changes permission in Settings. The mapping is the same as
    /// activation: a returning user who enables location in Settings is located
    /// without relaunching.
    func changeAction(for status: CLAuthorizationStatus, hasLoadedProfile: Bool) -> LocationAuthorizationAction {
        activationAction(for: status, hasLoadedProfile: hasLoadedProfile)
    }

    /// Returns the action after a location attempt fails while no profile is shown.
    ///
    /// Denied and restricted states never keep requesting location. An
    /// authorized request is tried again once; after `maxLocationAttempts`
    /// consecutive failures the explained no-fix state offers Retry.
    func failureAction(for status: CLAuthorizationStatus, consecutiveFailures: Int) -> LocationAuthorizationAction {
        switch status {
        case .denied:
            return .showLocationUnavailable(.denied)
        case .restricted:
            return .showLocationUnavailable(.restricted)
        case .notDetermined:
            return .showPermissionPrompt
        case .authorizedAlways, .authorizedWhenInUse:
            return consecutiveFailures < maxLocationAttempts ? .requestLocation : .showLocationUnavailable(.noFix)
        @unknown default:
            return .showLocationUnavailable(.noFix)
        }
    }
}
