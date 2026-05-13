import Combine
import CoreLocation
import Foundation

@MainActor
final class LocationProfileViewModel: NSObject, ObservableObject {
    enum State {
        case idle
        case requestingLocation
        case loading
        case refreshing(CachedCityProfile)
        case loaded(CachedCityProfile)
        case locationUnavailable
        case profileUnavailable(snapshot: DemographicSnapshot, boundary: GeoJSONFeatureCollection?, coordinate: CLLocationCoordinate2D?)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var traceToken = 0

    private let manager = CLLocationManager()
    private let censusService: CensusZipDemographicsService
    private let geocoderClient: CensusGeocoderClient
    private let boundaryClient: TIGERBoundaryClient
    private let hasCensusAPIKey: Bool
    private let debugCoordinate: CLLocationCoordinate2D?
    private let cacheStore: CityProfileCacheStore
    private var lastLoadedCoordinateKey: String?

    init(
        debugCoordinate: CLLocationCoordinate2D? = nil,
        cacheStore: CityProfileCacheStore? = nil
    ) {
        let httpClient = CensusHTTPClient(session: .shared)
        let censusAPIKey = AppConfig.censusAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.censusService = CensusZipDemographicsService(censusApiKey: censusAPIKey)
        self.geocoderClient = CensusGeocoderClient(httpClient: httpClient)
        self.boundaryClient = TIGERBoundaryClient(httpClient: httpClient)
        self.hasCensusAPIKey = !censusAPIKey.isEmpty
        self.debugCoordinate = debugCoordinate
        self.cacheStore = cacheStore ?? CityProfileCacheStore()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        if let cached = self.cacheStore.load() {
            state = .loaded(cached)
            traceToken += 1
        }
    }

    var snapshot: DemographicSnapshot {
        switch state {
        case .idle, .requestingLocation, .loading:
            return .loading
        case .refreshing(let profile), .loaded(let profile):
            return profile.snapshot
        case .locationUnavailable:
            return .placeholder
        case .profileUnavailable(let snapshot, _, _):
            return snapshot
        }
    }

    var boundary: GeoJSONFeatureCollection? {
        switch state {
        case .refreshing(let profile), .loaded(let profile):
            return profile.boundary
        case .profileUnavailable(_, let boundary, _):
            return boundary
        case .idle, .requestingLocation, .loading, .locationUnavailable:
            return nil
        }
    }

    var coordinate: CLLocationCoordinate2D? {
        switch state {
        case .refreshing(let profile), .loaded(let profile):
            return profile.coordinate
        case .profileUnavailable(_, _, let coordinate):
            return coordinate
        case .idle, .requestingLocation, .loading, .locationUnavailable:
            return debugCoordinate
        }
    }

    var isLoading: Bool {
        switch state {
        case .idle, .requestingLocation, .loading, .refreshing:
            return true
        case .loaded, .locationUnavailable, .profileUnavailable:
            return false
        }
    }

    var isWaitingForInitialData: Bool {
        switch state {
        case .idle, .requestingLocation, .loading:
            return true
        case .refreshing, .loaded, .locationUnavailable, .profileUnavailable:
            return false
        }
    }

    var canShowBoundary: Bool {
        boundary != nil && !isWaitingForInitialData && snapshot.hasDemographicData
    }

    func activate() {
        if let debugCoordinate {
            load(for: debugCoordinate)
            return
        }

        let authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .notDetermined:
            if cacheStore.load() == nil {
                state = .requestingLocation
            }
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            if cacheStore.load() == nil {
                state = .requestingLocation
            }
            manager.requestLocation()
        case .denied, .restricted:
            state = .locationUnavailable
        @unknown default:
            state = .locationUnavailable
        }
    }

    private func load(for coordinate: CLLocationCoordinate2D) {
        let coordinateKey = Self.coordinateKey(for: coordinate)
        guard coordinateKey != lastLoadedCoordinateKey else { return }

        let previousProfile = currentLoadedProfile
        lastLoadedCoordinateKey = coordinateKey

        if let previousProfile, Self.coordinateKey(for: previousProfile.coordinate) == coordinateKey {
            state = .refreshing(previousProfile)
        } else {
            state = .loading
        }

        Task { [weak self] in
            await self?.loadProfile(for: coordinate)
        }
    }

    private func loadProfile(for coordinate: CLLocationCoordinate2D) async {
        guard hasCensusAPIKey else {
            await loadLocationShell(for: coordinate, status: .censusKeyMissing)
            return
        }

        do {
            let profile = try await censusService.fetchPlaceProfile(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            guard let cityDemographics = profile.scaleDemographics.place else {
                var fallbackBoundary = profile.boundaries.city
                if fallbackBoundary == nil {
                    fallbackBoundary = await boundaryClient.fetchPlaceBoundary(place: profile.zipBundle.place)
                }
                state = .profileUnavailable(
                    snapshot: DemographicSnapshot.status(
                        for: .acsUnavailable,
                        market: DemographicValueFormatter.title(from: profile).uppercased()
                    ),
                    boundary: fallbackBoundary,
                    coordinate: coordinate
                )
                if fallbackBoundary != nil {
                    traceToken += 1
                }
                return
            }

            var cityBoundary = profile.boundaries.city
            if cityBoundary == nil {
                cityBoundary = await boundaryClient.fetchPlaceBoundary(place: profile.zipBundle.place)
            }
            guard let cityBoundary else {
                state = .profileUnavailable(
                    snapshot: DemographicSnapshot.status(
                        for: .acsUnavailable,
                        market: DemographicValueFormatter.title(from: profile).uppercased()
                    ),
                    boundary: nil,
                    coordinate: coordinate
                )
                return
            }

            let cityProfile = CachedCityProfile(
                snapshot: DemographicSnapshot(profile: profile, demographics: cityDemographics),
                boundary: cityBoundary,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            cacheStore.save(cityProfile)
            state = .loaded(cityProfile)
            traceToken += 1
        } catch {
            await loadLocationShell(for: coordinate, status: .acsUnavailable)
        }
    }

    private func loadLocationShell(for coordinate: CLLocationCoordinate2D, status: DemographicSnapshot.LocationStatus) async {
        do {
            let geography = try await geocoderClient.fetchGeographiesFromCoordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            let areaTitle = DemographicValueFormatter.cityTitle(from: geography) ?? "CITY UNAVAILABLE"
            let resolvedBoundary = await boundaryClient.fetchPlaceBoundary(place: geography.place)
            state = .profileUnavailable(
                snapshot: DemographicSnapshot.status(for: status, market: areaTitle.uppercased()),
                boundary: resolvedBoundary,
                coordinate: coordinate
            )
            if resolvedBoundary != nil {
                traceToken += 1
            }
        } catch {
            state = .profileUnavailable(
                snapshot: DemographicSnapshot.status(for: status, market: status.fallbackMarket),
                boundary: nil,
                coordinate: coordinate
            )
        }
    }

    private var currentLoadedProfile: CachedCityProfile? {
        switch state {
        case .refreshing(let profile), .loaded(let profile):
            return profile
        case .idle, .requestingLocation, .loading, .locationUnavailable, .profileUnavailable:
            return nil
        }
    }

    private static func coordinateKey(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }
}

extension LocationProfileViewModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied, .restricted:
                state = .locationUnavailable
            case .notDetermined:
                state = .requestingLocation
            @unknown default:
                state = .locationUnavailable
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor [weak self] in
            self?.load(for: coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if currentLoadedProfile == nil {
                state = manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
                    ? .locationUnavailable
                    : .requestingLocation
            }
        }
    }
}

struct CachedCityProfile: Codable, Sendable {
    let snapshot: DemographicSnapshot
    let boundary: GeoJSONFeatureCollection
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct CityProfileCacheStore {
    private let key = "lociq.lastCityProfile.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> CachedCityProfile? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CachedCityProfile.self, from: data)
    }

    func save(_ profile: CachedCityProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
    }
}
