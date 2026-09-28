//
//  CityProfileLoaderTests.swift
//  LociqTests
//
//  Verifies how Census results become loaded or explained unavailable states.
//
//  Counting fakes stand in for the geocoder, ACS, and TIGER clients so each
//  test can assert both the outcome and exactly which requests were made.
//

import CoreLocation
import Foundation
import Testing
@testable import Lociq

@MainActor
/// Tests for `CensusCityProfileLoader` and `CensusCityProfileService`.
struct CityProfileLoaderTests {
    private let request = CityProfileLoadRequest(coordinate: CLLocationCoordinate2D(latitude: 42.3736, longitude: -71.1056))

    /// CODE-005: a geocoder failure makes one geocoder call, with no fallback repeat.
    @Test func geocoderFailureIsNotRepeated() async throws {
        let clients = FakeCensusClients(geocoderResult: .failure(CensusServiceError.networkUnavailable("offline")))
        let outcome = await clients.loader().loadProfile(request)

        guard case .unavailable(let unavailable) = outcome else {
            Issue.record("Expected an unavailable outcome")
            return
        }
        #expect(unavailable.failure == .networkUnavailable)
        #expect(unavailable.snapshot.market == "OFFLINE")
        #expect(unavailable.snapshot.statusLine == "CHECK CONNECTION")
        #expect(await clients.geocoderCalls() == 1)
        #expect(await clients.boundaryCalls() == 0)
    }

    /// CODE-005: a success without a boundary does not fetch the boundary again.
    @Test func missingBoundaryIsNotFetchedTwice() async throws {
        let clients = FakeCensusClients(boundary: nil)
        let outcome = await clients.loader().loadProfile(request)

        guard case .loaded(let profile) = outcome else {
            Issue.record("Expected a loaded outcome")
            return
        }
        #expect(profile.boundary == nil)
        #expect(profile.partialFailures.contains { $0.stage == .boundary })
        #expect(await clients.boundaryCalls() == 1)
        #expect(await clients.geocoderCalls() == 1)
    }

    /// GIS-007: a county without a place is "outside city limits", with the county as the explanation.
    @Test func outsideCityLimitsWhenOnlyCounty() async throws {
        let clients = FakeCensusClients(geocoderResult: .success(CensusGeographiesBundle(county: Self.middlesex, place: nil)))
        let outcome = await clients.loader().loadProfile(request)

        guard case .unavailable(let unavailable) = outcome else {
            Issue.record("Expected an unavailable outcome")
            return
        }
        #expect(unavailable.failure == .cityUnavailable)
        #expect(unavailable.failure.isRetryable == false)
        #expect(unavailable.snapshot.market == "OUTSIDE CITY LIMITS")
        #expect(unavailable.snapshot.statusLine == "MIDDLESEX COUNTY, MA")
        #expect(await clients.demographicsCalls() == 0)
    }

    /// GIS-007: no county and no place is outside U.S. coverage.
    @Test func outsideCoverageWhenNothingResolves() async throws {
        let clients = FakeCensusClients(geocoderResult: .success(CensusGeographiesBundle(county: nil, place: nil)))
        guard case .unavailable(let unavailable) = await clients.loader().loadProfile(request) else {
            Issue.record("Expected an unavailable outcome")
            return
        }
        #expect(unavailable.failure == .outsideCoverage)
        #expect(unavailable.snapshot.market == "OUTSIDE U.S. COVERAGE")
    }

    /// UX-004: the recorded demographics failure decides the message and whether Retry helps.
    @Test func demographicsFailureUsesRecordedCause() async throws {
        let transient = FakeCensusClients(demographicsResult: .failure(CensusServiceError.timedOut))
        guard case .unavailable(let timedOut) = await transient.loader().loadProfile(request) else {
            Issue.record("Expected an unavailable outcome")
            return
        }
        #expect(timedOut.failure == .timedOut)
        #expect(timedOut.failure.isRetryable)
        #expect(timedOut.snapshot.market == "CAMBRIDGE, MA")
        #expect(timedOut.snapshot.statusLine == "CENSUS SERVICE TIMED OUT")

        let permanent = FakeCensusClients(demographicsResult: .failure(CensusServiceError.noDemographicsFound))
        guard case .unavailable(let noRow) = await permanent.loader().loadProfile(request) else {
            Issue.record("Expected an unavailable outcome")
            return
        }
        #expect(noRow.failure == .demographicsUnavailable)
        #expect(noRow.failure.isRetryable == false)
        #expect(noRow.snapshot.statusLine == "NO CENSUS ESTIMATES FOR THIS PLACE YET")
    }

    /// Without an API key, the city is named and the state explains the data service is unavailable.
    @Test func missingKeyExplainsDataServiceUnavailable() async throws {
        let clients = FakeCensusClients()
        guard case .unavailable(let unavailable) = await clients.loader(hasKey: false).loadProfile(request) else {
            Issue.record("Expected an unavailable outcome")
            return
        }
        #expect(unavailable.failure == .censusKeyMissing)
        #expect(unavailable.snapshot.market == "CAMBRIDGE, MA")
        #expect(unavailable.snapshot.statusLine == "DATA SERVICE UNAVAILABLE")
        #expect(await clients.demographicsCalls() == 0)
    }

    /// UX-005: a hung service resolves as "no response" within the load budget.
    @Test func loadBudgetEndsHungLoad() async throws {
        let clients = FakeCensusClients(geocoderDelay: 10_000_000_000)
        let started = Date()
        let outcome = await clients.loader(budget: 0.1).loadProfile(request)

        guard case .unavailable(let unavailable) = outcome else {
            Issue.record("Expected an unavailable outcome")
            return
        }
        #expect(unavailable.failure == .timedOut)
        #expect(Date().timeIntervalSince(started) < 2)
    }

    /// CODE-005: with the boundary hung, statistics still arrive within one boundary budget.
    @Test func hungBoundaryDoesNotHoldStatisticsBeyondItsBudget() async throws {
        let clients = FakeCensusClients(boundaryDelay: 200_000_000)
        let started = Date()
        let outcome = await clients.loader().loadProfile(request)

        guard case .loaded = outcome else {
            Issue.record("Expected a loaded outcome")
            return
        }
        #expect(Date().timeIntervalSince(started) < 1.5)
    }

    /// CODE-004: the memo is keyed by place and bypassed by a forced refresh.
    @Test func memoIsKeyedByPlaceAndBypassedOnForcedRefresh() async throws {
        let clients = FakeCensusClients()
        let service = clients.service()

        _ = try await service.fetchPlaceProfile(latitude: 42.3736, longitude: -71.1056)
        _ = try await service.fetchPlaceProfile(latitude: 42.3800, longitude: -71.1100)
        #expect(await clients.demographicsCalls() == 1)
        #expect(await clients.geocoderCalls() == 2)

        _ = try await service.fetchPlaceProfile(
            latitude: 42.3736,
            longitude: -71.1056,
            options: CityProfileFetchOptions(forceRefresh: true)
        )
        #expect(await clients.demographicsCalls() == 2)
    }

    /// A profile missing its boundary is not memoized, so a later load can heal it.
    @Test func partialProfilesAreNotMemoized() async throws {
        let clients = FakeCensusClients(boundary: nil)
        let service = clients.service()

        _ = try await service.fetchPlaceProfile(latitude: 42.3736, longitude: -71.1056)
        _ = try await service.fetchPlaceProfile(latitude: 42.3736, longitude: -71.1056)

        #expect(await clients.demographicsCalls() == 2)
        #expect(await clients.boundaryCalls() == 2)
    }

    /// CODE-003: a refresh of the same place reuses the boundary it already has.
    @Test func knownBoundaryIsReusedForSamePlace() async throws {
        let clients = FakeCensusClients()
        let known = KnownPlaceBoundary(geoid: "2511000", boundary: FakeCensusClients.cambridgeBoundary)
        _ = try await clients.service().fetchPlaceProfile(
            latitude: 42.3736,
            longitude: -71.1056,
            options: CityProfileFetchOptions(forceRefresh: true, knownBoundary: known)
        )
        #expect(await clients.boundaryCalls() == 0)

        let other = KnownPlaceBoundary(geoid: "0667000", boundary: FakeCensusClients.cambridgeBoundary)
        _ = try await clients.service().fetchPlaceProfile(
            latitude: 42.3736,
            longitude: -71.1056,
            options: CityProfileFetchOptions(forceRefresh: true, knownBoundary: other)
        )
        #expect(await clients.boundaryCalls() == 1)
    }

    /// Loaded profiles carry the place GEOID, approximate flag, and density.
    @Test func loadedProfileCarriesPlaceIdentity() async throws {
        let clients = FakeCensusClients()
        let approximate = CityProfileLoadRequest(
            coordinate: request.coordinate,
            horizontalAccuracy: 3_000,
            isApproximate: true
        )
        guard case .loaded(let profile) = await clients.loader().loadProfile(approximate) else {
            Issue.record("Expected a loaded outcome")
            return
        }
        #expect(profile.placeGeoid == "2511000")
        #expect(profile.isApproximate == true)
        #expect(profile.snapshot.densityPerSquareMile != nil)
        #expect(profile.isCurrent(for: .current))
    }

    private static let middlesex = CountyInfo(name: "Middlesex County", stateFIPS: "25", countyFIPS: "017", geoid: "25017")
}

/// Counting fakes for the three Census clients.
final class FakeCensusClients: @unchecked Sendable {
    static let cambridge = PlaceInfo(
        name: "Cambridge city",
        baseName: "Cambridge",
        stateFIPS: "25",
        placeFIPS: "11000",
        type: .incorporatedPlace
    )

    static let cambridgeBoundary = GeoJSONFeatureCollection(
        type: "FeatureCollection",
        features: [
            GeoJSONFeature(
                type: "Feature",
                properties: ["GEOID": .string("2511000"), "AREALAND": .string("16567881")],
                geometry: .polygon([[[-71.16, 42.35], [-71.06, 42.35], [-71.06, 42.40], [-71.16, 42.40], [-71.16, 42.35]]])
            )
        ]
    )

    private let counter = CallCounter()
    private let geocoderResult: Result<CensusGeographiesBundle, Error>
    private let demographicsResult: Result<Demographics, Error>
    private let boundary: GeoJSONFeatureCollection?
    private let geocoderDelay: UInt64
    private let boundaryDelay: UInt64

    init(
        geocoderResult: Result<CensusGeographiesBundle, Error> = .success(CensusGeographiesBundle(county: nil, place: FakeCensusClients.cambridge)),
        demographicsResult: Result<Demographics, Error> = .success(LociqTests.cambridgeDemographics()),
        boundary: GeoJSONFeatureCollection? = FakeCensusClients.cambridgeBoundary,
        geocoderDelay: UInt64 = 0,
        boundaryDelay: UInt64 = 0
    ) {
        self.geocoderResult = geocoderResult
        self.demographicsResult = demographicsResult
        self.boundary = boundary
        self.geocoderDelay = geocoderDelay
        self.boundaryDelay = boundaryDelay
    }

    func geocoderCalls() async -> Int { await counter.value("geocoder") }
    func demographicsCalls() async -> Int { await counter.value("acs") }
    func boundaryCalls() async -> Int { await counter.value("tiger") }

    func service() -> CensusCityProfileService {
        CensusCityProfileService(
            directClient: DirectCensusCityProfileClient(
                geocoderClient: Geocoder(owner: self),
                boundaryClient: Boundary(owner: self),
                demographicsClient: ACS(owner: self)
            )
        )
    }

    func loader(hasKey: Bool = true, budget: TimeInterval = 5) -> CensusCityProfileLoader {
        CensusCityProfileLoader(
            profileService: service(),
            geocoderClient: Geocoder(owner: self),
            hasCensusAPIKey: hasKey,
            loadBudget: budget
        )
    }

    private struct Geocoder: CensusGeographyFetching {
        let owner: FakeCensusClients
        func fetchGeographiesFromCoordinate(latitude: Double, longitude: Double) async throws -> CensusGeographiesBundle {
            await owner.counter.increment("geocoder")
            if owner.geocoderDelay > 0 { try await Task.sleep(nanoseconds: owner.geocoderDelay) }
            return try owner.geocoderResult.get()
        }
    }

    private struct ACS: ACSDemographicsFetching {
        let owner: FakeCensusClients
        func fetchDemographics(place: PlaceInfo) async throws -> Demographics {
            await owner.counter.increment("acs")
            return try owner.demographicsResult.get()
        }
    }

    private struct Boundary: TIGERBoundaryFetching {
        let owner: FakeCensusClients
        func fetchPlaceBoundary(place: PlaceInfo?) async -> GeoJSONFeatureCollection? {
            await owner.counter.increment("tiger")
            if owner.boundaryDelay > 0 { try? await Task.sleep(nanoseconds: owner.boundaryDelay) }
            return owner.boundary
        }
    }
}

/// Thread-safe call counts.
private actor CallCounter {
    private var counts: [String: Int] = [:]

    func increment(_ key: String) {
        counts[key, default: 0] += 1
    }

    func value(_ key: String) -> Int {
        counts[key, default: 0]
    }
}
