import CoreLocation

protocol LocationManaging: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var authorizationStatus: CLAuthorizationStatus { get }

    /// Requests foreground location authorization from the user.
    func requestWhenInUseAuthorization()

    /// Requests one current location update from the underlying location provider.
    func requestLocation()
}

extension CLLocationManager: LocationManaging {}
