//
//  LocationManaging.swift
//  Lociq
//
//  Defines the location-manager abstraction used by the profile ViewModel.
//
//  `CLLocationManager` is difficult to drive deterministically in tests. This
//  protocol captures only the surface the view model needs so tests can provide
//  a fake location manager.
//

import CoreLocation

/// Minimal Core Location manager surface consumed by `LocationProfileViewModel`.
///
/// Keeping the protocol small prevents the view model from depending on
/// unrelated `CLLocationManager` behavior.
protocol LocationManaging: AnyObject {
    /// Delegate that receives authorization and location callbacks.
    var delegate: CLLocationManagerDelegate? { get set }

    /// Requested accuracy for one-shot location updates.
    var desiredAccuracy: CLLocationAccuracy { get set }

    /// Current Core Location authorization status.
    var authorizationStatus: CLAuthorizationStatus { get }

    /// Whether the user granted precise or approximate ("Precise Location: Off") location.
    var accuracyAuthorization: CLAccuracyAuthorization { get }

    /// Requests foreground location authorization from the user.
    func requestWhenInUseAuthorization()

    /// Requests one current location update from the underlying location provider.
    func requestLocation()
}

/// Allows the real Core Location manager to satisfy the app's narrow abstraction.
extension CLLocationManager: LocationManaging {}

/// One location fix as the app uses it.
nonisolated struct LocationFix: Sendable {
    /// Fix coordinate.
    let coordinate: CLLocationCoordinate2D

    /// Radius of uncertainty in meters, when known.
    let horizontalAccuracy: CLLocationAccuracy?

    /// True when the user allows only approximate location.
    let isApproximate: Bool
}
