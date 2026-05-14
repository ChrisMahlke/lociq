//
//  LocationProfileViewModel.swift
//  Lociq
//
//  Coordinates location permission, profile loading, cache refresh, and UI state.
//

import Combine
import CoreLocation
import Foundation

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
    private let playProfileResolvedHaptic: @MainActor () -> Void
    private let cacheMaxAge: TimeInterval
    private let authorizationCoordinator = LocationAuthorizationCoordinator()
    private let profileLoadPlanner: ProfileLoadPlanner
    private var lastLoadedCoordinateKey: String?
    private var activeLoadID: UUID?
    private var loadTask: Task<Void, Never>?
    private var hasPlayedProfileResolvedHaptic = false

    /// Creates the location profile state machine and wires together location, cache, and Census profile dependencies.
    init(
        debugCoordinate: CLLocationCoordinate2D? = nil,
        cacheStore: CityProfileCacheStore? = nil,
        locationManager: LocationManaging = CLLocationManager(),
        profileLoader: (any CityProfileLoading)? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        profileResolvedHaptic: @escaping @MainActor () -> Void = { Haptics.profileResolved() },
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
        self.playProfileResolvedHaptic = profileResolvedHaptic
        self.cacheMaxAge = cacheMaxAge
        self.profileLoadPlanner = ProfileLoadPlanner(
            cacheMaxAge: cacheMaxAge,
            moveThresholdMeters: moveThresholdMeters,
            now: now
        )
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
            return isStale ? profile.snapshot.replacingDateLabel("") : profile.snapshot
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

    /// Starts or resumes the location/profile workflow based on the current authorization state.
    func activate() {
        if let debugCoordinate {
            load(for: debugCoordinate)
            return
        }

        perform(
            authorizationCoordinator.activationAction(
                for: manager.authorizationStatus,
                hasLoadedProfile: currentLoadedProfile != nil
            )
        )
    }

    /// Prompts for location access when possible or falls back to the normal retry path.
    func requestLocationAccess() {
        if manager.authorizationStatus == .notDetermined {
            state = .requestingLocation
            manager.requestWhenInUseAuthorization()
        } else {
            retry()
        }
    }

    /// Retries the last recoverable failure without requiring the user to restart the app.
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

    /// Waits for the active profile load to finish; used by tests to observe async state transitions deterministically.
    func waitForPendingLoad() async {
        await loadTask?.value
    }

    /// Applies a Core Location authorization transition to the state machine.
    func handleAuthorizationChange(_ authorizationStatus: CLAuthorizationStatus) {
        perform(
            authorizationCoordinator.changeAction(
                for: authorizationStatus,
                hasLoadedProfile: currentLoadedProfile != nil
            )
        )
    }

    /// Starts a profile refresh for the newest location update.
    func handleLocationUpdate(_ location: CLLocation) {
        load(for: location.coordinate, horizontalAccuracy: location.horizontalAccuracy)
    }

    /// Converts a location failure into the least noisy user-visible state.
    func handleLocationFailure(authorizationStatus: CLAuthorizationStatus) {
        guard currentLoadedProfile == nil else { return }
        perform(authorizationCoordinator.failureAction(for: authorizationStatus))
    }

    /// Starts a guarded city-profile request for a coordinate.
    private func load(
        for coordinate: CLLocationCoordinate2D,
        horizontalAccuracy: CLLocationAccuracy? = nil,
        force: Bool = false
    ) {
        guard let plan = profileLoadPlanner.plan(
            coordinate: coordinate,
            previousProfile: currentLoadedProfile,
            previousStale: currentLoadedProfileIsStale,
            lastCoordinateKey: lastLoadedCoordinateKey,
            force: force
        ) else { return }

        lastLoadedCoordinateKey = plan.coordinateKey
        state = plan.preLoadState

        let loadID = UUID()
        activeLoadID = loadID

        let startedAt = now()
        loadTask?.cancel()
        loadTask = Task { [weak self, profileLoader] in
            let outcome = await profileLoader.loadProfile(
                for: coordinate,
                horizontalAccuracy: horizontalAccuracy
            )
            self?.apply(outcome, loadID: loadID, startedAt: startedAt)
        }
    }

    /// Applies the result for the currently active request and ignores stale responses.
    private func apply(_ outcome: CityProfileLoadOutcome, loadID: UUID, startedAt: Date) {
        guard loadID == activeLoadID else { return }

        switch outcome {
        case .loaded(let profile):
            let timestampedProfile = profile.withCachedAt(now())
            cacheStore.save(timestampedProfile)
            state = .loaded(timestampedProfile, isStale: false)
            playProfileResolvedHapticIfNeeded()
            traceToken += 1
            LociqDiagnostics.cityProfileLoadCompleted(duration: now().timeIntervalSince(startedAt))
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
            LociqDiagnostics.cityProfileLoadFailed(
                failure,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
    }

    /// Emits the first successful profile haptic once per app session.
    private func playProfileResolvedHapticIfNeeded() {
        guard !hasPlayedProfileResolvedHaptic else { return }
        hasPlayedProfileResolvedHaptic = true
        playProfileResolvedHaptic()
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

    /// Applies one authorization action to ViewModel state and Core Location requests.
    private func perform(_ action: LocationAuthorizationAction) {
        switch action {
        case .showPermissionPrompt:
            state = .needsLocationPermission
        case .requestLocation:
            state = .requestingLocation
            manager.requestLocation()
        case .showLocationUnavailable:
            state = .locationUnavailable
        case .keepCurrentStateAndRequestLocation:
            manager.requestLocation()
        case .none:
            break
        }
    }
}

extension LocationProfileViewModel: CLLocationManagerDelegate {
    /// Bridges Core Location authorization callbacks back onto the main actor.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorizationStatus = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.handleAuthorizationChange(authorizationStatus)
        }
    }

    /// Bridges Core Location updates back onto the main actor.
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.handleLocationUpdate(location)
        }
    }

    /// Bridges Core Location failures back onto the main actor.
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let authorizationStatus = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.handleLocationFailure(authorizationStatus: authorizationStatus)
        }
    }
}
