import Combine
import Foundation

@MainActor
final class NeighborhoodDiscoveryModel: ObservableObject {
    @Published private(set) var result: NeighborhoodDiscoveryResult?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var activeSeedTitle: String?

    private let service: any NeighborhoodDiscoveryServing
    private let libraryStore: NeighborhoodLibraryStore
    private var activeTask: Task<Void, Never>?

    init(
        service: any NeighborhoodDiscoveryServing,
        libraryStore: NeighborhoodLibraryStore
    ) {
        self.service = service
        self.libraryStore = libraryStore
    }

    func refresh(
        currentSeed: NeighborhoodDiscoverySeed?,
        fallbackEntry: NeighborhoodLibraryEntry?
    ) {
        activeTask?.cancel()

        guard let seed = resolvedSeed(currentSeed: currentSeed, fallbackEntry: fallbackEntry) else {
            result = nil
            errorMessage = AppStrings.Labels.discoveryNeedsPlaceBody
            activeSeedTitle = nil
            isLoading = false
            return
        }

        activeSeedTitle = seed.snapshot.title
        isLoading = true
        errorMessage = nil
        let recentPlaces = libraryStore.recentLookups

        activeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await service.discoverNeighborhoods(
                    from: seed,
                    recentPlaces: recentPlaces
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.result = result
                    self.errorMessage = nil
                    self.isLoading = false
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.result = nil
                    self.errorMessage = (error as? LocalizedError)?.errorDescription ?? AppStrings.Labels.discoveryLoadFailedBody
                    self.isLoading = false
                }
            }
        }
    }

    func clear() {
        activeTask?.cancel()
        result = nil
        errorMessage = nil
        activeSeedTitle = nil
        isLoading = false
    }

    private func resolvedSeed(
        currentSeed: NeighborhoodDiscoverySeed?,
        fallbackEntry: NeighborhoodLibraryEntry?
    ) -> NeighborhoodDiscoverySeed? {
        if let currentSeed {
            return currentSeed
        }

        guard let fallbackEntry else { return nil }
        return NeighborhoodDiscoverySeed(
            snapshot: NeighborhoodLookupSnapshot(
                id: fallbackEntry.id,
                title: fallbackEntry.title,
                subtitle: fallbackEntry.subtitle,
                zipCode: fallbackEntry.zipCode,
                latitude: fallbackEntry.latitude,
                longitude: fallbackEntry.longitude,
                preferredScale: fallbackEntry.preferredScale
            ),
            profile: nil
        )
    }
}
