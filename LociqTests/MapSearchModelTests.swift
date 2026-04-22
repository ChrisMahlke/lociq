import CoreLocation
import Foundation
import Testing
@testable import Lociq

@MainActor
struct MapSearchModelTests {
    @Test func debouncedQuerySearchPopulatesResults() async {
        let service = StubPlaceSearchService(
            resultsByQuery: [
                "94107": [
                    PlaceSearchResult(
                        title: "94107",
                        subtitle: "San Francisco, CA",
                        coordinate: CLLocationCoordinate2D(latitude: 37.768, longitude: -122.393)
                    )
                ]
            ]
        )
        let model = MapSearchModel(service: service, debounceNanoseconds: 20_000_000)

        model.updateQuery("94107")
        await waitUntil { model.results.count == 1 && !model.isSearching }

        #expect(model.results.first?.title == "94107")
        #expect(service.recordedQueries == ["94107"])
    }

    @Test func shortQueryClearsResultsWithoutSearching() async {
        let service = StubPlaceSearchService(resultsByQuery: [:])
        let model = MapSearchModel(service: service, debounceNanoseconds: 20_000_000)

        model.updateQuery("9")
        try? await Task.sleep(nanoseconds: 60_000_000)

        #expect(model.results.isEmpty)
        #expect(model.shouldShowResults == false)
        #expect(service.recordedQueries.isEmpty)
    }

    @Test func submitSearchShowsEmptyStateForNoMatches() async {
        let service = StubPlaceSearchService(resultsByQuery: [:])
        let model = MapSearchModel(service: service, debounceNanoseconds: 20_000_000)

        model.updateQuery("Mission")
        model.submitSearch()
        await waitUntil { !model.isSearching && model.hasAttemptedSearch }

        #expect(model.results.isEmpty)
        #expect(model.shouldShowResults == true)
        #expect(model.errorMessage == nil)
    }

    @Test func selectingResultDismissesSuggestionsAndPreservesLabel() {
        let service = StubPlaceSearchService(resultsByQuery: [:])
        let model = MapSearchModel(service: service, debounceNanoseconds: 20_000_000)
        let result = PlaceSearchResult(
            title: "Mission District",
            subtitle: "San Francisco, CA",
            coordinate: CLLocationCoordinate2D(latitude: 37.7599, longitude: -122.4148)
        )

        model.updateQuery("Mission")
        model.selectResult(result)

        #expect(model.query == "Mission District")
        #expect(model.results.isEmpty)
        #expect(model.shouldShowResults == false)
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let interval: UInt64 = 20_000_000
        var elapsed: UInt64 = 0

        while elapsed < timeoutNanoseconds {
            if condition() {
                return
            }

            try? await Task.sleep(nanoseconds: interval)
            elapsed += interval
        }
    }
}

@MainActor
private final class StubPlaceSearchService: PlaceSearchServing {
    let resultsByQuery: [String: [PlaceSearchResult]]
    private(set) var recordedQueries: [String] = []

    init(resultsByQuery: [String: [PlaceSearchResult]]) {
        self.resultsByQuery = resultsByQuery
    }

    func search(query: String) async throws -> [PlaceSearchResult] {
        recordedQueries.append(query)
        return resultsByQuery[query] ?? []
    }
}
