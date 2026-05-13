import CoreLocation
import Foundation
import Testing
@testable import Lociq

@MainActor
struct LocationProfileViewModelTests {
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
        #expect(viewModel.snapshot.dateLabel == "CACHED")
    }

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
}

private extension LocationProfileViewModelTests {
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

    static func makeCacheStore() -> CityProfileCacheStore {
        let suiteName = "lociq.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return CityProfileCacheStore(defaults: defaults)
    }

    static func location() -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 42.3736, longitude: -71.1056),
            altitude: 0,
            horizontalAccuracy: 80,
            verticalAccuracy: 0,
            timestamp: Date(timeIntervalSinceReferenceDate: 100_000)
        )
    }

    static func cachedProfile(cachedAt: Date = Date(timeIntervalSinceReferenceDate: 100_000)) -> CachedCityProfile {
        CachedCityProfile(
            snapshot: DemographicSnapshot(
                market: "CAMBRIDGE, MASSACHUSETTS",
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
            latitude: 42.3736,
            longitude: -71.1056,
            horizontalAccuracy: 80,
            cachedAt: cachedAt
        )
    }

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

    init(authorizationStatus: CLAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
    }

    func requestWhenInUseAuthorization() {
        didRequestAuthorization = true
    }

    func requestLocation() {
        didRequestLocation = true
    }
}

private actor StubCityProfileLoader: CityProfileLoading {
    private var outcomes: [CityProfileLoadOutcome]
    private var requests: [CLLocationCoordinate2D] = []

    init(outcomes: [CityProfileLoadOutcome]) {
        self.outcomes = outcomes
    }

    func loadProfile(
        for coordinate: CLLocationCoordinate2D,
        horizontalAccuracy: CLLocationAccuracy?
    ) async -> CityProfileLoadOutcome {
        requests.append(coordinate)
        if outcomes.count > 1 {
            return outcomes.removeFirst()
        }
        return outcomes[0]
    }

    func requestCount() -> Int {
        requests.count
    }
}
