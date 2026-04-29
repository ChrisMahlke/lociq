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

struct SavedComparisonSnapshot: Equatable, Sendable {
    let id: String
    let title: String
    let summary: String
    let boundaryScale: BoundaryOverlayScale
    let primary: NeighborhoodLookupSnapshot
    let secondary: NeighborhoodLookupSnapshot
}

struct SavedComparisonEntry: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var title: String
    var summary: String
    var boundaryScaleRawValue: String
    var primaryID: String
    var primaryTitle: String
    var primarySubtitle: String
    var primaryZipCode: String?
    var primaryLatitude: Double
    var primaryLongitude: Double
    var secondaryID: String
    var secondaryTitle: String
    var secondarySubtitle: String
    var secondaryZipCode: String?
    var secondaryLatitude: Double
    var secondaryLongitude: Double
    var savedAt: Date

    var boundaryScale: BoundaryOverlayScale {
        BoundaryOverlayScale(rawValue: boundaryScaleRawValue) ?? .zip
    }

    var primarySnapshot: NeighborhoodLookupSnapshot {
        NeighborhoodLookupSnapshot(
            id: primaryID,
            title: primaryTitle,
            subtitle: primarySubtitle,
            zipCode: primaryZipCode,
            latitude: primaryLatitude,
            longitude: primaryLongitude,
            preferredScale: boundaryScale
        )
    }

    var secondarySnapshot: NeighborhoodLookupSnapshot {
        NeighborhoodLookupSnapshot(
            id: secondaryID,
            title: secondaryTitle,
            subtitle: secondarySubtitle,
            zipCode: secondaryZipCode,
            latitude: secondaryLatitude,
            longitude: secondaryLongitude,
            preferredScale: boundaryScale
        )
    }

    init(snapshot: SavedComparisonSnapshot, savedAt: Date = Date()) {
        id = snapshot.id
        title = snapshot.title
        summary = snapshot.summary
        boundaryScaleRawValue = snapshot.boundaryScale.rawValue
        primaryID = snapshot.primary.id
        primaryTitle = snapshot.primary.title
        primarySubtitle = snapshot.primary.subtitle
        primaryZipCode = snapshot.primary.zipCode
        primaryLatitude = snapshot.primary.latitude
        primaryLongitude = snapshot.primary.longitude
        secondaryID = snapshot.secondary.id
        secondaryTitle = snapshot.secondary.title
        secondarySubtitle = snapshot.secondary.subtitle
        secondaryZipCode = snapshot.secondary.zipCode
        secondaryLatitude = snapshot.secondary.latitude
        secondaryLongitude = snapshot.secondary.longitude
        self.savedAt = savedAt
    }
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
    var customLabel: String?
    var note: String
    var isPinned: Bool

    var preferredScale: BoundaryOverlayScale {
        BoundaryOverlayScale(rawValue: preferredScaleRawValue) ?? .zip
    }

    var isSaved: Bool {
        savedAt != nil
    }

    var normalizedCustomLabel: String? {
        guard let customLabel else { return nil }
        let trimmed = customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var normalizedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayTitle: String {
        normalizedCustomLabel ?? title
    }

    var supportingTitle: String? {
        guard let customLabel = normalizedCustomLabel, customLabel != title else { return nil }
        return title
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
        savedAt: Date?,
        customLabel: String? = nil,
        note: String = "",
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.zipCode = zipCode
        self.latitude = latitude
        self.longitude = longitude
        preferredScaleRawValue = preferredScale.rawValue
        self.lastViewedAt = lastViewedAt
        self.savedAt = savedAt
        self.customLabel = customLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isPinned = isPinned
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case zipCode
        case latitude
        case longitude
        case preferredScaleRawValue
        case lastViewedAt
        case savedAt
        case customLabel
        case note
        case isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        zipCode = try container.decodeIfPresent(String.self, forKey: .zipCode)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        preferredScaleRawValue = try container.decode(String.self, forKey: .preferredScaleRawValue)
        lastViewedAt = try container.decode(Date.self, forKey: .lastViewedAt)
        savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt)
        customLabel = try container.decodeIfPresent(String.self, forKey: .customLabel)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}

private struct NeighborhoodLibraryPayload: Codable {
    var entries: [NeighborhoodLibraryEntry]
    var savedComparisons: [SavedComparisonEntry]
}

@MainActor
final class NeighborhoodLibraryStore: ObservableObject {
    @Published private(set) var entries: [NeighborhoodLibraryEntry] = []
    @Published private(set) var savedComparisons: [SavedComparisonEntry] = []

    var pinnedPlaces: [NeighborhoodLibraryEntry] {
        entries
            .filter { $0.isSaved && $0.isPinned }
            .sorted { lhs, rhs in
                (lhs.savedAt ?? .distantPast) > (rhs.savedAt ?? .distantPast)
            }
    }

    var savedPlaces: [NeighborhoodLibraryEntry] {
        entries
            .filter(\.isSaved)
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                return (lhs.savedAt ?? .distantPast) > (rhs.savedAt ?? .distantPast)
            }
    }

    var unpinnedSavedPlaces: [NeighborhoodLibraryEntry] {
        savedPlaces.filter { !$0.isPinned }
    }

    var recentLookups: [NeighborhoodLibraryEntry] {
        Array(
            entries
                .filter { !$0.isSaved }
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
        _ = upsertEntry(with: snapshot, timestamp: Date())
        trimUnsavedHistory()
        persist()
    }

    @discardableResult
    func toggleSaved(_ snapshot: NeighborhoodLookupSnapshot) -> Bool {
        let index = upsertEntry(with: snapshot, timestamp: Date())

        if entries[index].isSaved {
            entries[index].savedAt = nil
            entries[index].isPinned = false
        } else {
            entries[index].savedAt = Date()
        }

        trimUnsavedHistory()
        persist()
        return entries[index].isSaved
    }

    func saveWithMetadata(
        _ snapshot: NeighborhoodLookupSnapshot,
        customLabel: String,
        note: String,
        isPinned: Bool
    ) {
        let index = upsertEntry(with: snapshot, timestamp: Date())
        if entries[index].savedAt == nil {
            entries[index].savedAt = Date()
        }

        applyMetadata(
            customLabel: customLabel,
            note: note,
            isPinned: isPinned,
            to: &entries[index]
        )
        trimUnsavedHistory()
        persist()
    }

    func updatePlaceMetadata(
        id: String,
        customLabel: String,
        note: String,
        isPinned: Bool
    ) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }

        if isPinned && entries[index].savedAt == nil {
            entries[index].savedAt = Date()
        }

        applyMetadata(
            customLabel: customLabel,
            note: note,
            isPinned: isPinned,
            to: &entries[index]
        )
        trimUnsavedHistory()
        persist()
    }

    func entry(id: String) -> NeighborhoodLibraryEntry? {
        entries.first(where: { $0.id == id })
    }

    func isSaved(_ snapshot: NeighborhoodLookupSnapshot) -> Bool {
        entries.contains { $0.id == snapshot.id && $0.isSaved }
    }

    func removeSavedPlace(id: String) {
        guard let index = entries.firstIndex(where: { $0.id == id && $0.isSaved }) else { return }

        entries[index].savedAt = nil
        entries[index].isPinned = false
        trimUnsavedHistory()
        persist()
    }

    func removeRecentLookup(id: String) {
        guard let index = entries.firstIndex(where: { $0.id == id && !$0.isSaved }) else { return }

        entries.remove(at: index)
        persist()
    }

    func saveComparison(_ snapshot: SavedComparisonSnapshot) {
        let now = Date()

        if let index = savedComparisons.firstIndex(where: { $0.id == snapshot.id }) {
            let previousSavedAt = savedComparisons[index].savedAt
            savedComparisons[index] = SavedComparisonEntry(snapshot: snapshot, savedAt: previousSavedAt)
        } else {
            savedComparisons.insert(SavedComparisonEntry(snapshot: snapshot, savedAt: now), at: 0)
        }

        savedComparisons.sort { $0.savedAt > $1.savedAt }
        persist()
    }

    func isComparisonSaved(id: String) -> Bool {
        savedComparisons.contains { $0.id == id }
    }

    func removeSavedComparison(id: String) {
        savedComparisons.removeAll { $0.id == id }
        persist()
    }

    private func upsertEntry(with snapshot: NeighborhoodLookupSnapshot, timestamp: Date) -> Int {
        if let index = entries.firstIndex(where: { $0.id == snapshot.id }) {
            entries[index].title = snapshot.title
            entries[index].subtitle = snapshot.subtitle
            entries[index].zipCode = snapshot.zipCode
            entries[index].latitude = snapshot.latitude
            entries[index].longitude = snapshot.longitude
            entries[index].preferredScaleRawValue = snapshot.preferredScale.rawValue
            entries[index].lastViewedAt = timestamp
            return index
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
                lastViewedAt: timestamp,
                savedAt: nil
            )
        )

        return entries.count - 1
    }

    private func applyMetadata(
        customLabel: String,
        note: String,
        isPinned: Bool,
        to entry: inout NeighborhoodLibraryEntry
    ) {
        let trimmedLabel = customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.customLabel = trimmedLabel.isEmpty ? nil : trimmedLabel
        entry.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.isPinned = isPinned && entry.savedAt != nil
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

        if let payload = try? JSONDecoder().decode(NeighborhoodLibraryPayload.self, from: data) {
            entries = payload.entries
            savedComparisons = payload.savedComparisons.sorted { $0.savedAt > $1.savedAt }
            return
        }

        if let legacyEntries = try? JSONDecoder().decode([NeighborhoodLibraryEntry].self, from: data) {
            entries = legacyEntries
            savedComparisons = []
        }
    }

    private func persist() {
        let payload = NeighborhoodLibraryPayload(entries: entries, savedComparisons: savedComparisons)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
