//
//  LocationProfileViewStateMapperTests.swift
//  LociqTests
//
//  Verifies the pure projection from state machine to view state.
//

import CoreLocation
import Foundation
import Testing
@testable import Lociq

@MainActor
/// Table-driven tests for `LocationProfileViewStateMapper`.
struct LocationProfileViewStateMapperTests {
    private struct Expectation {
        let state: LocationProfileViewModel.State
        let isWaiting: Bool
        let isBusy: Bool
        let primaryAction: PrimaryAction
        let refreshControl: RefreshControl
        let canPull: Bool
        let showsBoundary: Bool
        let statusLine: String
    }

    /// Every state projects the expected actions, waiting flags, and status line.
    @Test func viewStateMapperProjectsEveryState() {
        let profile = LocationProfileViewModelTests.cachedProfile()
        let expectations: [Expectation] = [
            Expectation(state: .idle, isWaiting: true, isBusy: true, primaryAction: .none, refreshControl: .hidden, canPull: false, showsBoundary: false, statusLine: ""),
            Expectation(state: .needsLocationPermission, isWaiting: false, isBusy: false, primaryAction: .requestPermission, refreshControl: .hidden, canPull: false, showsBoundary: false, statusLine: ""),
            Expectation(state: .requestingLocation, isWaiting: true, isBusy: true, primaryAction: .none, refreshControl: .hidden, canPull: false, showsBoundary: false, statusLine: ""),
            Expectation(state: .loading, isWaiting: true, isBusy: true, primaryAction: .none, refreshControl: .hidden, canPull: false, showsBoundary: false, statusLine: ""),
            Expectation(state: .refreshing(profile, context: .sameArea), isWaiting: false, isBusy: true, primaryAction: .toggleDetails, refreshControl: .refresh, canPull: true, showsBoundary: true, statusLine: "REFRESHING"),
            Expectation(state: .refreshing(profile, context: .newLocation), isWaiting: false, isBusy: true, primaryAction: .toggleDetails, refreshControl: .refresh, canPull: true, showsBoundary: true, statusLine: "UPDATING FOR NEW LOCATION"),
            Expectation(state: .loaded(profile, status: .current), isWaiting: false, isBusy: false, primaryAction: .toggleDetails, refreshControl: .refresh, canPull: true, showsBoundary: true, statusLine: ""),
            Expectation(state: .loaded(profile, status: .lastLocation), isWaiting: false, isBusy: false, primaryAction: .toggleDetails, refreshControl: .requestPermissionAndRefresh, canPull: true, showsBoundary: true, statusLine: "LAST LOCATION"),
            Expectation(state: .loaded(profile, status: .locationOff(restricted: false)), isWaiting: false, isBusy: false, primaryAction: .toggleDetails, refreshControl: .openSettings, canPull: true, showsBoundary: true, statusLine: "SAVED CITY · LOCATION OFF"),
            Expectation(state: .loaded(profile, status: .locationOff(restricted: true)), isWaiting: false, isBusy: false, primaryAction: .toggleDetails, refreshControl: .hidden, canPull: true, showsBoundary: true, statusLine: "SAVED CITY · LOCATION OFF"),
            Expectation(state: .loaded(profile, status: .lastKnownArea), isWaiting: false, isBusy: false, primaryAction: .toggleDetails, refreshControl: .refresh, canPull: true, showsBoundary: true, statusLine: "LAST KNOWN AREA"),
            Expectation(state: .loaded(profile, status: .savedAfterFailedRefresh(.timedOut)), isWaiting: false, isBusy: false, primaryAction: .toggleDetails, refreshControl: .refresh, canPull: true, showsBoundary: true, statusLine: "SAVED · NO RESPONSE"),
            Expectation(state: .locationUnavailable(.denied), isWaiting: false, isBusy: false, primaryAction: .openSettings, refreshControl: .hidden, canPull: false, showsBoundary: false, statusLine: "ALLOW IN SETTINGS"),
            Expectation(state: .locationUnavailable(.restricted), isWaiting: false, isBusy: false, primaryAction: .none, refreshControl: .hidden, canPull: false, showsBoundary: false, statusLine: "ON THIS DEVICE"),
            Expectation(state: .locationUnavailable(.noFix), isWaiting: false, isBusy: false, primaryAction: .retry, refreshControl: .hidden, canPull: true, showsBoundary: false, statusLine: "CAN'T FIND YOUR LOCATION"),
            Expectation(state: .profileUnavailable(LocationProfileViewModelTests.unavailable(.networkUnavailable)), isWaiting: false, isBusy: false, primaryAction: .retry, refreshControl: .hidden, canPull: true, showsBoundary: false, statusLine: "CHECK CONNECTION"),
            Expectation(state: .profileUnavailable(LocationProfileViewModelTests.unavailable(.outsideCoverage)), isWaiting: false, isBusy: false, primaryAction: .none, refreshControl: .hidden, canPull: false, showsBoundary: false, statusLine: "CITY DATA IS U.S.-ONLY")
        ]

        for expectation in expectations {
            let view = LocationProfileViewStateMapper.make(from: expectation.state, debugCoordinate: nil)
            #expect(view.isWaitingForInitialData == expectation.isWaiting, "\(expectation.state)")
            #expect(view.isBusy == expectation.isBusy, "\(expectation.state)")
            #expect(view.primaryAction == expectation.primaryAction, "\(expectation.state)")
            #expect(view.refreshControl == expectation.refreshControl, "\(expectation.state)")
            #expect(view.canPullToRefresh == expectation.canPull, "\(expectation.state)")
            #expect(view.canShowBoundary == expectation.showsBoundary, "\(expectation.state)")
            #expect(view.snapshot.statusLine == expectation.statusLine, "\(expectation.state)")
        }
    }

    /// UX-004: Retry is offered only for transient failures.
    @Test func retryOfferedOnlyForTransientFailures() {
        let retryable: [CityProfileLoadFailure] = [.networkUnavailable, .timedOut, .serviceUnavailable]
        let permanent: [CityProfileLoadFailure] = [.cityUnavailable, .outsideCoverage, .demographicsUnavailable, .censusKeyMissing]

        for failure in retryable {
            let view = LocationProfileViewStateMapper.make(
                from: .profileUnavailable(LocationProfileViewModelTests.unavailable(failure)),
                debugCoordinate: nil
            )
            #expect(view.primaryAction == .retry, "\(failure)")
        }
        for failure in permanent {
            let view = LocationProfileViewStateMapper.make(
                from: .profileUnavailable(LocationProfileViewModelTests.unavailable(failure)),
                debugCoordinate: nil
            )
            #expect(view.primaryAction == .none, "\(failure)")
            #expect(view.canPullToRefresh == false, "\(failure)")
        }
    }

    /// Small places carry a quiet caveat; approximate fixes take precedence.
    @Test func currentProfileCaveats() {
        let small = CachedCityProfile(
            snapshot: DemographicSnapshot(
                market: "MONOWI, NE",
                statusLine: "",
                hasDemographicData: true,
                metrics: [DemographicMetric(title: "POPULATION", primaryValue: "2", detail: "", kind: .population, count: 2)],
                detailSections: []
            ),
            boundary: nil,
            latitude: 42.9,
            longitude: -98.3,
            horizontalAccuracy: 50,
            isApproximate: false
        )
        #expect(LocationProfileViewStateMapper.statusLine(for: .current, profile: small) == "SMALL-AREA ESTIMATE")

        let approximate = CachedCityProfile(
            snapshot: small.snapshot,
            boundary: nil,
            latitude: 42.9,
            longitude: -98.3,
            horizontalAccuracy: 3_000,
            isApproximate: true
        )
        #expect(LocationProfileViewStateMapper.statusLine(for: .current, profile: approximate) == "APPROXIMATE AREA")
    }
}
