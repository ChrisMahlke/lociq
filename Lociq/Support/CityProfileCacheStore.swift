//
//  CityProfileCacheStore.swift
//  Lociq
//
//  Persists and restores the last successful city profile for fast launches.
//

import CoreLocation
import Foundation

struct CachedCityProfile: Codable, Sendable {
    let snapshot: DemographicSnapshot
    let boundary: GeoJSONFeatureCollection?
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double?
    let cachedAt: Date?
    let partialFailures: [CityProfilePartialFailure]

    /// Creates a cacheable city profile payload.
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

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Returns true when the cached profile is older than the configured maximum age.
    func isExpired(at date: Date, maxAge: TimeInterval) -> Bool {
        guard let cachedAt else { return true }
        return date.timeIntervalSince(cachedAt) > maxAge
    }

    /// Returns a copy of the cached profile with a replaced cache timestamp.
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

struct CityProfileCacheStore {
    private let key = "lociq.lastCityProfile.v1"
    private let defaults: UserDefaults

    /// Creates a profile cache backed by the supplied user defaults store.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Loads the most recently saved city profile.
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
    func save(_ profile: CachedCityProfile) {
        do {
            let data = try JSONEncoder().encode(profile)
            defaults.set(data, forKey: key)
        } catch {
            LociqDiagnostics.cityProfileCacheFailed(error, operation: "encode")
        }
    }

    /// Removes the cached city profile.
    func clear() {
        defaults.removeObject(forKey: key)
    }
}
