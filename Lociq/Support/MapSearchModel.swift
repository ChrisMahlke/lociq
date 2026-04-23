import Combine
import Foundation

@MainActor
final class MapSearchModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: [PlaceSearchResult] = []
    @Published private(set) var isSearching: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasAttemptedSearch: Bool = false

    private let service: any PlaceSearchServing
    private let debounceNanoseconds: UInt64
    private var searchTask: Task<Void, Never>?
    private var activeSearchID = UUID()

    init(service: any PlaceSearchServing, debounceNanoseconds: UInt64 = 300_000_000) {
        self.service = service
        self.debounceNanoseconds = debounceNanoseconds
    }

    var shouldShowResults: Bool {
        let trimmedQuery = trimmedQuery(query)
        guard !trimmedQuery.isEmpty else { return false }
        return isSearching || errorMessage != nil || !results.isEmpty || hasAttemptedSearch
    }

    func updateQuery(_ newValue: String) {
        query = newValue
        errorMessage = nil

        let trimmed = trimmedQuery(newValue)
        guard !trimmed.isEmpty else {
            clearSearchPresentation()
            return
        }

        guard trimmed.count >= 2 else {
            searchTask?.cancel()
            isSearching = false
            results = []
            hasAttemptedSearch = false
            return
        }

        scheduleSearch(for: trimmed)
    }

    func submitSearch() {
        let trimmed = trimmedQuery(query)
        guard !trimmed.isEmpty else {
            clearSearchPresentation()
            return
        }

        searchTask?.cancel()
        searchTask = Task { [weak self] in
            await self?.performSearch(for: trimmed)
        }
    }

    func submitSearchAndResolveTopResult() async -> PlaceSearchResult? {
        let trimmed = trimmedQuery(query)
        guard !trimmed.isEmpty else {
            clearSearchPresentation()
            return nil
        }

        searchTask?.cancel()
        let searchResults = await performSearch(for: trimmed)
        return searchResults?.first
    }

    func clear() {
        query = ""
        clearSearchPresentation()
    }

    func dismissResults() {
        searchTask?.cancel()
        isSearching = false
        results = []
        errorMessage = nil
        hasAttemptedSearch = false
    }

    func selectResult(_ result: PlaceSearchResult) {
        query = result.title
        dismissResults()
    }

    private func scheduleSearch(for query: String) {
        searchTask?.cancel()
        let searchID = UUID()
        activeSearchID = searchID
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.debounceNanoseconds ?? 0)
            guard !Task.isCancelled else { return }
            await self?.performSearch(for: query, searchID: searchID)
        }
    }

    @discardableResult
    private func performSearch(for query: String, searchID: UUID? = nil) async -> [PlaceSearchResult]? {
        let currentSearchID = searchID ?? UUID()
        activeSearchID = currentSearchID
        isSearching = true
        errorMessage = nil

        do {
            let searchResults = try await service.search(query: query)
            guard isCurrent(searchID: currentSearchID) else { return nil }

            let limitedResults = Array(searchResults.prefix(8))
            results = limitedResults
            hasAttemptedSearch = true
            isSearching = false
            return limitedResults
        } catch is CancellationError {
            return nil
        } catch {
            guard isCurrent(searchID: currentSearchID) else { return nil }

            results = []
            hasAttemptedSearch = true
            isSearching = false
            errorMessage = AppStrings.Labels.searchErrorBody
            return nil
        }
    }

    private func clearSearchPresentation() {
        searchTask?.cancel()
        isSearching = false
        results = []
        errorMessage = nil
        hasAttemptedSearch = false
    }

    private func isCurrent(searchID: UUID) -> Bool {
        activeSearchID == searchID
    }

    private func trimmedQuery(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
