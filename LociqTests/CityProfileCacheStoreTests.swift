//
//  CityProfileCacheStoreTests.swift
//  LociqTests
//
//  Verifies the file-based profile cache and its one-time migration.
//

import Foundation
import Testing
@testable import Lociq

@MainActor
/// Tests for `CityProfileCacheStore`.
struct CityProfileCacheStoreTests {
    /// CODE-002: a profile saved by an earlier build in `UserDefaults` moves to the file once.
    @Test func migratesV1DefaultsPayloadToFile() async throws {
        let (store, defaults, directory) = Self.makeStore()
        let legacy = try #require(LociqTests.legacyPayload(metricsJSON: """
            [{"title": "POPULATION", "primaryValue": "118,214", "detail": "MEDIAN AGE 30.8"}]
            """).data(using: .utf8))
        defaults.set(legacy, forKey: CityProfileCacheStore.legacyDefaultsKey)

        let migrated = try #require(store.load())
        #expect(migrated.snapshot.market == "CAMBRIDGE")
        #expect(defaults.data(forKey: CityProfileCacheStore.legacyDefaultsKey) == nil)
        #expect(FileManager.default.fileExists(atPath: store.fileURL.path))

        // A second load reads the file.
        #expect(store.load()?.snapshot.market == "CAMBRIDGE")
        try? FileManager.default.removeItem(at: directory)
    }

    /// CODE-002: when the file cannot be written, the legacy payload stays for the next launch.
    @Test func migrationKeepsLegacyPayloadWhenWriteFails() async throws {
        let suiteName = "lociq.cache-tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        // A regular file where the cache directory should be makes the write fail.
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent("lociq-blocker-\(UUID().uuidString)")
        try Data("x".utf8).write(to: blocker)
        let store = CityProfileCacheStore(directory: blocker, defaults: defaults)
        let legacy = try #require(LociqTests.legacyPayload(metricsJSON: """
            [{"title": "POPULATION", "primaryValue": "118,214", "detail": "MEDIAN AGE 30.8"}]
            """).data(using: .utf8))
        defaults.set(legacy, forKey: CityProfileCacheStore.legacyDefaultsKey)

        #expect(store.load()?.snapshot.market == "CAMBRIDGE")
        #expect(defaults.data(forKey: CityProfileCacheStore.legacyDefaultsKey) != nil)
        try? FileManager.default.removeItem(at: blocker)
    }

    /// CODE-002: a corrupt legacy payload is removed without breaking launch.
    @Test func corruptLegacyPayloadIsRemoved() async throws {
        let (store, defaults, directory) = Self.makeStore()
        defaults.set(Data("not json".utf8), forKey: CityProfileCacheStore.legacyDefaultsKey)

        #expect(store.load() == nil)
        #expect(defaults.data(forKey: CityProfileCacheStore.legacyDefaultsKey) == nil)
        try? FileManager.default.removeItem(at: directory)
    }

    /// CODE-002 / GIS-008: stored coordinates are rounded, and nothing stays in defaults.
    @Test func savedCoordinatesAreRoundedAndDefaultsStayClean() async throws {
        let (store, defaults, directory) = Self.makeStore()
        defaults.set(Data("old".utf8), forKey: CityProfileCacheStore.legacyDefaultsKey)
        let profile = LocationProfileViewModelTests.cachedProfile(latitude: 42.373_612_34, longitude: -71.105_678_9)

        await store.save(profile)
        let saved = try #require(store.load())

        #expect(saved.latitude == 42.3736)
        #expect(saved.longitude == -71.1057)
        #expect(defaults.data(forKey: CityProfileCacheStore.legacyDefaultsKey) == nil)
        try? FileManager.default.removeItem(at: directory)
    }

    /// The cache directory is excluded from backups.
    @Test func cacheDirectoryIsExcludedFromBackup() async throws {
        let (store, _, directory) = Self.makeStore()
        await store.save(LocationProfileViewModelTests.cachedProfile())

        let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
        try? FileManager.default.removeItem(at: directory)
    }

    private static func makeStore() -> (CityProfileCacheStore, UserDefaults, URL) {
        let suiteName = "lociq.cache-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lociq-cache-tests-\(UUID().uuidString)", isDirectory: true)
        return (CityProfileCacheStore(directory: directory, defaults: defaults), defaults, directory)
    }
}
