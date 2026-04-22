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
