//
//  CityProfileLoader.swift
//  Lociq
//
//  Maps city profile service results into UI-ready loaded or unavailable states.
//
//  The loader is the boundary between raw service composition and view-model
//  state. It does not render UI, but it does decide whether the app has a full
//  cacheable profile or an explained unavailable state, and it bounds how long
//  a load can take.
//

import CoreLocation
import Foundation

/// One profile load request.
nonisolated struct CityProfileLoadRequest: Sendable {
    /// The user's WGS84 coordinate.
    let coordinate: CLLocationCoordinate2D

    /// Accuracy radius from Core Location, used for marker styling.
    let horizontalAccuracy: CLLocationAccuracy?

    /// True when the fix came from approximate location.
    let isApproximate: Bool

    /// True for user-initiated refreshes, which skip the in-memory memo.
    let forceRefresh: Bool

    /// Boundary already on screen, reused when the place is unchanged.
    let knownBoundary: KnownPlaceBoundary?

    /// Creates a load request.
    init(
        coordinate: CLLocationCoordinate2D,
        horizontalAccuracy: CLLocationAccuracy? = nil,
        isApproximate: Bool = false,
        forceRefresh: Bool = false,
        knownBoundary: KnownPlaceBoundary? = nil
    ) {
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
        self.isApproximate = isApproximate
        self.forceRefresh = forceRefresh
        self.knownBoundary = knownBoundary
    }
}

/// An explained state for a profile that could not be loaded.
nonisolated struct CityProfileUnavailable: Sendable {
    /// Heading and plain-language status line.
    let snapshot: DemographicSnapshot

    /// Coordinate the load was for, kept so Retry can repeat it.
    let coordinate: CLLocationCoordinate2D

    /// Accuracy of that coordinate.
    let horizontalAccuracy: CLLocationAccuracy?

    /// True when that coordinate came from approximate location.
    let isApproximate: Bool

    /// Normalized failure category, which decides whether Retry is offered.
    let failure: CityProfileLoadFailure
}

/// Result of loading the current city profile for one coordinate.
///
/// The outcome is already display oriented. A loaded case contains the full
/// cached profile. An unavailable case carries an explained, honest state.
enum CityProfileLoadOutcome: Sendable {
    /// A complete profile that can be cached and shown.
    case loaded(CachedCityProfile)

    /// A displayable failure state.
    case unavailable(CityProfileUnavailable)
}

/// Loads a displayable city profile for a Core Location coordinate.
///
/// The protocol is used by `LocationProfileViewModel` so tests can replace the
/// Census pipeline with deterministic outcomes.
protocol CityProfileLoading: Sendable {
    /// Loads a city profile and returns either displayable data or an explained unavailable state.
    func loadProfile(_ request: CityProfileLoadRequest) async -> CityProfileLoadOutcome
}

/// Production loader that maps Census service results into app-level outcomes.
///
/// Every failure resolves to a specific, explained state: offline, no
/// response, a Census service error, outside every place, outside U.S.
/// coverage, or a place without estimates. The whole load is bounded by one
/// budget, so the user always reaches a state with an action.
struct CensusCityProfileLoader: CityProfileLoading {
    /// Longest a load may take before it resolves as "no response".
    static let defaultLoadBudget: TimeInterval = 25

    /// Full profile service, backed by the shared geocoder, ACS, and TIGER clients.
    private let profileService: any CityProfileFetching

    /// Geocoder used only to name the city when no API key is configured.
    private let geocoderClient: any CensusGeographyFetching

    /// Indicates whether the configured Census API key is present.
    private let hasCensusAPIKey: Bool

    /// Data vintage recorded on loaded profiles.
    private let vintage: CensusDataVintage

    /// Load budget in nanoseconds.
    private let loadBudgetNanoseconds: UInt64

    /// Creates a loader over the shared Census service graph.
    init(
        profileService: any CityProfileFetching,
        geocoderClient: any CensusGeographyFetching,
        hasCensusAPIKey: Bool,
        vintage: CensusDataVintage = .current,
        loadBudget: TimeInterval = CensusCityProfileLoader.defaultLoadBudget
    ) {
        self.profileService = profileService
        self.geocoderClient = geocoderClient
        self.hasCensusAPIKey = hasCensusAPIKey
        self.vintage = vintage
        loadBudgetNanoseconds = UInt64(max(loadBudget, 0.01) * 1_000_000_000)
    }

    /// Loads demographics and boundary data within the load budget.
    ///
    /// The method returns an outcome instead of throwing, so the view model
    /// can render every expected failure without duplicating error handling.
    func loadProfile(_ request: CityProfileLoadRequest) async -> CityProfileLoadOutcome {
        let budget = loadBudgetNanoseconds
        let outcome = await withTaskGroup(of: CityProfileLoadOutcome?.self) { group -> CityProfileLoadOutcome? in
            group.addTask { await self.loadUnbounded(request) }
            group.addTask {
                try? await Task.sleep(nanoseconds: budget)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        if let outcome { return outcome }
        if !Task.isCancelled {
            // Only a real timeout is logged; a superseded load is expected.
            LociqDiagnostics.cityProfilePartialLoadFailed(CensusServiceError.timedOut, stage: "load-budget")
        }
        return unavailable(.timedOut, for: request)
    }

    /// Loads a profile without a time limit; `loadProfile` applies the budget.
    private func loadUnbounded(_ request: CityProfileLoadRequest) async -> CityProfileLoadOutcome {
        guard hasCensusAPIKey else {
            // Without a key ACS cannot be queried. Name the city if possible so
            // the build problem shows as an explained state, never as fake data.
            return await keyMissingState(for: request)
        }

        let profile: ResolvedCityProfile
        do {
            profile = try await profileService.fetchPlaceProfile(
                latitude: request.coordinate.latitude,
                longitude: request.coordinate.longitude,
                options: CityProfileFetchOptions(forceRefresh: request.forceRefresh, knownBoundary: request.knownBoundary)
            )
        } catch is CancellationError {
            // Superseded or out of budget; the result is discarded, so do no more work.
            return unavailable(.timedOut, for: request)
        } catch {
            // The geocoder failed, so the place is unknown. Asking it again for
            // a fallback shell would only repeat the failed request.
            LociqDiagnostics.cityProfilePartialLoadFailed(error, stage: "city-profile")
            return unavailable(CityProfileLoadFailure(error: error), for: request)
        }

        guard let place = profile.geography.place else {
            if let county = profile.geography.county {
                return unavailable(
                    .cityUnavailable,
                    for: request,
                    countyTitle: DemographicValueFormatter.countyTitle(for: county)
                )
            }
            return unavailable(.outsideCoverage, for: request)
        }

        let placeTitle = DemographicValueFormatter.placeTitle(for: place)
        guard let cityDemographics = profile.demographics.place else {
            // The client recorded why statistics are missing: a transient
            // service problem, or a place with no ACS estimates.
            let failure = profile.partialFailures.first { $0.stage == .demographics }?.failure ?? .demographicsUnavailable
            return unavailable(failure, for: request, placeTitle: placeTitle)
        }

        return .loaded(
            CachedCityProfile(
                snapshot: DemographicSnapshot(profile: profile, demographics: cityDemographics, vintage: vintage),
                boundary: profile.boundarySet.city,
                latitude: request.coordinate.latitude,
                longitude: request.coordinate.longitude,
                horizontalAccuracy: request.horizontalAccuracy,
                cachedAt: nil,
                partialFailures: profile.partialFailures,
                placeGeoid: place.geoid,
                isApproximate: request.isApproximate
            )
        )
    }

    /// Resolves the city name for the missing-key state.
    private func keyMissingState(for request: CityProfileLoadRequest) async -> CityProfileLoadOutcome {
        LociqDiagnostics.censusKeyMissing()
        let geography = try? await geocoderClient.fetchGeographiesFromCoordinate(
            latitude: request.coordinate.latitude,
            longitude: request.coordinate.longitude
        )
        return unavailable(
            .censusKeyMissing,
            for: request,
            placeTitle: geography?.place.map(DemographicValueFormatter.placeTitle(for:))
        )
    }

    /// Builds an unavailable outcome with its explained snapshot.
    private func unavailable(
        _ failure: CityProfileLoadFailure,
        for request: CityProfileLoadRequest,
        placeTitle: String? = nil,
        countyTitle: String? = nil
    ) -> CityProfileLoadOutcome {
        .unavailable(
            CityProfileUnavailable(
                snapshot: .unavailable(failure, placeTitle: placeTitle, countyTitle: countyTitle),
                coordinate: request.coordinate,
                horizontalAccuracy: request.horizontalAccuracy,
                isApproximate: request.isApproximate,
                failure: failure
            )
        )
    }
}
