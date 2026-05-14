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
    private let cachePolicy: CityProfileCachePolicy
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
        self.cachePolicy = CityProfileCachePolicy(maxAge: cacheMaxAge)
        self.profileLoadPlanner = ProfileLoadPlanner(
            cacheMaxAge: cacheMaxAge,
            moveThresholdMeters: moveThresholdMeters,
            now: now
        )
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        if let cached = self.cacheStore.load() {
            state = .loaded(cached, isStale: cachePolicy.isStale(cached, at: now()))
            traceToken += 1
        }
    }

    var snapshot: DemographicSnapshot {
        viewState.snapshot
    }

    var boundary: GeoJSONFeatureCollection? {
        viewState.boundary
    }

    var coordinate: CLLocationCoordinate2D? {
        viewState.coordinate
    }

    var horizontalAccuracy: CLLocationAccuracy? {
        viewState.horizontalAccuracy
    }

    var isLoading: Bool {
        viewState.isLoading
    }

    var isWaitingForInitialData: Bool {
        viewState.isWaitingForInitialData
    }

    var canShowBoundary: Bool {
        viewState.canShowBoundary
    }

    var canRetry: Bool {
        viewState.canRetry
    }

    var needsLocationPermissionPrompt: Bool {
        viewState.needsLocationPermissionPrompt
    }

    var canRefreshCurrentCity: Bool {
        viewState.canRefresh
    }

    var shareText: String? {
        viewState.shareText
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

    /// Refreshes the currently visible city while keeping cached data on screen if the refresh fails.
    func refreshCurrentCity() {
        lastLoadedCoordinateKey = nil

        if let profile = currentLoadedProfile {
            load(
                for: profile.coordinate,
                horizontalAccuracy: profile.horizontalAccuracy,
                force: true
            )
        } else {
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
            if let cached = currentLoadedProfile {
                state = .loaded(cached, isStale: true)
            } else {
                state = .profileUnavailable(
                    snapshot: snapshot,
                    boundary: boundary,
                    coordinate: coordinate,
                    horizontalAccuracy: horizontalAccuracy,
                    failure: failure
                )
            }
            if boundary != nil || currentLoadedProfile?.boundary != nil {
                traceToken += 1
            }
            LociqDiagnostics.cityProfileLoadFailed(
                failure,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
    }

    private var viewState: LocationProfileViewState {
        LocationProfileViewStateMapper.make(from: state, debugCoordinate: debugCoordinate)
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
