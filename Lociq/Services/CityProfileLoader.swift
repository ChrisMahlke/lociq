//
//  CityProfileLoader.swift
//  Lociq
//
//  Maps city profile service results into UI-ready loaded or unavailable states.
//
//  The loader is the boundary between raw service composition and view-model
//  state. It does not render UI, but it does decide whether the app has a full
//  cacheable profile, a partial location shell, or an unavailable state.
//

import CoreLocation
import Foundation

/// Result of loading the current city profile for one coordinate.
///
/// The outcome is already display oriented. A loaded case contains the full
/// cached profile. An unavailable case still carries enough context for the UI
/// to render a minimal honest state, possibly including a city label and
/// boundary even when demographics are missing.
enum CityProfileLoadOutcome: Sendable {
    /// A complete or sufficiently useful profile that can be cached and shown.
    case loaded(CachedCityProfile)

    /// A displayable failure state with optional geographic context.
    case unavailable(
        snapshot: DemographicSnapshot,
        boundary: GeoJSONFeatureCollection?,
        coordinate: CLLocationCoordinate2D,
        horizontalAccuracy: CLLocationAccuracy?,
        failure: CityProfileLoadFailure
    )
}

/// Loads a displayable city profile for a Core Location coordinate.
///
/// The protocol is used by `LocationProfileViewModel` so tests can replace the
/// Census pipeline with deterministic outcomes.
protocol CityProfileLoading: Sendable {
    /// Loads a city profile for a coordinate and returns either displayable data or a displayable unavailable state.
    ///
    /// - Parameters:
    ///   - coordinate: The user's current WGS84 coordinate.
    ///   - horizontalAccuracy: Accuracy radius from Core Location, used only for
    ///     location-dot styling.
    /// - Returns: A profile that can be displayed immediately by the view model.
    func loadProfile(
        for coordinate: CLLocationCoordinate2D,
        horizontalAccuracy: CLLocationAccuracy?
    ) async -> CityProfileLoadOutcome
}

/// Production loader that maps Census service results into app-level outcomes.
///
/// The loader prefers full demographics, but it can fall back to a city shell
/// when ACS or the API key is unavailable. This keeps the minimalist UI from
/// showing fake demographic placeholders.
struct CensusCityProfileLoader: CityProfileLoading {
    /// Full profile service, typically backed by geocoder, ACS, and TIGER clients.
    private let profileService: any CityProfileFetching

    /// Geocoder used to build fallback city shells when full profile loading fails.
    private let geocoderClient: any CensusGeographyFetching

    /// Boundary client used for fallback geometry when the full profile lacks one.
    private let boundaryClient: any TIGERBoundaryFetching

    /// Indicates whether the configured Census API key is present.
    private let hasCensusAPIKey: Bool

    /// Creates a loader that maps Census service outcomes into cacheable profiles or minimal fallback states.
    init(
        profileService: any CityProfileFetching,
        geocoderClient: any CensusGeographyFetching,
        boundaryClient: any TIGERBoundaryFetching,
        hasCensusAPIKey: Bool
    ) {
        self.profileService = profileService
        self.geocoderClient = geocoderClient
        self.boundaryClient = boundaryClient
        self.hasCensusAPIKey = hasCensusAPIKey
    }

    /// Loads demographics and boundary data, preserving partial location context when one service fails.
    ///
    /// The method intentionally returns an outcome instead of throwing. The view
    /// model should be able to render something minimal for every expected
    /// failure category without duplicating service error handling.
    func loadProfile(
        for coordinate: CLLocationCoordinate2D,
        horizontalAccuracy: CLLocationAccuracy?
    ) async -> CityProfileLoadOutcome {
        guard hasCensusAPIKey else {
            // Without a key, ACS requests are not reliable enough for the app's
            // production path. Still try to resolve a location shell so the user
            // sees an honest enable/configuration state instead of fake data.
            return await loadLocationShell(
                for: coordinate,
                horizontalAccuracy: horizontalAccuracy,
                failure: .censusKeyMissing
            )
        }

        do {
            let profile = try await profileService.fetchPlaceProfile(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )

            guard let cityDemographics = profile.demographics.place else {
                // If the geocoder and perhaps boundary succeeded but ACS did
                // not, keep the city identity and outline if available.
                var fallbackBoundary = profile.boundarySet.city
                if fallbackBoundary == nil {
                    fallbackBoundary = await boundaryClient.fetchPlaceBoundary(place: profile.geography.place)
                }
                return .unavailable(
                    snapshot: DemographicSnapshot.status(
                        for: .demographicsUnavailable,
                        market: DemographicValueFormatter.title(from: profile).uppercased()
                    ),
                    boundary: fallbackBoundary,
                    coordinate: coordinate,
                    horizontalAccuracy: horizontalAccuracy,
                    failure: .demographicsUnavailable
                )
            }

            // Boundary is allowed to fail independently from demographics.
            // When the fallback boundary fetch succeeds, remove any stale
            // boundary partial failure from the profile.
            var cityBoundary = profile.boundarySet.city
            if cityBoundary == nil {
                cityBoundary = await boundaryClient.fetchPlaceBoundary(place: profile.geography.place)
            }
            let partialFailures = cityBoundary == nil
                ? profile.partialFailures
                : profile.partialFailures.filter { $0.stage != .boundary }
            return .loaded(
                CachedCityProfile(
                    snapshot: DemographicSnapshot(profile: profile, demographics: cityDemographics),
                    boundary: cityBoundary,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    horizontalAccuracy: horizontalAccuracy,
                    cachedAt: nil,
                    partialFailures: partialFailures
                )
            )
        } catch {
            // A full profile failure may still allow a city label and boundary
            // through the lighter geocoder path.
            LociqDiagnostics.cityProfilePartialLoadFailed(error, stage: "city-profile")
            return await loadLocationShell(
                for: coordinate,
                horizontalAccuracy: horizontalAccuracy,
                failure: CityProfileLoadFailure(error: error)
            )
        }
    }

    /// Resolves city name and optional boundary when full demographic loading is unavailable.
    ///
    /// This fallback path gives the UI a truthful non-demographic state. It
    /// avoids showing metric-shaped placeholders and still uses real Census
    /// geocoding when possible.
    private func loadLocationShell(
        for coordinate: CLLocationCoordinate2D,
        horizontalAccuracy: CLLocationAccuracy?,
        failure: CityProfileLoadFailure
    ) async -> CityProfileLoadOutcome {
        do {
            // Geocoding is much cheaper than the full profile pipeline and can
            // still provide a meaningful city label for the unavailable state.
            let geography = try await geocoderClient.fetchGeographiesFromCoordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            let areaTitle = DemographicValueFormatter.cityTitle(from: geography) ?? "CITY UNAVAILABLE"
            let resolvedBoundary = await boundaryClient.fetchPlaceBoundary(place: geography.place)
            let status: DemographicSnapshot.LocationStatus = areaTitle == "CITY UNAVAILABLE"
                ? .cityUnavailable
                : DemographicSnapshot.LocationStatus(failure: failure)

            return .unavailable(
                snapshot: DemographicSnapshot.status(for: status, market: areaTitle.uppercased()),
                boundary: resolvedBoundary,
                coordinate: coordinate,
                horizontalAccuracy: horizontalAccuracy,
                failure: areaTitle == "CITY UNAVAILABLE" ? .cityUnavailable : failure
            )
        } catch {
            // If even the shell fails, collapse to the normalized failure label.
            LociqDiagnostics.cityProfilePartialLoadFailed(error, stage: "location-shell")
            return .unavailable(
                snapshot: DemographicSnapshot.status(
                    for: DemographicSnapshot.LocationStatus(failure: failure),
                    market: failure.fallbackMarket
                ),
                boundary: nil,
                coordinate: coordinate,
                horizontalAccuracy: horizontalAccuracy,
                failure: failure
            )
        }
    }
}

private extension CityProfileLoadFailure {
    /// Short fallback heading used when no city label is available.
    ///
    /// These strings are intentionally terse because the UI has very limited
    /// text surface during failure states.
    var fallbackMarket: String {
        switch self {
        case .censusKeyMissing:
            return "CENSUS KEY"
        case .cityUnavailable:
            return "CITY"
        case .demographicsUnavailable:
            return "DEMOGRAPHICS"
        case .boundaryUnavailable:
            return "BOUNDARY"
        case .networkUnavailable:
            return "NETWORK"
        case .timedOut:
            return "TIMEOUT"
        case .serviceUnavailable:
            return "ACS"
        }
    }
}

private extension DemographicSnapshot.LocationStatus {
    /// Converts a loader failure into the corresponding minimal snapshot status.
    ///
    /// This mapping lives with the loader because it is part of translating
    /// service outcomes into display states.
    init(failure: CityProfileLoadFailure) {
        switch failure {
        case .censusKeyMissing:
            self = .censusKeyMissing
        case .cityUnavailable:
            self = .cityUnavailable
        case .demographicsUnavailable:
            self = .demographicsUnavailable
        case .boundaryUnavailable:
            self = .boundaryUnavailable
        case .networkUnavailable:
            self = .networkUnavailable
        case .timedOut:
            self = .timedOut
        case .serviceUnavailable:
            self = .serviceUnavailable
        }
    }
}
