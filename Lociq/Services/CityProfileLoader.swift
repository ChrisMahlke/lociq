import CoreLocation
import Foundation

enum CityProfileLoadFailure: Equatable, Sendable {
    case censusKeyMissing
    case cityUnavailable
    case demographicsUnavailable
    case boundaryUnavailable
    case serviceUnavailable
}

enum CityProfileLoadOutcome: Sendable {
    case loaded(CachedCityProfile)
    case unavailable(
        snapshot: DemographicSnapshot,
        boundary: GeoJSONFeatureCollection?,
        coordinate: CLLocationCoordinate2D,
        horizontalAccuracy: CLLocationAccuracy?,
        failure: CityProfileLoadFailure
    )
}

protocol CityProfileLoading: Sendable {
    func loadProfile(
        for coordinate: CLLocationCoordinate2D,
        horizontalAccuracy: CLLocationAccuracy?
    ) async -> CityProfileLoadOutcome
}

final class CensusCityProfileLoader: @unchecked Sendable, CityProfileLoading {
    private let profileService: CensusCityProfileService
    private let geocoderClient: CensusGeocoderClient
    private let boundaryClient: TIGERBoundaryClient
    private let hasCensusAPIKey: Bool

    init(
        profileService: CensusCityProfileService,
        geocoderClient: CensusGeocoderClient,
        boundaryClient: TIGERBoundaryClient,
        hasCensusAPIKey: Bool
    ) {
        self.profileService = profileService
        self.geocoderClient = geocoderClient
        self.boundaryClient = boundaryClient
        self.hasCensusAPIKey = hasCensusAPIKey
    }

    func loadProfile(
        for coordinate: CLLocationCoordinate2D,
        horizontalAccuracy: CLLocationAccuracy?
    ) async -> CityProfileLoadOutcome {
        guard hasCensusAPIKey else {
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

            var cityBoundary = profile.boundarySet.city
            if cityBoundary == nil {
                cityBoundary = await boundaryClient.fetchPlaceBoundary(place: profile.geography.place)
            }
            guard let cityBoundary else {
                return .unavailable(
                    snapshot: DemographicSnapshot.status(
                        for: .boundaryUnavailable,
                        market: DemographicValueFormatter.title(from: profile).uppercased()
                    ),
                    boundary: nil,
                    coordinate: coordinate,
                    horizontalAccuracy: horizontalAccuracy,
                    failure: .boundaryUnavailable
                )
            }

            return .loaded(
                CachedCityProfile(
                    snapshot: DemographicSnapshot(profile: profile, demographics: cityDemographics),
                    boundary: cityBoundary,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    horizontalAccuracy: horizontalAccuracy,
                    cachedAt: Date()
                )
            )
        } catch {
            return await loadLocationShell(
                for: coordinate,
                horizontalAccuracy: horizontalAccuracy,
                failure: .serviceUnavailable
            )
        }
    }

    private func loadLocationShell(
        for coordinate: CLLocationCoordinate2D,
        horizontalAccuracy: CLLocationAccuracy?,
        failure: CityProfileLoadFailure
    ) async -> CityProfileLoadOutcome {
        do {
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
        case .serviceUnavailable:
            return "ACS"
        }
    }
}

private extension DemographicSnapshot.LocationStatus {
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
        case .serviceUnavailable:
            self = .serviceUnavailable
        }
    }
}
