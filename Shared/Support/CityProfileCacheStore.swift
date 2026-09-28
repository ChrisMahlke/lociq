//
//  CityProfileCacheStore.swift
//  Lociq
//
//  Persists and restores the last successful city profile for fast launches.
//
//  The cache is intentionally simple: one last profile, stored as a file in
//  Application Support. It is used to avoid an empty first frame and to keep
//  showing useful data when live Census services are slow or unavailable.
//

import CoreLocation
import Foundation

/// Display-ready profile persisted between app launches.
///
/// This is not a raw service response. It stores the already projected snapshot,
/// optional boundary geometry, the lookup coordinate (rounded when saved), and
/// partial failures needed to resume the UI quickly without reloading Census
/// services first.
///
/// Persisted: add optional fields only. Payloads written by earlier builds under
/// `lociq.lastCityProfile.v1` must keep decoding.
nonisolated struct CachedCityProfile: Codable, Sendable {
    /// Version of the display format produced by the current snapshot builder.
    ///
    /// Bump when a snapshot formatting fix should reach cached profiles; a
    /// profile with an older version is reloaded at the next location fix.
    static let currentFormatVersion = 2

    /// UI-ready demographic content for the cached place.
    let snapshot: DemographicSnapshot

    /// Optional city or CDP boundary geometry used by the preview.
    let boundary: GeoJSONFeatureCollection?

    /// Latitude of the coordinate the Census lookup resolved to this place.
    let latitude: Double

    /// Longitude of the coordinate the Census lookup resolved to this place.
    let longitude: Double

    /// Core Location horizontal accuracy captured with the lookup coordinate.
    let horizontalAccuracy: Double?

    /// Local timestamp when the profile was saved.
    let cachedAt: Date?

    /// Non-fatal subrequest failures attached to the cached profile.
    let partialFailures: [CityProfilePartialFailure]

    /// Census place GEOID for the profile. `nil` in older caches; see `resolvedPlaceGeoid`.
    let placeGeoid: String?

    /// True when the latest fix came from approximate ("Precise Location: Off") authorization.
    let isApproximate: Bool?

    /// Snapshot format version. `nil` in caches written before versioning.
    let formatVersion: Int?

    /// Latitude of the latest fix inside this place, when newer than the lookup.
    let markerLatitude: Double?

    /// Longitude of the latest fix inside this place, when newer than the lookup.
    let markerLongitude: Double?

    /// Accuracy of the latest fix inside this place, when newer than the lookup.
    let markerHorizontalAccuracy: Double?

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
        partialFailures: [CityProfilePartialFailure] = [],
        placeGeoid: String? = nil,
        isApproximate: Bool? = nil,
        formatVersion: Int? = CachedCityProfile.currentFormatVersion,
        markerLatitude: Double? = nil,
        markerLongitude: Double? = nil,
        markerHorizontalAccuracy: Double? = nil
    ) {
        self.snapshot = snapshot
        self.boundary = boundary
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.cachedAt = cachedAt
        self.partialFailures = partialFailures
        self.placeGeoid = placeGeoid
        self.isApproximate = isApproximate
        self.formatVersion = formatVersion
        self.markerLatitude = markerLatitude
        self.markerLongitude = markerLongitude
        self.markerHorizontalAccuracy = markerHorizontalAccuracy
    }

    /// Decodes cached profiles while preserving compatibility with profiles saved by earlier builds.
    ///
    /// Older payloads lack `partialFailures` and every field added since.
    /// Missing values default instead of invalidating otherwise useful cached
    /// data. An undecodable boundary is dropped rather than losing the profile.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        snapshot = try container.decode(DemographicSnapshot.self, forKey: .snapshot)
        boundary = try? container.decodeIfPresent(GeoJSONFeatureCollection.self, forKey: .boundary)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        horizontalAccuracy = try container.decodeIfPresent(Double.self, forKey: .horizontalAccuracy)
        cachedAt = try container.decodeIfPresent(Date.self, forKey: .cachedAt)
        partialFailures = (try? container.decodeIfPresent([CityProfilePartialFailure].self, forKey: .partialFailures)) ?? []
        placeGeoid = try container.decodeIfPresent(String.self, forKey: .placeGeoid)
        isApproximate = try container.decodeIfPresent(Bool.self, forKey: .isApproximate)
        formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion)
        markerLatitude = try container.decodeIfPresent(Double.self, forKey: .markerLatitude)
        markerLongitude = try container.decodeIfPresent(Double.self, forKey: .markerLongitude)
        markerHorizontalAccuracy = try container.decodeIfPresent(Double.self, forKey: .markerHorizontalAccuracy)
    }

    /// The coordinate the Census lookup resolved to this place.
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Where the location marker belongs: the latest fix inside this place.
    var markerCoordinate: CLLocationCoordinate2D {
        guard let markerLatitude, let markerLongitude else { return coordinate }
        return CLLocationCoordinate2D(latitude: markerLatitude, longitude: markerLongitude)
    }

    /// Accuracy of the marker's fix.
    var markerAccuracy: Double? {
        markerLatitude == nil ? horizontalAccuracy : markerHorizontalAccuracy
    }

    /// Place GEOID, falling back to the boundary's GEOID for older caches.
    var resolvedPlaceGeoid: String? {
        placeGeoid ?? boundary?.geoid
    }

    /// True when the profile was built from the current data vintage and snapshot format.
    ///
    /// Profiles from an older vintage or format are still shown, but the next
    /// location fix reloads them so fixes and new data reach existing users.
    func isCurrent(for vintage: CensusDataVintage) -> Bool {
        snapshot.dataVintage == vintage.identifier && (formatVersion ?? 1) >= Self.currentFormatVersion
    }

    /// True when the boundary failed to load and may be worth requesting again.
    var isMissingBoundary: Bool {
        boundary == nil || partialFailures.contains { $0.stage == .boundary }
    }

    /// Returns the profile ready for display, with older snapshots mapped to the current layout.
    func normalizedForDisplay() -> CachedCityProfile {
        copy(snapshot: snapshot.normalizedForCurrentLayout())
    }

    /// Returns a copy of the cached profile with a replaced cache timestamp.
    func withCachedAt(_ date: Date) -> CachedCityProfile {
        copy(cachedAt: date)
    }

    /// Returns a copy with the marker moved to a newer fix inside the same place.
    ///
    /// The statistics and the lookup coordinate stay; only the marker moves.
    /// Keeping the lookup coordinate fixed means small moves can never walk
    /// the "same spot" check across a city line.
    func withMarker(at fix: LocationFix) -> CachedCityProfile {
        copy(
            isApproximate: fix.isApproximate,
            markerLatitude: fix.coordinate.latitude,
            markerLongitude: fix.coordinate.longitude,
            markerHorizontalAccuracy: fix.horizontalAccuracy
        )
    }

    /// Returns the copy written to disk, with coordinates rounded to about 11 m.
    ///
    /// The stored coordinates only place the marker and anchor the
    /// "same spot" check, neither of which needs more precision.
    func forStorage() -> CachedCityProfile {
        CachedCityProfile(
            snapshot: snapshot,
            boundary: boundary,
            latitude: Self.rounded(latitude),
            longitude: Self.rounded(longitude),
            horizontalAccuracy: horizontalAccuracy.map { max($0, 11) },
            cachedAt: cachedAt,
            partialFailures: partialFailures,
            placeGeoid: placeGeoid,
            isApproximate: isApproximate,
            formatVersion: formatVersion,
            markerLatitude: markerLatitude.map(Self.rounded),
            markerLongitude: markerLongitude.map(Self.rounded),
            markerHorizontalAccuracy: markerHorizontalAccuracy.map { max($0, 11) }
        )
    }

    private func copy(
        snapshot: DemographicSnapshot? = nil,
        cachedAt: Date?? = nil,
        isApproximate: Bool?? = nil,
        markerLatitude: Double?? = nil,
        markerLongitude: Double?? = nil,
        markerHorizontalAccuracy: Double?? = nil
    ) -> CachedCityProfile {
        CachedCityProfile(
            snapshot: snapshot ?? self.snapshot,
            boundary: boundary,
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracy: horizontalAccuracy,
            cachedAt: cachedAt ?? self.cachedAt,
            partialFailures: partialFailures,
            placeGeoid: placeGeoid,
            isApproximate: isApproximate ?? self.isApproximate,
            formatVersion: formatVersion,
            markerLatitude: markerLatitude ?? self.markerLatitude,
            markerLongitude: markerLongitude ?? self.markerLongitude,
            markerHorizontalAccuracy: markerHorizontalAccuracy ?? self.markerHorizontalAccuracy
        )
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 10_000).rounded() / 10_000
    }
}

/// Local persistence for the last successful city profile.
///
/// The profile lives in one JSON file in Application Support, excluded from
/// backups, and written atomically off the main actor. Profiles saved by
/// earlier builds in `UserDefaults` are migrated once and the key is removed,
/// so no coordinates remain in the defaults plist. Cache errors are logged and
/// never break the UI or prevent live data loading.
///
/// `@unchecked Sendable` because of `UserDefaults`, which Apple documents as
/// thread-safe; every other stored property is immutable or an actor.
nonisolated struct CityProfileCacheStore: @unchecked Sendable {
    /// `UserDefaults` key used by earlier builds; read once for migration, then removed.
    static let legacyDefaultsKey = "lociq.lastCityProfile.v1"

    /// Cache file name inside the cache directory.
    private static let fileName = "last-city-profile.json"

    /// Directory that holds the cache file.
    private let directoryURL: URL

    /// Backing defaults store, used only for the legacy payload.
    private let defaults: UserDefaults

    /// Serializes writes so a slow earlier save can never overwrite a newer one.
    private let writer: CityProfileCacheWriter

    /// Creates a profile cache.
    ///
    /// - Parameters:
    ///   - directory: Directory for the cache file. Defaults to
    ///     `Application Support/ProfileCache`.
    ///   - defaults: Defaults store that may hold a profile saved by an earlier build.
    init(directory: URL? = nil, defaults: UserDefaults = .standard) {
        let directoryURL = directory ?? Self.defaultDirectory()
        self.directoryURL = directoryURL
        self.defaults = defaults
        writer = CityProfileCacheWriter(directoryURL: directoryURL, fileName: Self.fileName)
    }

    /// Location of the cache file.
    var fileURL: URL {
        directoryURL.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    /// Loads the most recently saved city profile.
    ///
    /// Reads the cache file. If there is none, reads a profile saved by an
    /// earlier build in `UserDefaults`, writes it to the file, and removes the
    /// key. A corrupt legacy payload is removed without being migrated.
    ///
    /// - Returns: The cached profile, or `nil` if none exists or decoding fails.
    func load() -> CachedCityProfile? {
        if let data = try? Data(contentsOf: fileURL) {
            do {
                return try JSONDecoder().decode(CachedCityProfile.self, from: data)
            } catch {
                LociqDiagnostics.cityProfileCacheFailed(error, operation: "decode")
                return nil
            }
        }
        return migrateLegacyPayload()
    }

    /// Persists the latest successful city profile off the main actor.
    ///
    /// The coordinate is rounded before encoding. Returns once the write is
    /// finished, so callers that need ordering (tests, migration) can await it.
    func save(_ profile: CachedCityProfile) async {
        await writer.write(profile.forStorage())
        defaults.removeObject(forKey: Self.legacyDefaultsKey)
    }

    /// Moves a profile saved by an earlier build from `UserDefaults` into the cache file.
    ///
    /// The key is removed only once the file is written, or when the payload
    /// cannot be decoded at all; a failed write keeps it for the next launch.
    private func migrateLegacyPayload() -> CachedCityProfile? {
        guard let data = defaults.data(forKey: Self.legacyDefaultsKey) else { return nil }
        let profile: CachedCityProfile
        do {
            profile = try JSONDecoder().decode(CachedCityProfile.self, from: data)
        } catch {
            LociqDiagnostics.cityProfileCacheFailed(error, operation: "migrate")
            defaults.removeObject(forKey: Self.legacyDefaultsKey)
            return nil
        }
        if CityProfileCacheWriter.writeSynchronously(profile.forStorage(), directoryURL: directoryURL, fileName: Self.fileName) {
            defaults.removeObject(forKey: Self.legacyDefaultsKey)
        }
        return profile
    }

    /// `Application Support/ProfileCache` in the app container.
    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ProfileCache", isDirectory: true)
    }
}

/// Serial writer for the profile cache file.
private actor CityProfileCacheWriter {
    private let directoryURL: URL
    private let fileName: String

    init(directoryURL: URL, fileName: String) {
        self.directoryURL = directoryURL
        self.fileName = fileName
    }

    /// Encodes and atomically writes one profile.
    func write(_ profile: CachedCityProfile) {
        _ = Self.writeSynchronously(profile, directoryURL: directoryURL, fileName: fileName)
    }

    /// Encodes and atomically writes a profile, excluding the directory from backups.
    ///
    /// The cache can always be rebuilt from Census data, so it is excluded
    /// from iCloud and computer backups. Exclusion is set on the directory,
    /// which keeps applying after each atomic file replacement.
    ///
    /// - Returns: True when the file was written.
    nonisolated static func writeSynchronously(_ profile: CachedCityProfile, directoryURL: URL, fileName: String) -> Bool {
        do {
            let data = try JSONEncoder().encode(profile)
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            var excludedDirectory = directoryURL
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? excludedDirectory.setResourceValues(values)
            try data.write(to: directoryURL.appendingPathComponent(fileName, isDirectory: false), options: [.atomic])
            return true
        } catch {
            LociqDiagnostics.cityProfileCacheFailed(error, operation: "write")
            return false
        }
    }
}
