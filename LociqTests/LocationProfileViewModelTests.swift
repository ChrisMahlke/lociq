//
//  LocationProfileViewModelTests.swift
//  LociqTests
//
//  Verifies profile ViewModel state transitions, cache behavior, and retry logic.
//

import CoreLocation
import Foundation
import Testing
@testable import Lociq

@MainActor
struct LocationProfileViewModelTests {
    /// Verifies the app waits for an explicit user action before requesting first-run location access.
    @Test func activateWithUndeterminedPermissionWaitsForUserAction() async throws {
        let manager = FakeLocationManager(authorizationStatus: .notDetermined)
        let viewModel = Self.makeViewModel(
            cacheStore: Self.makeCacheStore(),
            manager: manager,
            loader: StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        )

        viewModel.activate()

        guard case .needsLocationPermission = viewModel.state else {
            Issue.record("Expected location permission prompt state")
            return
        }
        #expect(manager.didRequestAuthorization == false)

        viewModel.requestLocationAccess()

        guard case .requestingLocation = viewModel.state else {
            Issue.record("Expected requesting location state")
            return
        }
        #expect(manager.didRequestAuthorization)
    }

    /// Verifies denied location permission produces the minimal unavailable state when no cache exists.
    @Test func deniedPermissionShowsLocationUnavailableWithoutCache() async throws {
        let viewModel = Self.makeViewModel(
            cacheStore: Self.makeCacheStore(),
            manager: FakeLocationManager(authorizationStatus: .denied),
            loader: StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        )

        viewModel.activate()

        guard case .locationUnavailable = viewModel.state else {
            Issue.record("Expected location unavailable state")
            return
        }
    }

    /// Verifies stale cached profiles are shown without exposing cache state to users.
    @Test func staleCachedProfileIsDisplayedAsCached() async throws {
        let now = Date(timeIntervalSinceReferenceDate: 200_000)
        let store = Self.makeCacheStore()
        store.save(Self.cachedProfile(cachedAt: now.addingTimeInterval(-90_000)))

        let viewModel = Self.makeViewModel(
            cacheStore: store,
            manager: FakeLocationManager(authorizationStatus: .notDetermined),
            loader: StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile(cachedAt: now))]),
            now: { now }
        )

        guard case .loaded(_, let isStale) = viewModel.state else {
            Issue.record("Expected cached loaded state")
            return
        }
        #expect(isStale)
        #expect(viewModel.snapshot.dateLabel.isEmpty)
    }

    /// Verifies successful location loads save a fresh cache entry using the injected clock.
    @Test func successfulLocationLoadStoresFreshProfile() async throws {
        let now = Date(timeIntervalSinceReferenceDate: 300_000)
        let store = Self.makeCacheStore()
        let loadedProfile = Self.cachedProfile(cachedAt: now)
        let loader = StubCityProfileLoader(outcomes: [.loaded(loadedProfile)])
        let viewModel = Self.makeViewModel(
            cacheStore: store,
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: loader,
            now: { now }
        )

        viewModel.handleLocationUpdate(Self.location())
        await viewModel.waitForPendingLoad()

        guard case .loaded(let profile, let isStale) = viewModel.state else {
            Issue.record("Expected loaded state")
            return
        }
        #expect(profile.snapshot.market == "CAMBRIDGE, MASSACHUSETTS")
        #expect(isStale == false)
        #expect(store.load()?.cachedAt == now)
        #expect(await loader.requestCount() == 1)
    }

    /// Verifies recoverable service failures preserve retry context.
    @Test func unavailableProfileStatePreservesFailureForRetry() async throws {
        let coordinate = CLLocationCoordinate2D(latitude: 42.3736, longitude: -71.1056)
        let unavailable = CityProfileLoadOutcome.unavailable(
            snapshot: .status(for: .serviceUnavailable, market: "CAMBRIDGE"),
            boundary: nil,
            coordinate: coordinate,
            horizontalAccuracy: 80,
            failure: .serviceUnavailable
        )
        let loader = StubCityProfileLoader(outcomes: [
            unavailable,
            .loaded(Self.cachedProfile())
        ])
        let viewModel = Self.makeViewModel(
            cacheStore: Self.makeCacheStore(),
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: loader
        )

        viewModel.handleLocationUpdate(Self.location())
        await viewModel.waitForPendingLoad()

        guard case .profileUnavailable(_, _, _, _, let failure) = viewModel.state else {
            Issue.record("Expected profile unavailable state")
            return
        }
        #expect(failure == .serviceUnavailable)
        #expect(viewModel.canRetry)

        viewModel.retry()
        await viewModel.waitForPendingLoad()

        guard case .loaded(_, let isStale) = viewModel.state else {
            Issue.record("Expected retry to load profile")
            return
        }
        #expect(isStale == false)
        #expect(await loader.requestCount() == 2)
    }

    /// Verifies stale asynchronous profile responses cannot overwrite a newer coordinate load.
    @Test func olderProfileLoadCannotOverwriteNewerLocation() async throws {
        let firstCoordinate = CLLocationCoordinate2D(latitude: 42.3736, longitude: -71.1056)
        let secondCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let firstProfile = Self.cachedProfile(
            market: "CAMBRIDGE, MASSACHUSETTS",
            latitude: firstCoordinate.latitude,
            longitude: firstCoordinate.longitude
        )
        let secondProfile = Self.cachedProfile(
            market: "SAN FRANCISCO, CALIFORNIA",
            latitude: secondCoordinate.latitude,
            longitude: secondCoordinate.longitude
        )
        let loader = StubCityProfileLoader(
            outcomes: [.loaded(firstProfile), .loaded(secondProfile)],
            delays: [80_000_000, 0]
        )
        let viewModel = Self.makeViewModel(
            cacheStore: Self.makeCacheStore(),
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: loader
        )

        viewModel.handleLocationUpdate(CLLocation(latitude: firstCoordinate.latitude, longitude: firstCoordinate.longitude))
        viewModel.handleLocationUpdate(CLLocation(latitude: secondCoordinate.latitude, longitude: secondCoordinate.longitude))
        await viewModel.waitForPendingLoad()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(viewModel.snapshot.market == "SAN FRANCISCO, CALIFORNIA")
    }
}

private extension LocationProfileViewModelTests {
    /// Creates a ViewModel with fake dependencies for deterministic tests.
    static func makeViewModel(
        cacheStore: CityProfileCacheStore,
        manager: FakeLocationManager,
        loader: StubCityProfileLoader,
        now: @escaping @Sendable () -> Date = { Date(timeIntervalSinceReferenceDate: 100_000) }
    ) -> LocationProfileViewModel {
        LocationProfileViewModel(
            cacheStore: cacheStore,
            locationManager: manager,
            profileLoader: loader,
            now: now
        )
    }

    /// Creates an isolated cache store for one test.
    static func makeCacheStore() -> CityProfileCacheStore {
        let suiteName = "lociq.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return CityProfileCacheStore(defaults: defaults)
    }

    /// Returns the default Cambridge fixture location.
    static func location() -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 42.3736, longitude: -71.1056),
            altitude: 0,
            horizontalAccuracy: 80,
            verticalAccuracy: 0,
            timestamp: Date(timeIntervalSinceReferenceDate: 100_000)
        )
    }

    /// Creates a cacheable profile fixture.
    static func cachedProfile(
        market: String = "CAMBRIDGE, MASSACHUSETTS",
        latitude: Double = 42.3736,
        longitude: Double = -71.1056,
        cachedAt: Date = Date(timeIntervalSinceReferenceDate: 100_000)
    ) -> CachedCityProfile {
        CachedCityProfile(
            snapshot: DemographicSnapshot(
                market: market,
                dateLabel: "",
                cadence: "",
                mode: "DEMOGRAPHICS",
                confidence: 0.84,
                hasDemographicData: true,
                metrics: [
                    DemographicMetric(
                        title: "POPULATION",
                        primaryValue: "118,214",
                        detail: "MEDIAN AGE 30.8"
                    )
                ],
                detailSections: []
            ),
            boundary: sampleBoundary(),
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracy: 80,
            cachedAt: cachedAt
        )
    }

    /// Returns a rectangular GeoJSON fixture around Cambridge.
    static func sampleBoundary() -> GeoJSONFeatureCollection {
        GeoJSONFeatureCollection(
            type: "FeatureCollection",
            features: [
                GeoJSONFeature(
                    type: "Feature",
                    properties: [:],
                    geometry: .polygon([
                        [
                            [-71.12, 42.36],
                            [-71.08, 42.36],
                            [-71.08, 42.39],
                            [-71.12, 42.39],
                            [-71.12, 42.36]
                        ]
                    ])
                )
            ]
        )
    }
}

private final class FakeLocationManager: LocationManaging {
    weak var delegate: CLLocationManagerDelegate?
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyHundredMeters
    var authorizationStatus: CLAuthorizationStatus
    private(set) var didRequestAuthorization = false
    private(set) var didRequestLocation = false

    /// Creates a fake location manager with the supplied authorization state.
    init(authorizationStatus: CLAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
    }

    /// Records that authorization was requested.
    func requestWhenInUseAuthorization() {
        didRequestAuthorization = true
    }

    /// Records that a location update was requested.
    func requestLocation() {
        didRequestLocation = true
    }
}

private actor StubCityProfileLoader: CityProfileLoading {
    private var outcomes: [CityProfileLoadOutcome]
    private var delays: [UInt64]
    private var requests: [CLLocationCoordinate2D] = []

    /// Creates a profile loader that returns queued outcomes with optional delays.
    init(outcomes: [CityProfileLoadOutcome], delays: [UInt64] = []) {
        self.outcomes = outcomes
        self.delays = delays
    }

    /// Returns the next queued profile-load outcome.
    func loadProfile(
        for coordinate: CLLocationCoordinate2D,
        horizontalAccuracy: CLLocationAccuracy?
    ) async -> CityProfileLoadOutcome {
        requests.append(coordinate)
        let outcome = outcomes.count > 1 ? outcomes.removeFirst() : outcomes[0]
        if !delays.isEmpty {
            let delay = delays.removeFirst()
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
        }
        return outcome
    }

    /// Returns the number of load requests received by the stub.
    func requestCount() -> Int {
        requests.count
    }
}
