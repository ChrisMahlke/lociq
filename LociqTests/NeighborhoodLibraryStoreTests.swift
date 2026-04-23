import Foundation
import Testing
@testable import Lociq

@MainActor
struct NeighborhoodLibraryStoreTests {
    @Test func recordsRecentLookupAndPersistsSavedState() throws {
        let defaults = makeDefaults()
        let store = NeighborhoodLibraryStore(userDefaults: defaults, storageKey: "library")
        let snapshot = makeSnapshot(id: "06075022900", title: "San Francisco")

        store.recordLookup(snapshot)

        #expect(store.recentLookups.count == 1)
        #expect(store.recentLookups.first?.title == "San Francisco")
        #expect(store.savedPlaces.isEmpty)

        let isSaved = store.toggleSaved(snapshot)
        #expect(isSaved == true)
        #expect(store.savedPlaces.count == 1)

        let reloaded = NeighborhoodLibraryStore(userDefaults: defaults, storageKey: "library")
        #expect(reloaded.savedPlaces.count == 1)
        #expect(reloaded.savedPlaces.first?.id == snapshot.id)
    }

    @Test func trimsUnsavedHistoryWhileKeepingSavedEntries() {
        let store = NeighborhoodLibraryStore(userDefaults: makeDefaults(), storageKey: "trim")

        for index in 0..<(NeighborhoodLibraryStore.maxRecentLookups + 3) {
            let snapshot = makeSnapshot(id: "recent-\(index)", title: "Place \(index)")
            store.recordLookup(snapshot)
        }

        let savedSnapshot = makeSnapshot(id: "saved-place", title: "Saved Place")
        store.recordLookup(savedSnapshot)
        _ = store.toggleSaved(savedSnapshot)

        #expect(store.recentLookups.count == NeighborhoodLibraryStore.maxRecentLookups)
        #expect(store.savedPlaces.count == 1)
        #expect(store.entries.contains(where: { $0.id == "saved-place" }))
    }

    @Test func removesRecentLookupWithoutAffectingSavedPlaces() {
        let store = NeighborhoodLibraryStore(userDefaults: makeDefaults(), storageKey: "remove-recent")
        let recentSnapshot = makeSnapshot(id: "recent-1", title: "Recent Place")
        let savedSnapshot = makeSnapshot(id: "saved-1", title: "Saved Place")

        store.recordLookup(recentSnapshot)
        store.recordLookup(savedSnapshot)
        _ = store.toggleSaved(savedSnapshot)

        #expect(store.recentLookups.map(\.id) == ["recent-1"])

        store.removeRecentLookup(id: "recent-1")

        #expect(store.recentLookups.isEmpty)
        #expect(store.savedPlaces.map(\.id) == ["saved-1"])
    }

    @Test func removingSavedPlaceKeepsItemInRecents() {
        let store = NeighborhoodLibraryStore(userDefaults: makeDefaults(), storageKey: "remove-saved")
        let snapshot = makeSnapshot(id: "saved-then-recent", title: "Saved Then Recent")

        store.recordLookup(snapshot)
        _ = store.toggleSaved(snapshot)

        #expect(store.savedPlaces.map(\.id) == ["saved-then-recent"])
        #expect(store.recentLookups.isEmpty)

        store.removeSavedPlace(id: "saved-then-recent")

        #expect(store.savedPlaces.isEmpty)
        #expect(store.recentLookups.map(\.id) == ["saved-then-recent"])
    }
}

@MainActor
private func makeDefaults() -> UserDefaults {
    let suiteName = "NeighborhoodLibraryStoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

private func makeSnapshot(id: String, title: String) -> NeighborhoodLookupSnapshot {
    NeighborhoodLookupSnapshot(
        id: id,
        title: title,
        subtitle: "San Francisco County · ZIP 94107",
        zipCode: "94107",
        latitude: 37.78,
        longitude: -122.4,
        preferredScale: .zip
    )
}
