//
//  CityProfileCacheStore.swift
//  Lociq
//
//  Persists and restores the last successful city profile for fast launches.
//
//  The cache is intentionally simple: one last profile, stored locally in
//  `UserDefaults`. It is used to avoid an empty first frame and to provide stale
//  fallback when live Census services are slow or unavailable.
//

import CoreLocation
import Foundation

/// Display-ready profile persisted between app launches.
///
/// This is not a raw service response. It stores the already projected snapshot,
/// optional boundary geometry, original coordinate, and partial failures needed
/// to resume the UI quickly without reloading Census services first.
struct CachedCityProfile: Codable, Sendable {
    /// UI-ready demographic content for the cached place.
    let snapshot: DemographicSnapshot

    /// Optional city or CDP boundary geometry used by the preview.
    let boundary: GeoJSONFeatureCollection?

    /// Latitude of the coordinate that produced this profile.
    let latitude: Double

    /// Longitude of the coordinate that produced this profile.
    let longitude: Double

    /// Core Location horizontal accuracy captured with the coordinate.
    let horizontalAccuracy: Double?

    /// Local timestamp when the profile was saved.
    let cachedAt: Date?

    /// Non-fatal subrequest failures attached to the cached profile.
    let partialFailures: [CityProfilePartialFailure]

    /// Creates a cacheable city profile payload.
    ///
    /// `cachedAt` defaults to `nil` so service code can create a profile before
    /// the view model stamps it with the final save time.
    init(
        snapshot: DemographicSnapshot,
        boundary: GeoJSONFeatureCollection?,
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double?,
        cachedAt: Date? = nil,
        partialFailures: [CityProfilePartialFailure] = []
    ) {
        self.snapshot = snapshot
        self.boundary = boundary
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.cachedAt = cachedAt
        self.partialFailures = partialFailures
    }

    /// Decodes cached profiles while preserving compatibility with profiles saved before partial failures existed.
    ///
    /// Older cache payloads did not include `partialFailures`. Decoding defaults
    /// that field to an empty array instead of invalidating otherwise useful
    /// cached data.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        snapshot = try container.decode(DemographicSnapshot.self, forKey: .snapshot)
        boundary = try container.decodeIfPresent(GeoJSONFeatureCollection.self, forKey: .boundary)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        horizontalAccuracy = try container.decodeIfPresent(Double.self, forKey: .horizontalAccuracy)
        cachedAt = try container.decodeIfPresent(Date.self, forKey: .cachedAt)
        partialFailures = try container.decodeIfPresent([CityProfilePartialFailure].self, forKey: .partialFailures) ?? []
    }

    /// Reconstructs the original Core Location coordinate for refresh requests and boundary dot placement.
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Returns true when the cached profile is older than the configured maximum age.
    ///
    /// A missing timestamp is treated as expired because the app cannot prove
    /// freshness.
    func isExpired(at date: Date, maxAge: TimeInterval) -> Bool {
        guard let cachedAt else { return true }
        return date.timeIntervalSince(cachedAt) > maxAge
    }

    /// Returns a copy of the cached profile with a replaced cache timestamp.
    ///
    /// This keeps `CachedCityProfile` immutable while allowing the view model to
    /// stamp profiles at the moment they are persisted.
    func withCachedAt(_ date: Date) -> CachedCityProfile {
        CachedCityProfile(
            snapshot: snapshot,
            boundary: boundary,
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracy: horizontalAccuracy,
            cachedAt: date,
            partialFailures: partialFailures
        )
    }
}

/// Local persistence wrapper for the last successful city profile.
///
/// The store intentionally catches encode and decode failures. Cache errors
/// should never break the minimal UI or prevent live data loading.
struct CityProfileCacheStore {
    /// UserDefaults key for the current cache payload schema.
    private let key = "lociq.lastCityProfile.v1"

    /// Backing defaults store, injectable for tests.
    private let defaults: UserDefaults

    /// Creates a profile cache backed by the supplied user defaults store.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Loads the most recently saved city profile.
    ///
    /// - Returns: The cached profile, or `nil` if no profile exists or decoding fails.
    func load() -> CachedCityProfile? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(CachedCityProfile.self, from: data)
        } catch {
            LociqDiagnostics.cityProfileCacheFailed(error, operation: "decode")
            return nil
        }
    }

    /// Persists the latest successful city profile.
    ///
    /// Save failures are logged but not surfaced to the UI because live data is
    /// already available at this point.
    func save(_ profile: CachedCityProfile) {
        do {
            let data = try JSONEncoder().encode(profile)
            defaults.set(data, forKey: key)
        } catch {
            LociqDiagnostics.cityProfileCacheFailed(error, operation: "encode")
        }
    }

    /// Removes the cached city profile.
    ///
    /// This is used by tests and can support future explicit cache reset flows.
    func clear() {
        defaults.removeObject(forKey: key)
    }
}
