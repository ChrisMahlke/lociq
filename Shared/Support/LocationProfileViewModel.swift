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
#if os(iOS)
import UIKit
#endif

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
    /// about whether data exists or whether it is for the user's place.
    enum State {
        case idle
        case needsLocationPermission
        case requestingLocation
        case loading
        case refreshing(CachedCityProfile, context: RefreshContext)
        case loaded(CachedCityProfile, status: ProfileStatus)
        case locationUnavailable(LocationUnavailableReason)
        case profileUnavailable(CityProfileUnavailable)
    }

    /// Result of a user-initiated refresh, used for the brief confirmation.
    enum RefreshOutcome: Equatable {
        /// A fresh fix and a real Census load succeeded.
        case updated

        /// The load failed; the saved profile stays on screen.
        case failed(CityProfileLoadFailure)

        /// No location fix arrived; the saved profile stays on screen.
        case unableToLocate
    }

    /// One published refresh result. The id makes repeated outcomes distinct.
    struct RefreshEvent: Equatable {
        let id: Int
        let outcome: RefreshOutcome
    }

    /// Where a refresh was requested.
    enum RefreshTrigger {
        /// The refresh button or menu item: a deliberate tap, which may open Settings.
        case button

        /// Pull-to-refresh and the Refresh command, which never leave the app.
        case pull
    }

    /// Why a load started, which decides its feedback.
    private enum LoadPurpose {
        /// Location arrived on its own (launch, foreground). No haptic.
        case automatic

        /// The user granted permission or tapped Retry.
        case userInitiated

        /// The user asked to refresh a displayed profile.
        case userRefresh
    }

    /// Current state machine value observed by SwiftUI.
    @Published private(set) var state: State = .idle {
        didSet { stateDidChange() }
    }

    /// Incrementing token that restarts the boundary trace when the displayed place changes.
    @Published private(set) var traceToken = 0

    /// Boundary outline for the displayed place, built off the main actor.
    @Published private(set) var boundaryGlyph: BoundaryGlyph?

    /// Latest user-initiated refresh result.
    @Published private(set) var refreshEvent: RefreshEvent?

    /// View-facing projection of `state`, recomputed once per state change.
    private(set) var viewState: LocationProfileViewState

    /// Location manager abstraction, real in production and fake in tests.
    private let manager: LocationManaging

    /// Profile loading dependency that hides Census service composition.
    private let profileLoader: any CityProfileLoading

    /// Optional launch-argument coordinate used for deterministic debug testing.
    private let debugCoordinate: CLLocationCoordinate2D?

    /// Local cache for the last successful profile.
    private let cacheStore: CityProfileCacheStore

    /// Clock dependency for testable fix ages and load durations.
    private let now: @Sendable () -> Date

    /// Haptic closure invoked once when the first user-initiated profile resolves.
    private let playProfileResolvedHaptic: @MainActor () -> Void

    /// Opens LOC IQ's page in Settings.
    private let openSettingsAction: @MainActor () -> Void

    /// Pure authorization transition helper.
    private let authorizationCoordinator: LocationAuthorizationCoordinator

    /// Pure reload-decision helper.
    private let profileLoadPlanner: ProfileLoadPlanner

    /// Total time allowed for the location attempts of one request.
    private let locationTimeout: TimeInterval

    /// Oldest fix accepted as current.
    private let maximumFixAge: TimeInterval = 120

    /// Last rounded coordinate key requested while no profile was shown.
    private var lastLoadedCoordinateKey: String?

    /// Identifier for the currently active async profile load.
    private var activeLoadID: UUID?

    /// Coordinate of the active load, used to ignore repeats of the same fix.
    private var inFlightCoordinate: CLLocationCoordinate2D?

    /// The current load task, retained so tests can await it and new loads can cancel it.
    private var loadTask: Task<Void, Never>?

    /// The latest cache write, retained so tests can await it.
    private var saveTask: Task<Void, Never>?

    /// Prevents repeated first-profile haptics.
    private var hasPlayedProfileResolvedHaptic = false

    /// Consecutive failed location attempts without a profile on screen.
    private var consecutiveLocationFailures = 0

    /// Deadline for the current sequence of location attempts.
    private var locationDeadline: Date?

    /// Watchdog that ends a location request that never answers.
    private var locationWatchdog: Task<Void, Never>?

    /// Refreshes waiting for the next fix.
    private var locationWaiters: [CheckedContinuation<LocationFix?, Never>] = []

    /// True when the next load follows a user action (permission, Retry).
    private var pendingUserInitiatedLoad = false

    /// True when a refresh asked for permission and should load once located.
    private var pendingRefreshAfterAuthorization = false

    /// Counter for refresh event ids.
    private var refreshEventCounter = 0

    /// Key of the glyph currently built or being built.
    private var glyphKey: String?

    /// Place of the glyph currently built or being built.
    private var glyphPlaceKey: String?

    /// Off-main glyph build.
    private var glyphTask: Task<Void, Never>?

    /// Creates the location profile state machine and wires together location, cache, and Census profile dependencies.
    ///
    /// Production defaults construct the real Core Location manager, one
    /// shared Census client graph, the cache store, haptics, and the Settings
    /// opener. Tests can inject every side-effecting dependency.
    init(
        debugCoordinate: CLLocationCoordinate2D? = nil,
        cacheStore: CityProfileCacheStore? = nil,
        locationManager: LocationManaging = CLLocationManager(),
        profileLoader: (any CityProfileLoading)? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        profileResolvedHaptic: @escaping @MainActor () -> Void = { Haptics.profileResolved() },
        openSettings: @escaping @MainActor () -> Void = { LocationProfileViewModel.openAppSettings() },
        vintage: CensusDataVintage = .current,
        locationTimeout: TimeInterval = 15,
        maxLocationAttempts: Int = 2
    ) {
        manager = locationManager
        self.profileLoader = profileLoader ?? Self.makeProductionLoader(vintage: vintage)
        self.debugCoordinate = debugCoordinate
        self.cacheStore = cacheStore ?? CityProfileCacheStore()
        self.now = now
        playProfileResolvedHaptic = profileResolvedHaptic
        openSettingsAction = openSettings
        authorizationCoordinator = LocationAuthorizationCoordinator(maxLocationAttempts: maxLocationAttempts)
        profileLoadPlanner = ProfileLoadPlanner(vintage: vintage, now: now)
        self.locationTimeout = locationTimeout
        viewState = LocationProfileViewStateMapper.make(from: .idle, debugCoordinate: debugCoordinate)
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        // Restore cached content immediately so launch does not wait for the
        // network. Without location access the city is labeled as the last
        // location rather than presented as current.
        if let cached = self.cacheStore.load()?.normalizedForDisplay() {
            let status: ProfileStatus = debugCoordinate == nil
                ? Self.restoredStatus(for: manager.authorizationStatus)
                : .current
            state = .loaded(cached, status: status)
            traceToken += 1
        }
        stateDidChange()
    }

    /// Builds the production loader over one shared Census client graph.
    private static func makeProductionLoader(vintage: CensusDataVintage) -> any CityProfileLoading {
        let censusAPIKey = AppConfig.censusAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let graph = CensusServiceGraph(censusAPIKey: censusAPIKey, vintage: vintage)
        return CensusCityProfileLoader(
            profileService: graph.profileService,
            geocoderClient: graph.geocoderClient,
            hasCensusAPIKey: !censusAPIKey.isEmpty,
            vintage: vintage
        )
    }

    /// Opens LOC IQ's own page in the Settings app.
    ///
    /// watchOS offers no way to open Settings from an app, so the watch app
    /// says where to allow location instead, and this does nothing there.
    static func openAppSettings() {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    /// Status for a profile restored from disk, based on location access.
    private static func restoredStatus(for status: CLAuthorizationStatus) -> ProfileStatus {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return .current
        case .notDetermined:
            return .lastLocation
        case .denied:
            return .locationOff(restricted: false)
        case .restricted:
            return .locationOff(restricted: true)
        @unknown default:
            return .locationOff(restricted: true)
        }
    }

    // MARK: - View-facing values

    /// Current display snapshot projected from the state machine.
    var snapshot: DemographicSnapshot {
        viewState.snapshot
    }

    /// True while location or profile loading is active.
    var isBusy: Bool {
        viewState.isBusy
    }

    /// True when the primary action retries a failed step.
    var canRetry: Bool {
        viewState.primaryAction == .retry
    }

    // MARK: - Actions

    /// Starts or resumes the location/profile workflow based on the current authorization state.
    ///
    /// Debug coordinates bypass Core Location so simulator and regression tests
    /// can load a known city deterministically.
    func activate() {
        if let debugCoordinate {
            handleFix(LocationFix(coordinate: debugCoordinate, horizontalAccuracy: nil, isApproximate: false))
            return
        }

        perform(
            authorizationCoordinator.activationAction(
                for: manager.authorizationStatus,
                hasLoadedProfile: currentLoadedProfile != nil
            )
        )
    }

    /// Asks for location access from the first-run prompt.
    ///
    /// Once access has been decided, the system prompt cannot appear again, so
    /// a denial routes to Settings and an authorized state simply locates.
    func requestLocationAccess() {
        switch manager.authorizationStatus {
        case .notDetermined:
            pendingUserInitiatedLoad = true
            state = .requestingLocation
            manager.requestWhenInUseAuthorization()
        case .denied:
            openLocationSettings()
        case .restricted:
            break
        case .authorizedAlways, .authorizedWhenInUse:
            retry()
        @unknown default:
            break
        }
    }

    /// Opens LOC IQ's page in Settings so the user can allow location access.
    ///
    /// When the user returns with access enabled, the authorization callback
    /// locates and loads the city without a relaunch.
    func openLocationSettings() {
        openSettingsAction()
    }

    /// Retries the last recoverable failure without requiring the user to restart the app.
    ///
    /// Retry clears the duplicate coordinate key and the failure count, so the
    /// same coordinate can be requested again after a transient failure.
    func retry() {
        lastLoadedCoordinateKey = nil
        consecutiveLocationFailures = 0
        locationDeadline = nil
        pendingUserInitiatedLoad = true

        switch state {
        case .profileUnavailable(let unavailable):
            let request = CityProfileLoadRequest(
                coordinate: unavailable.coordinate,
                horizontalAccuracy: unavailable.horizontalAccuracy,
                isApproximate: unavailable.isApproximate,
                forceRefresh: true
            )
            startLoad(
                request,
                coordinateKey: ProfileLoadPlanner.coordinateKey(for: unavailable.coordinate),
                preLoadState: .loading,
                purpose: .userInitiated
            )
        case .needsLocationPermission, .locationUnavailable, .idle, .requestingLocation, .loading, .refreshing, .loaded:
            activate()
        }
    }

    /// Refreshes the displayed city: locates first, then reloads Census data.
    ///
    /// The route depends on location access. Without a decision, the system
    /// prompt appears and the city loads once access is granted. With location
    /// off, Settings opens. With access, a fresh fix is loaded with the current
    /// city kept on screen; "UPDATED NOW" is reported only after a real load.
    /// In a failure state, a transient failure is retried instead.
    func refresh(trigger: RefreshTrigger = .button) async {
        if activeLoadID != nil {
            await waitForPendingLoad()
            return
        }
        // A refresh is already waiting for its fix; a second one adds nothing.
        guard locationWaiters.isEmpty else { return }
        guard let profile = currentLoadedProfile else {
            if viewState.canPullToRefresh {
                retry()
                await waitForPendingLoad()
            }
            return
        }

        if let debugCoordinate {
            await refreshLoad(
                fix: LocationFix(coordinate: debugCoordinate, horizontalAccuracy: nil, isApproximate: false),
                previous: profile
            )
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            pendingRefreshAfterAuthorization = true
            manager.requestWhenInUseAuthorization()
        case .denied:
            if trigger == .button {
                openLocationSettings()
            }
        case .restricted:
            break
        case .authorizedAlways, .authorizedWhenInUse:
            pendingRefreshAfterAuthorization = false
            state = .refreshing(profile, context: .sameArea)
            guard let fix = await requestFreshFix() else {
                if case .refreshing(let visible, _) = state {
                    state = .loaded(visible, status: labeledStatus(.lastKnownArea))
                }
                publishRefreshEvent(.unableToLocate)
                return
            }
            await refreshLoad(fix: fix, previous: currentLoadedProfile ?? profile)
        @unknown default:
            break
        }
    }

    /// Waits for the active profile load and cache write to finish.
    func waitForPendingLoad() async {
        await loadTask?.value
        await saveTask?.value
    }

    // MARK: - Core Location input

    /// Applies a Core Location authorization transition to the state machine.
    ///
    /// The coordinator decides the action. The view model performs the action so
    /// all mutations remain centralized.
    func handleAuthorizationChange(_ authorizationStatus: CLAuthorizationStatus) {
        guard debugCoordinate == nil else { return }
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse, .notDetermined:
            break
        default:
            pendingRefreshAfterAuthorization = false
        }
        perform(
            authorizationCoordinator.changeAction(
                for: authorizationStatus,
                hasLoadedProfile: currentLoadedProfile != nil
            )
        )
    }

    /// Handles the newest location update.
    ///
    /// Invalid fixes (negative accuracy) and fixes older than two minutes are
    /// treated as failed attempts rather than shown as the current location.
    func handleLocationUpdate(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0, now().timeIntervalSince(location.timestamp) <= maximumFixAge else {
            handleLocationFailure(authorizationStatus: manager.authorizationStatus)
            return
        }
        handleFix(
            LocationFix(
                coordinate: location.coordinate,
                horizontalAccuracy: location.horizontalAccuracy,
                isApproximate: manager.accuracyAuthorization == .reducedAccuracy
            )
        )
    }

    /// Converts a location failure into the least noisy honest state.
    ///
    /// With a profile on screen, the profile stays and is labeled as the last
    /// known area. Without one, the attempt is retried once, then the explained
    /// no-fix state offers Retry, so the spinner can never run unbounded.
    func handleLocationFailure(authorizationStatus: CLAuthorizationStatus) {
        cancelLocationWatchdog()
        if !locationWaiters.isEmpty {
            resumeLocationWaiters(with: nil)
            return
        }
        if currentLoadedProfile != nil {
            locationDeadline = nil
            markDisplayedProfileAsLastKnownArea()
            return
        }
        consecutiveLocationFailures += 1
        perform(
            authorizationCoordinator.failureAction(
                for: authorizationStatus,
                consecutiveFailures: consecutiveLocationFailures
            )
        )
    }

    // MARK: - Location plumbing

    /// Routes one usable fix: to a waiting refresh, or through the planner.
    private func handleFix(_ fix: LocationFix) {
        cancelLocationWatchdog()
        consecutiveLocationFailures = 0
        locationDeadline = nil

        if !locationWaiters.isEmpty {
            // The waiting refresh force-loads this fix itself.
            pendingRefreshAfterAuthorization = false
            resumeLocationWaiters(with: fix)
            return
        }

        if pendingRefreshAfterAuthorization, let profile = currentLoadedProfile {
            pendingRefreshAfterAuthorization = false
            Task { await self.refreshLoad(fix: fix, previous: profile) }
            return
        }

        // A load is already on its way. A repeat of the same spot adds nothing;
        // a fix somewhere else supersedes it, as the newest location wins.
        if activeLoadID != nil {
            guard
                let inFlightCoordinate,
                Self.distance(inFlightCoordinate, fix.coordinate) > ProfileLoadPlanner.sameSpotRadiusMeters
            else { return }
        }

        let decision = profileLoadPlanner.decide(
            fix: fix,
            currentProfile: currentLoadedProfile,
            lastCoordinateKey: lastLoadedCoordinateKey,
            force: false
        )
        switch decision {
        case .suppressDuplicate:
            return
        case .keepProfile(let profile):
            // Still in the displayed place, with current data: no network.
            // Any load for a place the user already left is abandoned.
            cancelActiveLoad()
            pendingUserInitiatedLoad = false
            let previousMarker = currentLoadedProfile?.markerCoordinate
            state = .loaded(profile, status: .current)
            if let previousMarker, Self.distance(previousMarker, profile.markerCoordinate) > 50 {
                persist(profile)
            }
        case .load(let coordinateKey, let preLoadState):
            startLoad(
                request(for: fix, force: false, previous: currentLoadedProfile),
                coordinateKey: coordinateKey,
                preLoadState: preLoadState,
                purpose: pendingUserInitiatedLoad ? .userInitiated : .automatic
            )
        }
    }

    /// Asks Core Location for one fix, bounded by the location timeout.
    ///
    /// A request already in progress is not duplicated. The deadline covers
    /// the whole sequence of attempts, not each attempt.
    private func requestLocationFix() {
        guard debugCoordinate == nil else { return }
        let deadline = locationDeadline ?? now().addingTimeInterval(locationTimeout)
        locationDeadline = deadline
        guard locationWatchdog == nil else { return }
        manager.requestLocation()

        let remaining = min(max(deadline.timeIntervalSince(now()), 0.01), locationTimeout)
        locationWatchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.handleLocationTimeout()
        }
    }

    /// Ends a location request that produced no callback in time.
    private func handleLocationTimeout() {
        locationWatchdog = nil
        locationDeadline = nil
        if !locationWaiters.isEmpty {
            resumeLocationWaiters(with: nil)
            return
        }
        if currentLoadedProfile != nil {
            markDisplayedProfileAsLastKnownArea()
            return
        }
        guard case .requestingLocation = state else { return }
        perform(.showLocationUnavailable(.noFix))
    }

    /// Waits for the next fix on behalf of a refresh.
    private func requestFreshFix() async -> LocationFix? {
        await withCheckedContinuation { continuation in
            locationWaiters.append(continuation)
            requestLocationFix()
        }
    }

    /// Resumes every waiting refresh exactly once.
    ///
    /// Resuming ends the refresh's attempt sequence, so its deadline is
    /// cleared; the next refresh gets a full timeout of its own.
    private func resumeLocationWaiters(with fix: LocationFix?) {
        locationDeadline = nil
        let waiters = locationWaiters
        locationWaiters = []
        for waiter in waiters {
            waiter.resume(returning: fix)
        }
    }

    /// Labels the displayed profile after a failed fix.
    ///
    /// Any label is replaced except "not your current location", which is
    /// more specific. A refresh that asked for access and then got no fix
    /// reports that it could not locate.
    private func markDisplayedProfileAsLastKnownArea() {
        if pendingRefreshAfterAuthorization {
            pendingRefreshAfterAuthorization = false
            publishRefreshEvent(.unableToLocate)
        }
        guard case .loaded(let profile, let status) = state, status != .notCurrentLocation else { return }
        state = .loaded(profile, status: labeledStatus(.lastKnownArea))
    }

    /// Returns a status that respects current location access.
    ///
    /// Work that finishes after access changed, such as a load that was
    /// already running, must not present the city as current without access,
    /// and a location-off label must not outlive access being restored.
    private func labeledStatus(_ status: ProfileStatus) -> ProfileStatus {
        guard debugCoordinate == nil else { return status }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return status
        default:
            return Self.restoredStatus(for: manager.authorizationStatus)
        }
    }

    /// Cancels the location watchdog.
    private func cancelLocationWatchdog() {
        locationWatchdog?.cancel()
        locationWatchdog = nil
    }

    /// Stops waiting for a fix, for example when access was just revoked.
    private func cancelLocationRequest() {
        cancelLocationWatchdog()
        locationDeadline = nil
        resumeLocationWaiters(with: nil)
    }

    // MARK: - Loading

    /// Force-loads a fresh fix for a refresh, keeping the displayed city visible.
    private func refreshLoad(fix: LocationFix, previous: CachedCityProfile) async {
        guard case .load(let coordinateKey, let preLoadState) = profileLoadPlanner.decide(
            fix: fix,
            currentProfile: previous,
            lastCoordinateKey: nil,
            force: true
        ) else { return }
        startLoad(
            request(for: fix, force: true, previous: previous),
            coordinateKey: coordinateKey,
            preLoadState: preLoadState,
            purpose: .userRefresh
        )
        await waitForPendingLoad()
    }

    /// Builds a load request, offering the displayed boundary for reuse.
    ///
    /// The boundary is reused only for the same place and data vintage; the
    /// service checks the place after geocoding.
    private func request(for fix: LocationFix, force: Bool, previous: CachedCityProfile?) -> CityProfileLoadRequest {
        let knownBoundary: KnownPlaceBoundary? = previous.flatMap { profile in
            guard
                profile.isCurrent(for: profileLoadPlanner.vintage),
                let geoid = profile.resolvedPlaceGeoid,
                let boundary = profile.boundary
            else { return nil }
            return KnownPlaceBoundary(geoid: geoid, boundary: boundary)
        }
        return CityProfileLoadRequest(
            coordinate: fix.coordinate,
            horizontalAccuracy: fix.horizontalAccuracy,
            isApproximate: fix.isApproximate,
            forceRefresh: force,
            knownBoundary: knownBoundary
        )
    }

    /// Starts one profile load with a unique identity.
    ///
    /// Each load receives a UUID so late responses from cancelled tasks cannot
    /// overwrite newer data. The cache write runs off the main actor as part of
    /// the load task, so awaiting the load also awaits the write.
    private func startLoad(
        _ request: CityProfileLoadRequest,
        coordinateKey: String,
        preLoadState: State,
        purpose: LoadPurpose
    ) {
        lastLoadedCoordinateKey = coordinateKey
        pendingUserInitiatedLoad = false
        let previous = currentLoadedProfile
        let context: RefreshContext? = {
            if case .refreshing(_, let context) = preLoadState { return context }
            return nil
        }()
        state = preLoadState

        let loadID = UUID()
        activeLoadID = loadID
        inFlightCoordinate = request.coordinate
        let startedAt = now()
        loadTask?.cancel()
        loadTask = Task { [weak self, profileLoader, cacheStore] in
            let outcome = await profileLoader.loadProfile(request)
            guard
                let profile = self?.apply(
                    outcome,
                    loadID: loadID,
                    startedAt: startedAt,
                    previous: previous,
                    context: context,
                    purpose: purpose
                )
            else { return }
            await cacheStore.save(profile)
        }
    }

    /// Applies the result for the currently active request and ignores stale responses.
    ///
    /// - Returns: The profile to persist, if the outcome produced one.
    private func apply(
        _ outcome: CityProfileLoadOutcome,
        loadID: UUID,
        startedAt: Date,
        previous: CachedCityProfile?,
        context: RefreshContext?,
        purpose: LoadPurpose
    ) -> CachedCityProfile? {
        guard loadID == activeLoadID else { return nil }
        activeLoadID = nil
        inFlightCoordinate = nil

        switch outcome {
        case .loaded(let loaded):
            let profile = loaded.withCachedAt(now()).normalizedForDisplay()
            let placeChanged = previous?.resolvedPlaceGeoid == nil
                || previous?.resolvedPlaceGeoid != profile.resolvedPlaceGeoid
            state = .loaded(profile, status: labeledStatus(.current))
            if placeChanged {
                // Replay the outline only for a new place, never for a reload.
                traceToken += 1
            }
            switch purpose {
            case .userInitiated:
                playProfileResolvedHapticIfNeeded()
            case .userRefresh:
                publishRefreshEvent(.updated)
            case .automatic:
                break
            }
            LociqDiagnostics.cityProfileLoadCompleted(duration: now().timeIntervalSince(startedAt))
            return profile
        case .unavailable(let unavailable):
            if let previous {
                if context == .newLocation, !unavailable.failure.isRetryable {
                    // The new location has no city data (for example outside
                    // city limits). Show that, not the place the user left.
                    state = .profileUnavailable(unavailable)
                } else if context == .newLocation {
                    state = .loaded(previous, status: labeledStatus(.notCurrentLocation))
                } else {
                    state = .loaded(previous, status: labeledStatus(.savedAfterFailedRefresh(unavailable.failure)))
                }
            } else {
                state = .profileUnavailable(unavailable)
            }
            if purpose == .userRefresh {
                publishRefreshEvent(.failed(unavailable.failure))
            }
            LociqDiagnostics.cityProfileLoadFailed(unavailable.failure)
            return nil
        }
    }

    /// Abandons the active load so its result is ignored.
    private func cancelActiveLoad() {
        guard activeLoadID != nil else { return }
        loadTask?.cancel()
        activeLoadID = nil
        inFlightCoordinate = nil
    }

    /// Writes a profile to the cache without blocking the main actor.
    private func persist(_ profile: CachedCityProfile) {
        saveTask = Task { [cacheStore] in
            await cacheStore.save(profile)
        }
    }

    /// Applies one authorization action to ViewModel state and Core Location requests.
    ///
    /// This is the only method that translates authorization actions into
    /// concrete state changes and `CLLocationManager` calls.
    private func perform(_ action: LocationAuthorizationAction) {
        switch action {
        case .showPermissionPrompt:
            cancelLocationRequest()
            pendingUserInitiatedLoad = false
            consecutiveLocationFailures = 0
            state = .needsLocationPermission
        case .requestLocation:
            // A load already under way keeps its "reading Census data" state.
            guard activeLoadID == nil else { return }
            // A fix arriving now must load even if it repeats the coordinate
            // that last failed; otherwise the spinner could wait forever.
            lastLoadedCoordinateKey = nil
            state = .requestingLocation
            requestLocationFix()
        case .showLocationUnavailable(let reason):
            cancelLocationRequest()
            pendingUserInitiatedLoad = false
            consecutiveLocationFailures = 0
            state = .locationUnavailable(reason)
        case .keepProfileAndRequestLocation:
            guard activeLoadID == nil else { return }
            requestLocationFix()
        case .markProfile(let status):
            if case .loaded(let profile, _) = state {
                state = .loaded(profile, status: status)
            }
        }
    }

    // MARK: - Derived state

    /// Recomputes the view projection and the boundary glyph after a state change.
    private func stateDidChange() {
        viewState = LocationProfileViewStateMapper.make(from: state, debugCoordinate: debugCoordinate)
        updateBoundaryGlyph()
    }

    /// Builds the boundary glyph off the main actor when the place or focus changes.
    private func updateBoundaryGlyph() {
        guard let boundary = viewState.boundary else {
            glyphTask?.cancel()
            glyphKey = nil
            glyphPlaceKey = nil
            if boundaryGlyph != nil { boundaryGlyph = nil }
            return
        }

        let focus = viewState.coordinate
        let placeKey = "\(viewState.placeKey ?? "")|\(viewState.snapshot.dataVintage ?? "-")|\(Self.vertexCount(of: boundary))"
        let focusKey = focus.map { String(format: "%.3f,%.3f", $0.latitude, $0.longitude) } ?? "-"
        let key = "\(placeKey)|\(focusKey)"
        guard key != glyphKey else { return }
        if placeKey != glyphPlaceKey {
            // Never show one place's outline with another place's numbers.
            boundaryGlyph = nil
        }
        glyphKey = key
        glyphPlaceKey = placeKey
        glyphTask?.cancel()
        glyphTask = Task { [weak self] in
            let glyph = await Task.detached(priority: .userInitiated) {
                GeoJSONBoundaryPathBuilder.glyph(for: boundary, focus: focus)
            }.value
            guard !Task.isCancelled, let self, self.glyphKey == key else { return }
            self.boundaryGlyph = glyph
        }
    }

    /// Counts a boundary's coordinates, which tells two versions of one place apart cheaply.
    private static func vertexCount(of boundary: GeoJSONFeatureCollection) -> Int {
        boundary.features.reduce(0) { total, feature in
            switch feature.geometry {
            case .polygon(let rings):
                return total + rings.reduce(0) { $0 + $1.count }
            case .multiPolygon(let polygons):
                return total + polygons.reduce(0) { sum, rings in sum + rings.reduce(0) { $0 + $1.count } }
            case .other, nil:
                return total
            }
        }
    }

    /// Records a refresh result for the confirmation line and VoiceOver.
    private func publishRefreshEvent(_ outcome: RefreshOutcome) {
        refreshEventCounter += 1
        refreshEvent = RefreshEvent(id: refreshEventCounter, outcome: outcome)
    }

    /// Emits the first user-initiated profile haptic once per app session.
    private func playProfileResolvedHapticIfNeeded() {
        guard !hasPlayedProfileResolvedHaptic else { return }
        hasPlayedProfileResolvedHaptic = true
        playProfileResolvedHaptic()
    }

    /// Currently visible profile, including one shown during a refresh.
    private var currentLoadedProfile: CachedCityProfile? {
        switch state {
        case .refreshing(let profile, _), .loaded(let profile, _):
            return profile
        case .idle, .needsLocationPermission, .requestingLocation, .loading, .locationUnavailable, .profileUnavailable:
            return nil
        }
    }

    /// Ground distance in meters between two coordinates.
    private static func distance(_ lhs: CLLocationCoordinate2D, _ rhs: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
            .distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude))
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
