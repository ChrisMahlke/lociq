//
//  LocationProfileViewModelTests.swift
//  LociqTests
//
//  Verifies profile ViewModel state transitions, cache behavior, and retry logic.
//
//  These tests exercise the view model as a state machine. Service and location
//  dependencies are replaced by fakes so each test controls authorization,
//  location updates, async outcomes, cache contents, and race ordering.
//

import CoreLocation
import Foundation
import Testing
@testable import Lociq

@MainActor
/// Tests for `LocationProfileViewModel` orchestration behavior.
struct LocationProfileViewModelTests {
    // MARK: - Permission

    /// The app waits for an explicit user action before requesting first-run location access.
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
        #expect(manager.authorizationRequestCount == 0)
        #expect(viewModel.viewState.primaryAction == .requestPermission)

        viewModel.requestLocationAccess()

        guard case .requestingLocation = viewModel.state else {
            Issue.record("Expected requesting location state")
            return
        }
        #expect(manager.authorizationRequestCount == 1)
    }

    /// UX-001: a denial without a cache offers one route to Settings, never a futile retry.
    @Test func deniedPrimaryActionOpensSettings() async throws {
        var settingsOpenCount = 0
        let viewModel = Self.makeViewModel(
            cacheStore: Self.makeCacheStore(),
            manager: FakeLocationManager(authorizationStatus: .denied),
            loader: StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())]),
            openSettings: { settingsOpenCount += 1 }
        )

        viewModel.activate()

        guard case .locationUnavailable(.denied) = viewModel.state else {
            Issue.record("Expected denied state")
            return
        }
        #expect(viewModel.viewState.primaryAction == .openSettings)
        #expect(viewModel.snapshot.market == "LOCATION OFF")
        #expect(viewModel.snapshot.statusLine == "ALLOW IN SETTINGS")
        #expect(viewModel.canRetry == false)

        viewModel.openLocationSettings()
        viewModel.requestLocationAccess()
        #expect(settingsOpenCount == 2)
    }

    /// UX-001: a restriction the user cannot change offers no action at all.
    @Test func restrictedLocationOffersNoAction() async throws {
        let viewModel = Self.makeViewModel(
            cacheStore: Self.makeCacheStore(),
            manager: FakeLocationManager(authorizationStatus: .restricted),
            loader: StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        )

        viewModel.activate()

        #expect(viewModel.viewState.primaryAction == .none)
        #expect(viewModel.viewState.canPullToRefresh == false)
        #expect(viewModel.snapshot.market == "LOCATION RESTRICTED")
    }

    /// UX-001: enabling location in Settings and returning loads the city without a relaunch.
    @Test func returningFromSettingsWithAccessLoadsCity() async throws {
        let manager = FakeLocationManager(authorizationStatus: .denied)
        let loader = StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        let viewModel = Self.makeViewModel(cacheStore: Self.makeCacheStore(), manager: manager, loader: loader)
        viewModel.activate()

        manager.authorizationStatus = .authorizedWhenInUse
        viewModel.handleAuthorizationChange(.authorizedWhenInUse)
        #expect(manager.locationRequestCount == 1)
        viewModel.handleLocationUpdate(Self.location())
        await viewModel.waitForPendingLoad()

        guard case .loaded(let profile, .current) = viewModel.state else {
            Issue.record("Expected a loaded current profile")
            return
        }
        #expect(profile.snapshot.market == "CAMBRIDGE, MA")
    }

    // MARK: - Location recovery (UX-003)

    /// UX-003: after a failure, coming back with the same fix loads again instead of spinning forever.
    @Test func reactivationAfterUnavailableReloadsSameCoordinate() async throws {
        let manager = FakeLocationManager(authorizationStatus: .authorizedWhenInUse)
        let loader = StubCityProfileLoader(outcomes: [
            .unavailable(Self.unavailable(.networkUnavailable)),
            .loaded(Self.cachedProfile())
        ])
        let viewModel = Self.makeViewModel(cacheStore: Self.makeCacheStore(), manager: manager, loader: loader)

        viewModel.activate()
        viewModel.handleLocationUpdate(Self.location())
        await viewModel.waitForPendingLoad()
        guard case .profileUnavailable = viewModel.state else {
            Issue.record("Expected the failure state")
            return
        }

        // The user fixes the connection from Control Center and returns.
        viewModel.activate()
        viewModel.handleLocationUpdate(Self.location())
        await viewModel.waitForPendingLoad()

        #expect(await loader.requestCount() == 2)
        guard case .loaded = viewModel.state else {
            Issue.record("Expected the same-cell fix to load, not a control-less spinner")
            return
        }
    }

    /// UX-003: repeated location failures end in an explained, retryable state.
    @Test func locationFailureWithoutProfileEndsInRetryableState() async throws {
        let manager = FakeLocationManager(authorizationStatus: .authorizedWhenInUse)
        let viewModel = Self.makeViewModel(
            cacheStore: Self.makeCacheStore(),
            manager: manager,
            loader: StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        )

        viewModel.activate()
        #expect(manager.locationRequestCount == 1)
        viewModel.handleLocationFailure(authorizationStatus: .authorizedWhenInUse)
        #expect(manager.locationRequestCount == 2)
        viewModel.handleLocationFailure(authorizationStatus: .authorizedWhenInUse)

        guard case .locationUnavailable(.noFix) = viewModel.state else {
            Issue.record("Expected the no-fix state after two failed attempts")
            return
        }
        #expect(manager.locationRequestCount == 2)
        #expect(viewModel.canRetry)
        #expect(viewModel.snapshot.statusLine == "CAN'T FIND YOUR LOCATION")

        viewModel.retry()
        #expect(manager.locationRequestCount == 3)
    }

    /// UX-003: a location request that never answers ends within the location timeout.
    @Test func silentLocationRequestTimesOutIntoRetryableState() async throws {
        let viewModel = Self.makeViewModel(
            cacheStore: Self.makeCacheStore(),
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())]),
            locationTimeout: 0.05
        )

        viewModel.activate()
        try await Task.sleep(nanoseconds: 300_000_000)

        guard case .locationUnavailable(.noFix) = viewModel.state else {
            Issue.record("Expected the watchdog to end the wait")
            return
        }
    }

    /// GIS-011: fixes with negative accuracy are never shown as the current location.
    @Test func invalidFixIsTreatedAsFailure() async throws {
        let manager = FakeLocationManager(authorizationStatus: .authorizedWhenInUse)
        let loader = StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        let viewModel = Self.makeViewModel(cacheStore: Self.makeCacheStore(), manager: manager, loader: loader)

        viewModel.activate()
        viewModel.handleLocationUpdate(Self.location(accuracy: -1))
        await viewModel.waitForPendingLoad()

        #expect(await loader.requestCount() == 0)
        #expect(manager.locationRequestCount == 2)
    }

    // MARK: - Allow Once and cached profiles (UX-002)

    /// UX-002: after "Allow Once" expires, the cached city is labeled and refresh asks for access first.
    @Test func notDeterminedWithCacheRefreshRequestsAuthorization() async throws {
        let store = Self.makeCacheStore()
        await store.save(Self.cachedProfile())
        let manager = FakeLocationManager(authorizationStatus: .notDetermined)
        let boston = Self.cachedProfile(market: "SAN FRANCISCO, CA", latitude: 37.7749, longitude: -122.4194, geoid: "0667000")
        let loader = StubCityProfileLoader(outcomes: [.loaded(boston)])
        let viewModel = Self.makeViewModel(cacheStore: store, manager: manager, loader: loader)

        #expect(viewModel.snapshot.statusLine == "LAST LOCATION")
        viewModel.activate()
        #expect(manager.authorizationRequestCount == 0)
        #expect(manager.locationRequestCount == 0)
        #expect(viewModel.viewState.refreshControl == .requestPermissionAndRefresh)

        await viewModel.refresh()
        #expect(manager.authorizationRequestCount == 1)
        #expect(await loader.requestCount() == 0)

        // The user allows access; the fix in another city loads that city.
        manager.authorizationStatus = .authorizedWhenInUse
        viewModel.handleAuthorizationChange(.authorizedWhenInUse)
        viewModel.handleLocationUpdate(Self.location(latitude: 37.7749, longitude: -122.4194))
        try await Task.sleep(nanoseconds: 50_000_000)
        await viewModel.waitForPendingLoad()

        #expect(viewModel.snapshot.market == "SAN FRANCISCO, CA")
        #expect(viewModel.snapshot.statusLine.isEmpty)
        #expect(viewModel.refreshEvent?.outcome == .updated)
        #expect(await loader.forcedRequestCount() == 1)
    }

    /// UX-002: with location off, the cached city says so and refresh opens Settings.
    @Test func deniedWithCacheIsLabeledAndRefreshOpensSettings() async throws {
        let store = Self.makeCacheStore()
        await store.save(Self.cachedProfile())
        var settingsOpenCount = 0
        let loader = StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        let viewModel = Self.makeViewModel(
            cacheStore: store,
            manager: FakeLocationManager(authorizationStatus: .denied),
            loader: loader,
            openSettings: { settingsOpenCount += 1 }
        )

        viewModel.activate()
        #expect(viewModel.snapshot.statusLine == "SAVED CITY · LOCATION OFF")
        #expect(viewModel.viewState.refreshControl == .openSettings)

        await viewModel.refresh()
        #expect(settingsOpenCount == 1)
        // Pulling never leaves the app.
        await viewModel.refresh(trigger: .pull)
        #expect(settingsOpenCount == 1)
        #expect(await loader.requestCount() == 0)
        #expect(viewModel.refreshEvent == nil)
    }

    /// UX-002: refresh locates first and always reaches the loader, bypassing the memo.
    @Test func refreshLocatesFirstAndForcesALoad() async throws {
        let store = Self.makeCacheStore()
        await store.save(Self.cachedProfile())
        let manager = FakeLocationManager(authorizationStatus: .authorizedWhenInUse)
        let loader = StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        let viewModel = Self.makeViewModel(cacheStore: store, manager: manager, loader: loader)
        let traceBefore = viewModel.traceToken

        let refresh = Task { await viewModel.refresh() }
        try await Task.sleep(nanoseconds: 20_000_000)
        #expect(manager.locationRequestCount == 1)
        #expect(viewModel.snapshot.statusLine == "REFRESHING")
        viewModel.handleLocationUpdate(Self.location())
        await refresh.value

        #expect(await loader.forcedRequestCount() == 1)
        #expect(viewModel.refreshEvent?.outcome == .updated)
        // Same place: no outline replay.
        #expect(viewModel.traceToken == traceBefore)
    }

    /// UX-002: when no fix arrives, refresh keeps the city and says it is the last known area.
    @Test func refreshWithoutFixKeepsCityAsLastKnownArea() async throws {
        let store = Self.makeCacheStore()
        await store.save(Self.cachedProfile())
        let loader = StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        let viewModel = Self.makeViewModel(
            cacheStore: store,
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: loader,
            locationTimeout: 0.05
        )

        await viewModel.refresh()

        #expect(viewModel.refreshEvent?.outcome == .unableToLocate)
        #expect(viewModel.snapshot.statusLine == "LAST KNOWN AREA")
        #expect(await loader.requestCount() == 0)
    }

    // MARK: - Freshness by place and vintage (GIS-004, CODE-004)

    /// CODE-004: a stationary foreground makes no network request and shows no refresh churn.
    @Test func stationaryForegroundDoesNotReload() async throws {
        let store = Self.makeCacheStore()
        await store.save(Self.cachedProfile())
        let manager = FakeLocationManager(authorizationStatus: .authorizedWhenInUse)
        let loader = StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        let viewModel = Self.makeViewModel(cacheStore: store, manager: manager, loader: loader)
        let traceBefore = viewModel.traceToken

        for _ in 0..<5 {
            viewModel.activate()
            viewModel.handleLocationUpdate(Self.location(latitude: 42.3738, longitude: -71.1052))
        }
        await viewModel.waitForPendingLoad()

        #expect(await loader.requestCount() == 0)
        #expect(viewModel.traceToken == traceBefore)
        guard case .loaded(_, .current) = viewModel.state else {
            Issue.record("Expected the current profile to stay")
            return
        }
    }

    /// GIS-004: moving inside the same place keeps the data and moves the marker.
    @Test func moveInsideBoundaryKeepsProfileAndMovesMarker() async throws {
        let store = Self.makeCacheStore()
        await store.save(Self.cachedProfile())
        let loader = StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        let viewModel = Self.makeViewModel(
            cacheStore: store,
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: loader
        )

        viewModel.activate()
        // About 1.2 km east, still well inside the sample boundary.
        viewModel.handleLocationUpdate(Self.location(latitude: 42.3736, longitude: -71.0910))
        await viewModel.waitForPendingLoad()

        #expect(await loader.requestCount() == 0)
        let marker = try #require(viewModel.viewState.coordinate)
        #expect(abs(marker.longitude - -71.0910) < 0.0001)
    }

    /// GIS-004: a fix outside the displayed place always loads, keeping the old city dimmed meanwhile.
    @Test func fixOutsideBoundaryLoadsNewPlace() async throws {
        let store = Self.makeCacheStore()
        await store.save(Self.cachedProfile())
        let sanFrancisco = Self.cachedProfile(market: "SAN FRANCISCO, CA", latitude: 37.7749, longitude: -122.4194, geoid: "0667000")
        let loader = StubCityProfileLoader(outcomes: [.loaded(sanFrancisco)], delays: [60_000_000])
        let viewModel = Self.makeViewModel(
            cacheStore: store,
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: loader
        )
        let traceBefore = viewModel.traceToken

        viewModel.activate()
        viewModel.handleLocationUpdate(Self.location(latitude: 37.7749, longitude: -122.4194))
        #expect(viewModel.viewState.isContentDimmed)
        #expect(viewModel.snapshot.statusLine == "UPDATING FOR NEW LOCATION")
        await viewModel.waitForPendingLoad()

        #expect(viewModel.snapshot.market == "SAN FRANCISCO, CA")
        #expect(viewModel.traceToken == traceBefore + 1)
    }

    /// GIS-004: when the new place cannot load, the old one is labeled as not current.
    @Test func failedLoadAfterMovingLabelsOldPlace() async throws {
        let store = Self.makeCacheStore()
        await store.save(Self.cachedProfile())
        let viewModel = Self.makeViewModel(
            cacheStore: store,
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: StubCityProfileLoader(outcomes: [.unavailable(Self.unavailable(.networkUnavailable))])
        )

        viewModel.activate()
        viewModel.handleLocationUpdate(Self.location(latitude: 37.7749, longitude: -122.4194))
        await viewModel.waitForPendingLoad()

        #expect(viewModel.snapshot.market == "CAMBRIDGE, MA")
        #expect(viewModel.snapshot.statusLine == "LAST KNOWN AREA · NOT YOUR CURRENT LOCATION")
    }

    /// GIS-004: a failed refresh minutes after a load says "saved · offline", never "stale data".
    @Test func failedRefreshKeepsCachedProfileVisibleAsSaved() async throws {
        let now = Date(timeIntervalSinceReferenceDate: 400_000)
        let store = Self.makeCacheStore()
        await store.save(Self.cachedProfile(cachedAt: now.addingTimeInterval(-300)))
        let viewModel = Self.makeViewModel(
            cacheStore: store,
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: StubCityProfileLoader(outcomes: [.unavailable(Self.unavailable(.networkUnavailable))]),
            now: { now }
        )

        let refresh = Task { await viewModel.refresh() }
        try await Task.sleep(nanoseconds: 20_000_000)
        viewModel.handleLocationUpdate(Self.location(timestamp: now))
        await refresh.value

        guard case .loaded(let profile, _) = viewModel.state else {
            Issue.record("Expected cached profile to remain loaded")
            return
        }
        #expect(profile.snapshot.market == "CAMBRIDGE, MA")
        #expect(viewModel.snapshot.statusLine == "SAVED · OFFLINE")
        #expect(viewModel.refreshEvent?.outcome == .failed(.networkUnavailable))
    }

    /// Profiles from an older release or format reload once, even inside the same place.
    @Test func olderVintageProfileReloadsInsideBoundary() async throws {
        let store = Self.makeCacheStore()
        await store.save(Self.cachedProfile(vintage: nil, formatVersion: nil))
        let loader = StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        let viewModel = Self.makeViewModel(
            cacheStore: store,
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: loader
        )

        viewModel.activate()
        viewModel.handleLocationUpdate(Self.location())
        #expect(viewModel.snapshot.statusLine == "REFRESHING")
        await viewModel.waitForPendingLoad()

        #expect(await loader.requestCount() == 1)
        #expect(viewModel.snapshot.dataVintage == CensusDataVintage.current.identifier)
    }

    // MARK: - Approximate location (GIS-005)

    /// GIS-005: an approximate fix is labeled as an approximate area.
    @Test func approximateFixIsLabeled() async throws {
        let manager = FakeLocationManager(authorizationStatus: .authorizedWhenInUse)
        manager.accuracyAuthorization = .reducedAccuracy
        // The production loader copies the request's flag (CityProfileLoaderTests).
        let loader = StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile(isApproximate: true))])
        let viewModel = Self.makeViewModel(cacheStore: Self.makeCacheStore(), manager: manager, loader: loader)

        viewModel.activate()
        viewModel.handleLocationUpdate(Self.location(accuracy: 3_000))
        await viewModel.waitForPendingLoad()

        #expect(await loader.lastRequest()?.isApproximate == true)
        #expect(viewModel.snapshot.statusLine == "APPROXIMATE AREA")
        #expect(viewModel.viewState.isApproximate)
    }

    // MARK: - Loads, retries, and feedback

    /// Successful location loads save a fresh cache entry using the injected clock.
    @Test func successfulLocationLoadStoresFreshProfile() async throws {
        let now = Date(timeIntervalSinceReferenceDate: 300_000)
        let store = Self.makeCacheStore()
        let loader = StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        let viewModel = Self.makeViewModel(
            cacheStore: store,
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: loader,
            now: { now }
        )

        viewModel.activate()
        viewModel.handleLocationUpdate(Self.location(timestamp: now))
        await viewModel.waitForPendingLoad()

        guard case .loaded(let profile, .current) = viewModel.state else {
            Issue.record("Expected loaded state")
            return
        }
        #expect(profile.snapshot.market == "CAMBRIDGE, MA")
        #expect(store.load()?.cachedAt == now)
        #expect(await loader.requestCount() == 1)
    }

    /// Recoverable service failures preserve retry context.
    @Test func unavailableProfileStatePreservesFailureForRetry() async throws {
        let loader = StubCityProfileLoader(outcomes: [
            .unavailable(Self.unavailable(.serviceUnavailable)),
            .loaded(Self.cachedProfile())
        ])
        let viewModel = Self.makeViewModel(
            cacheStore: Self.makeCacheStore(),
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: loader
        )

        viewModel.activate()
        viewModel.handleLocationUpdate(Self.location())
        await viewModel.waitForPendingLoad()

        guard case .profileUnavailable(let unavailable) = viewModel.state else {
            Issue.record("Expected profile unavailable state")
            return
        }
        #expect(unavailable.failure == .serviceUnavailable)
        #expect(viewModel.canRetry)

        viewModel.retry()
        await viewModel.waitForPendingLoad()

        guard case .loaded = viewModel.state else {
            Issue.record("Expected retry to load profile")
            return
        }
        #expect(await loader.requestCount() == 2)
    }

    /// UX-004: permanent failures never offer a retry.
    @Test func permanentFailureOffersNoRetry() async throws {
        let viewModel = Self.makeViewModel(
            cacheStore: Self.makeCacheStore(),
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: StubCityProfileLoader(outcomes: [.unavailable(Self.unavailable(.cityUnavailable, countyTitle: "Middlesex County, MA"))])
        )

        viewModel.activate()
        viewModel.handleLocationUpdate(Self.location())
        await viewModel.waitForPendingLoad()

        #expect(viewModel.canRetry == false)
        #expect(viewModel.viewState.canPullToRefresh == false)
        #expect(viewModel.snapshot.market == "OUTSIDE CITY LIMITS")
        #expect(viewModel.snapshot.statusLine == "MIDDLESEX COUNTY, MA")
    }

    /// Stale asynchronous profile responses cannot overwrite a newer coordinate load.
    ///
    /// The first load is delayed and the second completes immediately. The view
    /// model's active load ID should ignore the older completion.
    @Test func olderProfileLoadCannotOverwriteNewerLocation() async throws {
        let firstProfile = Self.cachedProfile()
        let secondProfile = Self.cachedProfile(market: "SAN FRANCISCO, CA", latitude: 37.7749, longitude: -122.4194, geoid: "0667000")
        let loader = StubCityProfileLoader(
            outcomes: [.loaded(firstProfile), .loaded(secondProfile)],
            delays: [80_000_000, 0]
        )
        let viewModel = Self.makeViewModel(
            cacheStore: Self.makeCacheStore(),
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: loader
        )

        viewModel.activate()
        viewModel.handleLocationUpdate(Self.location())
        viewModel.handleLocationUpdate(Self.location(latitude: 37.7749, longitude: -122.4194))
        await viewModel.waitForPendingLoad()
        try await Task.sleep(nanoseconds: 120_000_000)

        #expect(viewModel.snapshot.market == "SAN FRANCISCO, CA")
        #expect(await loader.requestCount() == 2)
    }

    /// A repeat of the same fix while a load runs does not start a second load.
    @Test func repeatedFixDuringLoadIsIgnored() async throws {
        let loader = StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())], delays: [60_000_000])
        let viewModel = Self.makeViewModel(
            cacheStore: Self.makeCacheStore(),
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: loader
        )

        viewModel.activate()
        viewModel.handleLocationUpdate(Self.location())
        viewModel.handleLocationUpdate(Self.location(latitude: 42.3737, longitude: -71.1055))
        await viewModel.waitForPendingLoad()

        #expect(await loader.requestCount() == 1)
    }

    /// UX-006: the first profile after granting access plays the haptic; a passive refresh does not.
    @Test func hapticPlaysOnlyForUserInitiatedLoads() async throws {
        var hapticCount = 0
        let manager = FakeLocationManager(authorizationStatus: .notDetermined)
        let loader = StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        let viewModel = Self.makeViewModel(
            cacheStore: Self.makeCacheStore(),
            manager: manager,
            loader: loader,
            haptic: { hapticCount += 1 }
        )

        viewModel.activate()
        viewModel.requestLocationAccess()
        manager.authorizationStatus = .authorizedWhenInUse
        viewModel.handleAuthorizationChange(.authorizedWhenInUse)
        viewModel.handleLocationUpdate(Self.location())
        await viewModel.waitForPendingLoad()
        #expect(hapticCount == 1)

        let passiveStore = Self.makeCacheStore()
        await passiveStore.save(Self.cachedProfile(vintage: nil, formatVersion: nil))
        var passiveHapticCount = 0
        let passive = Self.makeViewModel(
            cacheStore: passiveStore,
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())]),
            haptic: { passiveHapticCount += 1 }
        )
        passive.activate()
        passive.handleLocationUpdate(Self.location())
        await passive.waitForPendingLoad()
        #expect(passiveHapticCount == 0)
    }

    /// UX-006: the details toggle stays available while a background refresh runs.
    @Test func detailsToggleStaysAvailableDuringRefresh() async throws {
        let store = Self.makeCacheStore()
        await store.save(Self.cachedProfile(vintage: nil, formatVersion: nil))
        let viewModel = Self.makeViewModel(
            cacheStore: store,
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())], delays: [60_000_000])
        )

        viewModel.activate()
        viewModel.handleLocationUpdate(Self.location())
        #expect(viewModel.isBusy)
        #expect(viewModel.viewState.primaryAction == .toggleDetails)
        #expect(viewModel.viewState.refreshControl == .refresh)
        await viewModel.waitForPendingLoad()
    }

    // MARK: - Review follow-ups

    /// A refresh after a failed one gets a full location timeout of its own.
    @Test func secondRefreshAfterFailedFixGetsAFullTimeout() async throws {
        let clock = TestClock(Date(timeIntervalSinceReferenceDate: 100_000))
        let store = Self.makeCacheStore()
        await store.save(Self.cachedProfile())
        let viewModel = Self.makeViewModel(
            cacheStore: store,
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())]),
            now: { clock.now }
        )

        let first = Task { await viewModel.refresh() }
        try await Task.sleep(nanoseconds: 20_000_000)
        clock.advance(by: 5)
        viewModel.handleLocationFailure(authorizationStatus: .authorizedWhenInUse)
        await first.value
        let failedEvent = try #require(viewModel.refreshEvent)
        #expect(failedEvent.outcome == .unableToLocate)

        clock.advance(by: 15)
        let second = Task { await viewModel.refresh() }
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(viewModel.refreshEvent == failedEvent)

        viewModel.handleLocationUpdate(Self.location(timestamp: clock.now))
        await second.value
        #expect(viewModel.refreshEvent?.outcome == .updated)
    }

    /// A refresh that asked for access and then got no fix ends; the next fix is not a forced load.
    @Test func failedFixAfterGrantingAccessEndsPendingRefresh() async throws {
        let store = Self.makeCacheStore()
        await store.save(Self.cachedProfile())
        let manager = FakeLocationManager(authorizationStatus: .notDetermined)
        let loader = StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        let viewModel = Self.makeViewModel(cacheStore: store, manager: manager, loader: loader)

        await viewModel.refresh()
        manager.authorizationStatus = .authorizedWhenInUse
        viewModel.handleAuthorizationChange(.authorizedWhenInUse)
        viewModel.handleLocationFailure(authorizationStatus: .authorizedWhenInUse)
        #expect(viewModel.refreshEvent?.outcome == .unableToLocate)
        #expect(viewModel.snapshot.statusLine == "LAST KNOWN AREA")

        // The next foreground's fix is an ordinary one: same place, no load.
        viewModel.activate()
        viewModel.handleLocationUpdate(Self.location())
        await viewModel.waitForPendingLoad()
        #expect(await loader.requestCount() == 0)
        #expect(viewModel.snapshot.statusLine.isEmpty)
    }

    /// Foregrounding during the first load keeps the loading state and makes no new request.
    @Test func foregroundDuringInitialLoadKeepsLoadingState() async throws {
        let manager = FakeLocationManager(authorizationStatus: .authorizedWhenInUse)
        let viewModel = Self.makeViewModel(
            cacheStore: Self.makeCacheStore(),
            manager: manager,
            loader: StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())], delays: [80_000_000])
        )

        viewModel.activate()
        viewModel.handleLocationUpdate(Self.location())
        viewModel.activate()

        guard case .loading = viewModel.state else {
            Issue.record("Expected the load to keep its state")
            return
        }
        #expect(manager.locationRequestCount == 1)
        await viewModel.waitForPendingLoad()
    }

    /// Access revoked while a load runs: the result is labeled as location off, not current.
    @Test func revokingAccessDuringLoadLabelsTheResult() async throws {
        let store = Self.makeCacheStore()
        await store.save(Self.cachedProfile(vintage: nil, formatVersion: nil))
        let manager = FakeLocationManager(authorizationStatus: .authorizedWhenInUse)
        let viewModel = Self.makeViewModel(
            cacheStore: store,
            manager: manager,
            loader: StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())], delays: [60_000_000])
        )

        viewModel.activate()
        viewModel.handleLocationUpdate(Self.location())
        manager.authorizationStatus = .denied
        viewModel.handleAuthorizationChange(.denied)
        await viewModel.waitForPendingLoad()

        #expect(viewModel.snapshot.statusLine == "SAVED CITY · LOCATION OFF")
        #expect(viewModel.viewState.refreshControl == .openSettings)
    }

    /// After the no-fix state, the next activation gets the full two attempts again.
    @Test func locationRetryBudgetResetsAfterNoFix() async throws {
        let manager = FakeLocationManager(authorizationStatus: .authorizedWhenInUse)
        let viewModel = Self.makeViewModel(
            cacheStore: Self.makeCacheStore(),
            manager: manager,
            loader: StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        )

        viewModel.activate()
        viewModel.handleLocationFailure(authorizationStatus: .authorizedWhenInUse)
        viewModel.handleLocationFailure(authorizationStatus: .authorizedWhenInUse)
        #expect(manager.locationRequestCount == 2)

        viewModel.activate()
        viewModel.handleLocationFailure(authorizationStatus: .authorizedWhenInUse)
        guard case .requestingLocation = viewModel.state else {
            Issue.record("Expected a second attempt, not the no-fix state")
            return
        }
        #expect(manager.locationRequestCount == 4)
    }

    /// A pull while a button refresh waits for its fix does not start a second refresh.
    @Test func overlappingRefreshIsIgnored() async throws {
        let store = Self.makeCacheStore()
        await store.save(Self.cachedProfile())
        let loader = StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        let viewModel = Self.makeViewModel(
            cacheStore: store,
            manager: FakeLocationManager(authorizationStatus: .authorizedWhenInUse),
            loader: loader
        )

        let first = Task { await viewModel.refresh() }
        try await Task.sleep(nanoseconds: 20_000_000)
        await viewModel.refresh(trigger: .pull)
        viewModel.handleLocationUpdate(Self.location())
        await first.value

        #expect(await loader.forcedRequestCount() == 1)
    }

    /// CODE-011: retry from the permission state reevaluates access instead of recursing.
    @Test func retryFromPermissionStateReactivates() async throws {
        let manager = FakeLocationManager(authorizationStatus: .notDetermined)
        let viewModel = Self.makeViewModel(
            cacheStore: Self.makeCacheStore(),
            manager: manager,
            loader: StubCityProfileLoader(outcomes: [.loaded(Self.cachedProfile())])
        )
        viewModel.activate()

        // Access changed in Settings, and the tap lands before the callback.
        manager.authorizationStatus = .denied
        viewModel.retry()

        guard case .locationUnavailable(.denied) = viewModel.state else {
            Issue.record("Expected the denied state")
            return
        }
    }
}

// MARK: - Fixtures

extension LocationProfileViewModelTests {
    /// Creates a ViewModel with fake dependencies for deterministic tests.
    static func makeViewModel(
        cacheStore: CityProfileCacheStore,
        manager: FakeLocationManager,
        loader: StubCityProfileLoader,
        now: @escaping @Sendable () -> Date = { Date(timeIntervalSinceReferenceDate: 100_000) },
        haptic: @escaping @MainActor () -> Void = {},
        openSettings: @escaping @MainActor () -> Void = {},
        locationTimeout: TimeInterval = 5
    ) -> LocationProfileViewModel {
        LocationProfileViewModel(
            cacheStore: cacheStore,
            locationManager: manager,
            profileLoader: loader,
            now: now,
            profileResolvedHaptic: haptic,
            openSettings: openSettings,
            locationTimeout: locationTimeout
        )
    }

    /// Creates an isolated cache store for one test.
    static func makeCacheStore() -> CityProfileCacheStore {
        let suiteName = "lociq.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lociq-tests-\(UUID().uuidString)", isDirectory: true)
        return CityProfileCacheStore(directory: directory, defaults: defaults)
    }

    /// Returns a Cambridge fixture location stamped at the test clock's time.
    static func location(
        latitude: Double = 42.3736,
        longitude: Double = -71.1056,
        accuracy: CLLocationAccuracy = 80,
        timestamp: Date = Date(timeIntervalSinceReferenceDate: 100_000)
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 0,
            timestamp: timestamp
        )
    }

    /// Creates an explained unavailable outcome.
    static func unavailable(_ failure: CityProfileLoadFailure, countyTitle: String? = nil) -> CityProfileUnavailable {
        CityProfileUnavailable(
            snapshot: .unavailable(failure, countyTitle: countyTitle),
            coordinate: CLLocationCoordinate2D(latitude: 42.3736, longitude: -71.1056),
            horizontalAccuracy: 80,
            isApproximate: false,
            failure: failure
        )
    }

    /// Creates a cacheable profile fixture for the current data vintage.
    static func cachedProfile(
        market: String = "CAMBRIDGE, MA",
        latitude: Double = 42.3736,
        longitude: Double = -71.1056,
        cachedAt: Date = Date(timeIntervalSinceReferenceDate: 100_000),
        geoid: String = "2511000",
        vintage: String? = CensusDataVintage.current.identifier,
        formatVersion: Int? = CachedCityProfile.currentFormatVersion,
        isApproximate: Bool? = nil
    ) -> CachedCityProfile {
        CachedCityProfile(
            snapshot: DemographicSnapshot(
                market: market,
                statusLine: "",
                hasDemographicData: true,
                metrics: [
                    DemographicMetric(
                        title: "POPULATION",
                        primaryValue: "118,214",
                        detail: "MEDIAN AGE 30.8",
                        kind: .population,
                        count: 118_214
                    )
                ],
                detailSections: [],
                dataVintage: vintage
            ),
            boundary: sampleBoundary(around: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), geoid: geoid),
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracy: 80,
            cachedAt: cachedAt,
            placeGeoid: geoid,
            isApproximate: isApproximate,
            formatVersion: formatVersion
        )
    }

    /// Returns a rectangular GeoJSON fixture about 8 km wide around a coordinate.
    static func sampleBoundary(around center: CLLocationCoordinate2D, geoid: String) -> GeoJSONFeatureCollection {
        let lat = center.latitude
        let lon = center.longitude
        return GeoJSONFeatureCollection(
            type: "FeatureCollection",
            features: [
                GeoJSONFeature(
                    type: "Feature",
                    properties: ["GEOID": .string(geoid), "AREALAND": .string("16567881")],
                    geometry: .polygon([
                        [
                            [lon - 0.05, lat - 0.03],
                            [lon + 0.05, lat - 0.03],
                            [lon + 0.05, lat + 0.03],
                            [lon - 0.05, lat + 0.03],
                            [lon - 0.05, lat - 0.03]
                        ]
                    ])
                )
            ]
        )
    }
}

/// A clock tests can advance.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date) {
        current = start
    }

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func advance(by seconds: TimeInterval) {
        lock.lock()
        current = current.addingTimeInterval(seconds)
        lock.unlock()
    }
}

/// Fake `LocationManaging` implementation used by view-model tests.
final class FakeLocationManager: LocationManaging {
    weak var delegate: CLLocationManagerDelegate?
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyHundredMeters
    var authorizationStatus: CLAuthorizationStatus
    var accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy
    private(set) var authorizationRequestCount = 0
    private(set) var locationRequestCount = 0

    /// Creates a fake location manager with the supplied authorization state.
    init(authorizationStatus: CLAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
    }

    /// Records that authorization was requested.
    func requestWhenInUseAuthorization() {
        authorizationRequestCount += 1
    }

    /// Records that a location update was requested.
    func requestLocation() {
        locationRequestCount += 1
    }
}

/// Actor-backed city profile loader stub.
///
/// Outcomes are queued so tests can model failures followed by successful
/// retries or out-of-order async completions.
actor StubCityProfileLoader: CityProfileLoading {
    private var outcomes: [CityProfileLoadOutcome]
    private var delays: [UInt64]
    private var requests: [CityProfileLoadRequest] = []

    /// Creates a profile loader that returns queued outcomes with optional delays.
    init(outcomes: [CityProfileLoadOutcome], delays: [UInt64] = []) {
        self.outcomes = outcomes
        self.delays = delays
    }

    /// Returns the next queued profile-load outcome.
    func loadProfile(_ request: CityProfileLoadRequest) async -> CityProfileLoadOutcome {
        requests.append(request)
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

    /// Returns the number of forced (refresh) requests.
    func forcedRequestCount() -> Int {
        requests.filter(\.forceRefresh).count
    }

    /// Returns the latest request.
    func lastRequest() -> CityProfileLoadRequest? {
        requests.last
    }
}
