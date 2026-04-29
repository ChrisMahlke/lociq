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

        #expect(store.recentLookups.count == NeighborhoodLibraryStore.maxRecentLookups - 1)
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

    @Test func persistsCustomLabelsNotesAndPinnedPlaces() {
        let defaults = makeDefaults()
        let store = NeighborhoodLibraryStore(userDefaults: defaults, storageKey: "metadata")
        let snapshot = makeSnapshot(id: "06075022900", title: "San Francisco")

        store.saveWithMetadata(
            snapshot,
            customLabel: "Shortlist",
            note: "Great transit and strong income profile.",
            isPinned: true
        )

        #expect(store.pinnedPlaces.map(\.id) == [snapshot.id])
        #expect(store.savedPlaces.first?.displayTitle == "Shortlist")
        #expect(store.savedPlaces.first?.normalizedNote == "Great transit and strong income profile.")

        let reloaded = NeighborhoodLibraryStore(userDefaults: defaults, storageKey: "metadata")
        #expect(reloaded.pinnedPlaces.map(\.id) == [snapshot.id])
        #expect(reloaded.savedPlaces.first?.displayTitle == "Shortlist")
    }

    @Test func savesAndReloadsComparisonLibraryEntries() {
        let defaults = makeDefaults()
        let store = NeighborhoodLibraryStore(userDefaults: defaults, storageKey: "comparisons")
        let snapshot = SavedComparisonSnapshot(
            id: "a::b::ZIP",
            title: "San Francisco vs Oakland",
            summary: "ZIP · San Francisco County · Alameda County",
            boundaryScale: .zip,
            primary: makeSnapshot(id: "primary", title: "San Francisco"),
            secondary: makeSnapshot(id: "secondary", title: "Oakland")
        )

        store.saveComparison(snapshot)

        #expect(store.savedComparisons.count == 1)
        #expect(store.savedComparisons.first?.title == "San Francisco vs Oakland")
        #expect(store.isComparisonSaved(id: snapshot.id) == true)

        let reloaded = NeighborhoodLibraryStore(userDefaults: defaults, storageKey: "comparisons")
        #expect(reloaded.savedComparisons.count == 1)
        #expect(reloaded.savedComparisons.first?.secondaryTitle == "Oakland")
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
