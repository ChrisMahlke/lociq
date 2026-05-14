//
//  LocationProfileViewModel.swift
//  Lociq
//
//  Coordinates location permission, profile loading, cache refresh, and UI state.
//
//  This is the app's main state machine. It is deliberately responsible for
//  orchestration only: Core Location callbacks, cache loading, request planning,
//  async profile loading, and state publication. Display projection lives in
//  `LocationProfileViewStateMapper`, and service details live behind protocols.
//

import Combine
import CoreLocation
import Foundation

@MainActor
/// Main actor state machine backing the root SwiftUI interface.
///
/// The view model keeps all published state on the main actor because SwiftUI
/// observes it directly. Network and service work happens in async tasks, but
/// outcomes are applied back on the main actor.
final class LocationProfileViewModel: NSObject, ObservableObject {
    /// Internal state machine for location and profile loading.
    ///
    /// The states distinguish between initial loading, refresh over existing
    /// data, complete profile availability, permission states, and unavailable
    /// profile shells. That separation lets the UI stay sparse without lying
    /// about whether data exists.
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

    /// Current state machine value observed by SwiftUI.
    @Published private(set) var state: State = .idle

    /// Incrementing token used to restart one-shot boundary and connector animations.
    @Published private(set) var traceToken = 0

    /// Location manager abstraction, real in production and fake in tests.
    private let manager: LocationManaging

    /// Profile loading dependency that hides Census service composition.
    private let profileLoader: any CityProfileLoading

    /// Optional launch-argument coordinate used for deterministic debug testing.
    private let debugCoordinate: CLLocationCoordinate2D?

    /// Local cache for the last successful profile.
    private let cacheStore: CityProfileCacheStore

    /// Clock dependency for testable cache freshness and load durations.
    private let now: @Sendable () -> Date

    /// Haptic closure invoked once when the first real profile resolves.
    private let playProfileResolvedHaptic: @MainActor () -> Void

    /// Cache freshness policy used for restored profiles.
    private let cachePolicy: CityProfileCachePolicy

    /// Pure authorization transition helper.
    private let authorizationCoordinator = LocationAuthorizationCoordinator()

    /// Pure duplicate-suppression and pre-load-state planner.
    private let profileLoadPlanner: ProfileLoadPlanner

    /// Last rounded coordinate key requested by the loader.
    private var lastLoadedCoordinateKey: String?

    /// Identifier for the currently active async profile load.
    private var activeLoadID: UUID?

    /// The current load task, retained so tests can await it and new loads can cancel it.
    private var loadTask: Task<Void, Never>?

    /// Prevents repeated first-profile haptics during refreshes.
    private var hasPlayedProfileResolvedHaptic = false

    /// Creates the location profile state machine and wires together location, cache, and Census profile dependencies.
    ///
    /// Production defaults construct the real Core Location manager, Census
    /// services, cache store, and haptic behavior. Tests can inject every
    /// side-effecting dependency.
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

        // Restore cached content immediately so launch does not have to wait
        // for network services before showing a known recent profile.
        if let cached = self.cacheStore.load() {
            state = .loaded(cached, isStale: cachePolicy.isStale(cached, at: now()))
            traceToken += 1
        }
    }

    /// Current display snapshot projected from the state machine.
    var snapshot: DemographicSnapshot {
        viewState.snapshot
    }

    /// Boundary geometry that should currently be available to the view.
    var boundary: GeoJSONFeatureCollection? {
        viewState.boundary
    }

    /// Coordinate associated with the currently displayed state.
    var coordinate: CLLocationCoordinate2D? {
        viewState.coordinate
    }

    /// Horizontal accuracy associated with the displayed coordinate.
    var horizontalAccuracy: CLLocationAccuracy? {
        viewState.horizontalAccuracy
    }

    /// True while location or profile loading is active.
    var isLoading: Bool {
        viewState.isLoading
    }

    /// True before the app has any displayable data or fallback state.
    var isWaitingForInitialData: Bool {
        viewState.isWaitingForInitialData
    }

    /// True when the boundary preview should draw.
    var canShowBoundary: Bool {
        viewState.canShowBoundary
    }

    /// True when the bottom action can retry a recoverable state.
    var canRetry: Bool {
        viewState.canRetry
    }

    /// True when the UI should ask the user to enable location access.
    var needsLocationPermissionPrompt: Bool {
        viewState.needsLocationPermissionPrompt
    }

    /// True when a visible profile can be refreshed in place.
    var canRefreshCurrentCity: Bool {
        viewState.canRefresh
    }

    /// Optional share text for the visible profile.
    var shareText: String? {
        viewState.shareText
    }

    /// Starts or resumes the location/profile workflow based on the current authorization state.
    ///
    /// Debug coordinates bypass Core Location so simulator and regression tests
    /// can load a known city deterministically.
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
    ///
    /// If authorization has already been decided, the bottom action behaves as a
    /// retry instead of repeatedly asking for permission.
    func requestLocationAccess() {
        if manager.authorizationStatus == .notDetermined {
            state = .requestingLocation
            manager.requestWhenInUseAuthorization()
        } else {
            retry()
        }
    }

    /// Retries the last recoverable failure without requiring the user to restart the app.
    ///
    /// Retry clears the duplicate coordinate key so the same coordinate can be
    /// requested again after a transient network or service failure.
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
    ///
    /// The refresh path forces a new request even when the coordinate has not
    /// changed, but it keeps current data visible through the `.refreshing`
    /// pre-load state.
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
    ///
    /// The coordinator decides the action. The view model performs the action so
    /// all mutations remain centralized.
    func handleAuthorizationChange(_ authorizationStatus: CLAuthorizationStatus) {
        perform(
            authorizationCoordinator.changeAction(
                for: authorizationStatus,
                hasLoadedProfile: currentLoadedProfile != nil
            )
        )
    }

    /// Starts a profile refresh for the newest location update.
    ///
    /// Core Location may deliver multiple locations. The delegate passes only
    /// the newest one here.
    func handleLocationUpdate(_ location: CLLocation) {
        load(for: location.coordinate, horizontalAccuracy: location.horizontalAccuracy)
    }

    /// Converts a location failure into the least noisy user-visible state.
    ///
    /// If a profile is already visible, location errors do not replace it. This
    /// preserves useful stale context instead of flashing an error.
    func handleLocationFailure(authorizationStatus: CLAuthorizationStatus) {
        guard currentLoadedProfile == nil else { return }
        perform(authorizationCoordinator.failureAction(for: authorizationStatus))
    }

    /// Starts a guarded city-profile request for a coordinate.
    ///
    /// The load planner suppresses duplicate requests and chooses whether to
    /// show loading or refreshing state. Each actual request receives a UUID so
    /// late responses from cancelled tasks cannot overwrite newer data.
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
    ///
    /// `loadID` protects against out-of-order async completion. If a newer load
    /// has started, older outcomes are ignored.
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

    /// Current view-facing projection of the internal state machine.
    private var viewState: LocationProfileViewState {
        LocationProfileViewStateMapper.make(from: state, debugCoordinate: debugCoordinate)
    }

    /// Emits the first successful profile haptic once per app session.
    private func playProfileResolvedHapticIfNeeded() {
        guard !hasPlayedProfileResolvedHaptic else { return }
        hasPlayedProfileResolvedHaptic = true
        playProfileResolvedHaptic()
    }

    /// Currently visible loaded profile, including stale profiles shown during refresh.
    private var currentLoadedProfile: CachedCityProfile? {
        switch state {
        case .refreshing(let profile, _), .loaded(let profile, _):
            return profile
        case .idle, .needsLocationPermission, .requestingLocation, .loading, .locationUnavailable, .profileUnavailable:
            return nil
        }
    }

    /// Staleness flag attached to the currently visible loaded profile.
    private var currentLoadedProfileIsStale: Bool {
        switch state {
        case .refreshing(_, let isStale), .loaded(_, let isStale):
            return isStale
        case .idle, .needsLocationPermission, .requestingLocation, .loading, .locationUnavailable, .profileUnavailable:
            return false
        }
    }

    /// Applies one authorization action to ViewModel state and Core Location requests.
    ///
    /// This is the only method that translates authorization actions into
    /// concrete state changes and `CLLocationManager` calls.
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
