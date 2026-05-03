import Combine
import CoreLocation
import Foundation

@MainActor
final class ContentFlowCoordinator: ObservableObject {
    @Published var selection: TabSelection = .map
    @Published var showSearchExperience: Bool = false
    @Published var showComparePicker: Bool = false
    @Published var mapFocusRequest: MapFocusRequest?

    func showSearch() {
        showSearchExperience = true
    }

    func openComparePicker(compareSearchModel: MapSearchModel) {
        compareSearchModel.clear()
        showComparePicker = true
    }

    func dismissSearch() {
        showSearchExperience = false
    }

    func dismissComparePicker() {
        showComparePicker = false
    }

    func handleMapSelection(
        _ coordinate: CLLocationCoordinate2D?,
        usesSidebarLayout: Bool,
        markMapQuickTipSeen: () -> Void,
        selectionModel: MapSelectionModel,
        searchModel: MapSearchModel,
        compareModel: CompareModeModel
    ) {
        if coordinate != nil {
            markMapQuickTipSeen()
            if usesSidebarLayout {
                selection = .map
            }
            showSearchExperience = false
            showComparePicker = false
            compareModel.clear()
            searchModel.dismissResults()
        }
        selectionModel.handleMapSelection(coordinate)
    }

    func openLibraryEntry(
        _ entry: NeighborhoodLibraryEntry,
        markMapQuickTipSeen: () -> Void,
        selectionModel: MapSelectionModel,
        searchModel: MapSearchModel,
        compareModel: CompareModeModel
    ) {
        prepareMapNavigation(markMapQuickTipSeen: markMapQuickTipSeen)
        compareModel.clear()
        searchModel.dismissResults()
        focusMap(on: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude))
        selectionModel.openLibraryEntry(entry)
    }

    func openSavedComparison(
        _ entry: SavedComparisonEntry,
        markMapQuickTipSeen: () -> Void,
        selectionModel: MapSelectionModel,
        searchModel: MapSearchModel,
        compareModel: CompareModeModel
    ) {
        prepareMapNavigation(markMapQuickTipSeen: markMapQuickTipSeen)
        searchModel.dismissResults()
        selectionModel.boundaryScale = entry.boundaryScale
        compareModel.clear()

        let primaryCoordinate = CLLocationCoordinate2D(
            latitude: entry.primaryLatitude,
            longitude: entry.primaryLongitude
        )
        focusMap(on: primaryCoordinate)
        selectionModel.handleMapSelection(primaryCoordinate)

        let comparisonResult = PlaceSearchResult(
            title: entry.secondaryTitle,
            subtitle: entry.secondarySubtitle,
            coordinate: CLLocationCoordinate2D(
                latitude: entry.secondaryLatitude,
                longitude: entry.secondaryLongitude
            )
        )
        compareModel.beginComparison(with: comparisonResult, scale: entry.boundaryScale)
    }

    func openDiscoveryRecommendation(
        _ recommendation: NeighborhoodDiscoveryRecommendation,
        markMapQuickTipSeen: () -> Void,
        selectionModel: MapSelectionModel,
        searchModel: MapSearchModel,
        compareModel: CompareModeModel
    ) {
        prepareMapNavigation(markMapQuickTipSeen: markMapQuickTipSeen)
        compareModel.clear()
        searchModel.dismissResults()
        selectionModel.boundaryScale = recommendation.destination.preferredScale

        let coordinate = CLLocationCoordinate2D(
            latitude: recommendation.destination.latitude,
            longitude: recommendation.destination.longitude
        )
        focusMap(on: coordinate)
        selectionModel.handleMapSelection(coordinate)
    }

    func openSearchResult(
        _ result: PlaceSearchResult,
        markMapQuickTipSeen: () -> Void,
        selectionModel: MapSelectionModel,
        searchModel: MapSearchModel,
        compareModel: CompareModeModel
    ) {
        prepareMapNavigation(markMapQuickTipSeen: markMapQuickTipSeen)
        compareModel.clear()
        searchModel.selectResult(result)
        focusMap(on: result.coordinate)
        selectionModel.handleMapSelection(result.coordinate)
    }

    func chooseComparisonResult(
        _ result: PlaceSearchResult,
        compareSearchModel: MapSearchModel,
        compareModel: CompareModeModel,
        boundaryScale: BoundaryOverlayScale
    ) {
        showComparePicker = false
        compareSearchModel.selectResult(result)
        compareModel.beginComparison(with: result, scale: boundaryScale)
    }

    private func prepareMapNavigation(markMapQuickTipSeen: () -> Void) {
        selection = .map
        markMapQuickTipSeen()
        showSearchExperience = false
        showComparePicker = false
    }

    private func focusMap(on coordinate: CLLocationCoordinate2D, minimumZoom: Float = 13) {
        mapFocusRequest = MapFocusRequest(
            id: UUID(),
            coordinate: coordinate,
            minimumZoom: minimumZoom
        )
    }
}
