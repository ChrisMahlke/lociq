import Combine
import Foundation

struct NeighborhoodLookupSnapshot: Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let zipCode: String?
    let latitude: Double
    let longitude: Double
    let preferredScale: BoundaryOverlayScale
}

struct NeighborhoodLibraryEntry: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var title: String
    var subtitle: String
    var zipCode: String?
    var latitude: Double
    var longitude: Double
    var preferredScaleRawValue: String
    var lastViewedAt: Date
    var savedAt: Date?

    var preferredScale: BoundaryOverlayScale {
        BoundaryOverlayScale(rawValue: preferredScaleRawValue) ?? .zip
    }

    var isSaved: Bool {
        savedAt != nil
    }

    init(
        id: String,
        title: String,
        subtitle: String,
        zipCode: String?,
        latitude: Double,
        longitude: Double,
        preferredScale: BoundaryOverlayScale,
        lastViewedAt: Date,
        savedAt: Date?
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.zipCode = zipCode
        self.latitude = latitude
        self.longitude = longitude
        self.preferredScaleRawValue = preferredScale.rawValue
        self.lastViewedAt = lastViewedAt
        self.savedAt = savedAt
    }
}

@MainActor
final class NeighborhoodLibraryStore: ObservableObject {
    @Published private(set) var entries: [NeighborhoodLibraryEntry] = []

    var savedPlaces: [NeighborhoodLibraryEntry] {
        entries
            .filter(\.isSaved)
            .sorted { lhs, rhs in
                (lhs.savedAt ?? .distantPast) > (rhs.savedAt ?? .distantPast)
            }
    }

    var recentLookups: [NeighborhoodLibraryEntry] {
        Array(
            entries
                .sorted { $0.lastViewedAt > $1.lastViewedAt }
                .prefix(Self.maxRecentLookups)
        )
    }

    private let userDefaults: UserDefaults
    private let storageKey: String

    static let maxRecentLookups = 12

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "io.chrismahlke.lociq.neighborhoodLibrary"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        load()
    }

    func recordLookup(_ snapshot: NeighborhoodLookupSnapshot) {
        let now = Date()

        if let index = entries.firstIndex(where: { $0.id == snapshot.id }) {
            entries[index].title = snapshot.title
            entries[index].subtitle = snapshot.subtitle
            entries[index].zipCode = snapshot.zipCode
            entries[index].latitude = snapshot.latitude
            entries[index].longitude = snapshot.longitude
            entries[index].preferredScaleRawValue = snapshot.preferredScale.rawValue
            entries[index].lastViewedAt = now
        } else {
            entries.append(
                NeighborhoodLibraryEntry(
                    id: snapshot.id,
                    title: snapshot.title,
                    subtitle: snapshot.subtitle,
                    zipCode: snapshot.zipCode,
                    latitude: snapshot.latitude,
                    longitude: snapshot.longitude,
                    preferredScale: snapshot.preferredScale,
                    lastViewedAt: now,
                    savedAt: nil
                )
            )
        }

        trimUnsavedHistory()
        persist()
    }

    @discardableResult
    func toggleSaved(_ snapshot: NeighborhoodLookupSnapshot) -> Bool {
        let now = Date()

        if let index = entries.firstIndex(where: { $0.id == snapshot.id }) {
            entries[index].title = snapshot.title
            entries[index].subtitle = snapshot.subtitle
            entries[index].zipCode = snapshot.zipCode
            entries[index].latitude = snapshot.latitude
            entries[index].longitude = snapshot.longitude
            entries[index].preferredScaleRawValue = snapshot.preferredScale.rawValue
            entries[index].lastViewedAt = now
            entries[index].savedAt = entries[index].savedAt == nil ? now : nil

            trimUnsavedHistory()
            persist()
            return entries[index].isSaved
        }

        entries.append(
            NeighborhoodLibraryEntry(
                id: snapshot.id,
                title: snapshot.title,
                subtitle: snapshot.subtitle,
                zipCode: snapshot.zipCode,
                latitude: snapshot.latitude,
                longitude: snapshot.longitude,
                preferredScale: snapshot.preferredScale,
                lastViewedAt: now,
                savedAt: now
            )
        )

        persist()
        return true
    }

    func isSaved(_ snapshot: NeighborhoodLookupSnapshot) -> Bool {
        entries.contains { $0.id == snapshot.id && $0.isSaved }
    }

    private func trimUnsavedHistory() {
        let savedIDs = Set(entries.filter(\.isSaved).map(\.id))
        let unsavedRecentIDs = Set(
            entries
                .filter { !savedIDs.contains($0.id) }
                .sorted { $0.lastViewedAt > $1.lastViewedAt }
                .prefix(Self.maxRecentLookups)
                .map(\.id)
        )

        entries.removeAll { entry in
            !entry.isSaved && !unsavedRecentIDs.contains(entry.id)
        }
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else { return }
        guard let decoded = try? JSONDecoder().decode([NeighborhoodLibraryEntry].self, from: data) else { return }
        entries = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
