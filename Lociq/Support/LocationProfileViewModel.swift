import Combine
import CoreLocation
import Foundation

protocol LocationManaging: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    func requestLocation()
}

extension CLLocationManager: LocationManaging {}

@MainActor
final class LocationProfileViewModel: NSObject, ObservableObject {
    enum State {
        case idle
        case needsLocationPermission
        case requestingLocation
        case loading
        case refreshing(CachedCityProfile, isStale: Bool)
        case loaded(CachedCityProfile, isStale: Bool)
        case locationUnavailable
        case profileUnavailable(
            snapshot: DemographicSnapshot,
            boundary: GeoJSONFeatureCollection?,
            coordinate: CLLocationCoordinate2D?,
            horizontalAccuracy: CLLocationAccuracy?,
            failure: CityProfileLoadFailure
        )
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var traceToken = 0

    private let manager: LocationManaging
    private let profileLoader: any CityProfileLoading
    private let debugCoordinate: CLLocationCoordinate2D?
    private let cacheStore: CityProfileCacheStore
    private let now: @Sendable () -> Date
    private let cacheMaxAge: TimeInterval
    private let moveThresholdMeters: CLLocationDistance
    private var lastLoadedCoordinateKey: String?
    private var loadTask: Task<Void, Never>?

    init(
        debugCoordinate: CLLocationCoordinate2D? = nil,
        cacheStore: CityProfileCacheStore? = nil,
        locationManager: LocationManaging = CLLocationManager(),
        profileLoader: (any CityProfileLoading)? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        cacheMaxAge: TimeInterval = 86_400,
        moveThresholdMeters: CLLocationDistance = 1_000
    ) {
        let httpClient = CensusHTTPClient(session: .shared)
        let censusAPIKey = AppConfig.censusAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let profileService = CensusCityProfileService(censusApiKey: censusAPIKey)
        let geocoderClient = CensusGeocoderClient(httpClient: httpClient)
        let boundaryClient = TIGERBoundaryClient(httpClient: httpClient)

        self.manager = locationManager
        self.profileLoader = profileLoader ?? CensusCityProfileLoader(
            profileService: profileService,
            geocoderClient: geocoderClient,
            boundaryClient: boundaryClient,
            hasCensusAPIKey: !censusAPIKey.isEmpty
        )
        self.debugCoordinate = debugCoordinate
        self.cacheStore = cacheStore ?? CityProfileCacheStore()
        self.now = now
        self.cacheMaxAge = cacheMaxAge
        self.moveThresholdMeters = moveThresholdMeters
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        if let cached = self.cacheStore.load() {
            state = .loaded(cached, isStale: cached.isExpired(at: now(), maxAge: cacheMaxAge))
            traceToken += 1
        }
    }

    var snapshot: DemographicSnapshot {
        switch state {
        case .idle, .requestingLocation, .loading:
            return .loading
        case .needsLocationPermission, .locationUnavailable:
            return .placeholder
        case .refreshing(let profile, let isStale), .loaded(let profile, let isStale):
            return isStale ? profile.snapshot.replacingDateLabel("CACHED") : profile.snapshot
        case .profileUnavailable(let snapshot, _, _, _, _):
            return snapshot
        }
    }

    var boundary: GeoJSONFeatureCollection? {
        switch state {
        case .refreshing(let profile, _), .loaded(let profile, _):
            return profile.boundary
        case .profileUnavailable(_, let boundary, _, _, _):
            return boundary
        case .idle, .needsLocationPermission, .requestingLocation, .loading, .locationUnavailable:
            return nil
        }
    }

    var coordinate: CLLocationCoordinate2D? {
        switch state {
        case .refreshing(let profile, _), .loaded(let profile, _):
            return profile.coordinate
        case .profileUnavailable(_, _, let coordinate, _, _):
            return coordinate
        case .idle, .needsLocationPermission, .requestingLocation, .loading, .locationUnavailable:
            return debugCoordinate
        }
    }

    var horizontalAccuracy: CLLocationAccuracy? {
        switch state {
        case .refreshing(let profile, _), .loaded(let profile, _):
            return profile.horizontalAccuracy
        case .profileUnavailable(_, _, _, let horizontalAccuracy, _):
            return horizontalAccuracy
        case .idle, .needsLocationPermission, .requestingLocation, .loading, .locationUnavailable:
            return nil
        }
    }

    var isLoading: Bool {
        switch state {
        case .idle, .requestingLocation, .loading, .refreshing:
            return true
        case .needsLocationPermission, .loaded, .locationUnavailable, .profileUnavailable:
            return false
        }
    }

    var isWaitingForInitialData: Bool {
        switch state {
        case .idle, .requestingLocation, .loading:
            return true
        case .needsLocationPermission, .refreshing, .loaded, .locationUnavailable, .profileUnavailable:
            return false
        }
    }

    var canShowBoundary: Bool {
        boundary != nil && !isWaitingForInitialData && snapshot.hasDemographicData
    }

    var canRetry: Bool {
        switch state {
        case .needsLocationPermission, .locationUnavailable, .profileUnavailable:
            return true
        case .idle, .requestingLocation, .loading, .refreshing, .loaded:
            return false
        }
    }

    var needsLocationPermissionPrompt: Bool {
        if case .needsLocationPermission = state {
            return true
        }
        return false
    }

    func activate() {
        if let debugCoordinate {
            load(for: debugCoordinate)
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            if currentLoadedProfile == nil {
                state = .needsLocationPermission
            }
        case .authorizedAlways, .authorizedWhenInUse:
            if currentLoadedProfile == nil {
                state = .requestingLocation
            }
            manager.requestLocation()
        case .denied, .restricted:
            if currentLoadedProfile == nil {
                state = .locationUnavailable
            }
        @unknown default:
            if currentLoadedProfile == nil {
                state = .locationUnavailable
            }
        }
    }

    func requestLocationAccess() {
        if manager.authorizationStatus == .notDetermined {
            state = .requestingLocation
            manager.requestWhenInUseAuthorization()
        } else {
            retry()
        }
    }

    func retry() {
        lastLoadedCoordinateKey = nil

        switch state {
        case .needsLocationPermission:
            requestLocationAccess()
        case .profileUnavailable(_, _, let coordinate, let horizontalAccuracy, _):
            if let coordinate {
                load(for: coordinate, horizontalAccuracy: horizontalAccuracy, force: true)
            } else {
                activate()
            }
        case .locationUnavailable:
            activate()
        case .idle, .requestingLocation, .loading, .refreshing, .loaded:
            activate()
        }
    }

    func waitForPendingLoad() async {
        await loadTask?.value
    }

    func handleAuthorizationChange(_ authorizationStatus: CLAuthorizationStatus) {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            state = currentLoadedProfile == nil ? .requestingLocation : state
            manager.requestLocation()
        case .denied, .restricted:
            if currentLoadedProfile == nil {
                state = .locationUnavailable
            }
        case .notDetermined:
            if currentLoadedProfile == nil {
                state = .needsLocationPermission
            }
        @unknown default:
            if currentLoadedProfile == nil {
                state = .locationUnavailable
            }
        }
    }

    func handleLocationUpdate(_ location: CLLocation) {
        load(for: location.coordinate, horizontalAccuracy: location.horizontalAccuracy)
    }

    func handleLocationFailure(authorizationStatus: CLAuthorizationStatus) {
        guard currentLoadedProfile == nil else { return }
        state = authorizationStatus == .denied || authorizationStatus == .restricted
            ? .locationUnavailable
            : .requestingLocation
    }

    private func load(
        for coordinate: CLLocationCoordinate2D,
        horizontalAccuracy: CLLocationAccuracy? = nil,
        force: Bool = false
    ) {
        let coordinateKey = Self.coordinateKey(for: coordinate)
        guard force || coordinateKey != lastLoadedCoordinateKey else { return }

        let previousProfile = currentLoadedProfile
        let previousStale = currentLoadedProfileIsStale
        lastLoadedCoordinateKey = coordinateKey

        if let previousProfile,
           !Self.isMeaningfullyDifferent(
            previousProfile.coordinate,
            from: coordinate,
            thresholdMeters: moveThresholdMeters
           ) {
            state = .refreshing(
                previousProfile,
                isStale: previousStale || previousProfile.isExpired(at: now(), maxAge: cacheMaxAge)
            )
        } else {
            state = .loading
        }

        loadTask?.cancel()
        loadTask = Task { [weak self, profileLoader] in
            let outcome = await profileLoader.loadProfile(
                for: coordinate,
                horizontalAccuracy: horizontalAccuracy
            )
            self?.apply(outcome)
        }
    }

    private func apply(_ outcome: CityProfileLoadOutcome) {
        switch outcome {
        case .loaded(let profile):
            cacheStore.save(profile)
            state = .loaded(profile, isStale: false)
            traceToken += 1
        case .unavailable(let snapshot, let boundary, let coordinate, let horizontalAccuracy, let failure):
            state = .profileUnavailable(
                snapshot: snapshot,
                boundary: boundary,
                coordinate: coordinate,
                horizontalAccuracy: horizontalAccuracy,
                failure: failure
            )
            if boundary != nil {
                traceToken += 1
            }
        }
    }

    private var currentLoadedProfile: CachedCityProfile? {
        switch state {
        case .refreshing(let profile, _), .loaded(let profile, _):
            return profile
        case .idle, .needsLocationPermission, .requestingLocation, .loading, .locationUnavailable, .profileUnavailable:
            return nil
        }
    }

    private var currentLoadedProfileIsStale: Bool {
        switch state {
        case .refreshing(_, let isStale), .loaded(_, let isStale):
            return isStale
        case .idle, .needsLocationPermission, .requestingLocation, .loading, .locationUnavailable, .profileUnavailable:
            return false
        }
    }

    private static func coordinateKey(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    private static func isMeaningfullyDifferent(
        _ lhs: CLLocationCoordinate2D,
        from rhs: CLLocationCoordinate2D,
        thresholdMeters: CLLocationDistance
    ) -> Bool {
        let start = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
        let end = CLLocation(latitude: rhs.latitude, longitude: rhs.longitude)
        return start.distance(from: end) > thresholdMeters
    }
}

extension LocationProfileViewModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorizationStatus = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.handleAuthorizationChange(authorizationStatus)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.handleLocationUpdate(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let authorizationStatus = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.handleLocationFailure(authorizationStatus: authorizationStatus)
        }
    }
}

struct CachedCityProfile: Codable, Sendable {
    let snapshot: DemographicSnapshot
    let boundary: GeoJSONFeatureCollection
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double?
    let cachedAt: Date?

    init(
        snapshot: DemographicSnapshot,
        boundary: GeoJSONFeatureCollection,
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double?,
        cachedAt: Date? = nil
    ) {
        self.snapshot = snapshot
        self.boundary = boundary
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.cachedAt = cachedAt
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func isExpired(at date: Date, maxAge: TimeInterval) -> Bool {
        guard let cachedAt else { return true }
        return date.timeIntervalSince(cachedAt) > maxAge
    }
}

struct CityProfileCacheStore {
    private let key = "lociq.lastCityProfile.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> CachedCityProfile? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CachedCityProfile.self, from: data)
    }

    func save(_ profile: CachedCityProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
