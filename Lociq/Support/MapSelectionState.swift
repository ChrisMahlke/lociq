import CoreLocation
import Foundation

struct MapSelectionState {
    var selectedZipCode: String?
    var censusMetrics: CensusMetrics?
    var selectedDemographics: Demographics?
    var metricsSource: MetricsSource?
    var selectedBoundary: GeoJSONFeatureCollection?
    var neighborhoodBoundaries: NeighborhoodBoundarySet?
    var selectedZipBundle: ZipLookupResult?
    var isBoundaryLoading: Bool
    var mapNotice: String?
    var selectionFeedbackState: SelectionFeedbackState?
    var isRefreshingScale: Bool
    var resolvedCoordinate: CLLocationCoordinate2D?
    var resolvedPlaceProfile: ResolvedPlaceProfile?

    init(
        selectedZipCode: String? = nil,
        censusMetrics: CensusMetrics? = nil,
        selectedDemographics: Demographics? = nil,
        metricsSource: MetricsSource? = nil,
        selectedBoundary: GeoJSONFeatureCollection? = nil,
        neighborhoodBoundaries: NeighborhoodBoundarySet? = nil,
        selectedZipBundle: ZipLookupResult? = nil,
        isBoundaryLoading: Bool = false,
        mapNotice: String? = nil,
        selectionFeedbackState: SelectionFeedbackState? = nil,
        isRefreshingScale: Bool = false,
        resolvedCoordinate: CLLocationCoordinate2D? = nil,
        resolvedPlaceProfile: ResolvedPlaceProfile? = nil
    ) {
        self.selectedZipCode = selectedZipCode
        self.censusMetrics = censusMetrics
        self.selectedDemographics = selectedDemographics
        self.metricsSource = metricsSource
        self.selectedBoundary = selectedBoundary
        self.neighborhoodBoundaries = neighborhoodBoundaries
        self.selectedZipBundle = selectedZipBundle
        self.isBoundaryLoading = isBoundaryLoading
        self.mapNotice = mapNotice
        self.selectionFeedbackState = selectionFeedbackState
        self.isRefreshingScale = isRefreshingScale
        self.resolvedCoordinate = resolvedCoordinate
        self.resolvedPlaceProfile = resolvedPlaceProfile
    }

    static let empty = MapSelectionState()

    func loadingNextSelection() -> MapSelectionState {
        var state = self
        state.isBoundaryLoading = true
        state.isRefreshingScale = false
        state.mapNotice = nil
        state.selectionFeedbackState = nil
        return state
    }

    static func loaded(
        coordinate: CLLocationCoordinate2D,
        profile: ResolvedPlaceProfile,
        demographics: Demographics,
        metricsSource: MetricsSource,
        boundary: GeoJSONFeatureCollection?,
        metrics: CensusMetrics
    ) -> MapSelectionState {
        MapSelectionState(
            selectedZipCode: profile.zipBundle.zcta,
            censusMetrics: metrics,
            selectedDemographics: demographics,
            metricsSource: metricsSource,
            selectedBoundary: boundary,
            neighborhoodBoundaries: profile.boundaries,
            selectedZipBundle: profile.zipBundle,
            resolvedCoordinate: coordinate,
            resolvedPlaceProfile: profile
        )
    }

    static func noCoverage(notice: String) -> MapSelectionState {
        MapSelectionState(
            mapNotice: notice,
            selectionFeedbackState: .noCoverage
        )
    }

    static func sampleFallback(metrics: CensusMetrics) -> MapSelectionState {
        MapSelectionState(
            censusMetrics: metrics,
            metricsSource: .sample,
            selectionFeedbackState: .sampleFallback
        )
    }
}
