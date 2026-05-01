//
//  MapSelectionModel.swift
//  Lociq
//
//  View model that owns map selection, lookup orchestration, and fallback state.
//

import Combine
import CoreLocation
import Foundation
import SwiftUI

enum SelectionFeedbackState: Equatable {
    case noCoverage
    case sampleFallback

    var title: String {
        switch self {
        case .noCoverage:
            return AppStrings.Labels.noCoverageTitle
        case .sampleFallback:
            return AppStrings.Labels.sampleFallbackTitle
        }
    }

    var message: String {
        switch self {
        case .noCoverage:
            return AppStrings.Labels.noCoverageBody
        case .sampleFallback:
            return AppStrings.Labels.sampleFallbackBody
        }
    }

    var symbol: String {
        switch self {
        case .noCoverage:
            return "mappin.slash.circle.fill"
        case .sampleFallback:
            return "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
        }
    }

    var tint: Color {
        switch self {
        case .noCoverage:
            return .orange
        case .sampleFallback:
            return .indigo
        }
    }

    var allowsRetry: Bool {
        switch self {
        case .noCoverage:
            return false
        case .sampleFallback:
            return true
        }
    }
}

@MainActor
final class MapSelectionModel: ObservableObject {
    @Published var tappedCoordinate: CLLocationCoordinate2D?
    @Published var boundaryScale: BoundaryOverlayScale = .zip

    @Published private(set) var selectedZipCode: String?
    @Published private(set) var censusMetrics: CensusMetrics?
    @Published private(set) var selectedDemographics: Demographics?
    @Published private(set) var metricsSource: MetricsSource?
    @Published private(set) var selectedBoundary: GeoJSONFeatureCollection?
    @Published private(set) var neighborhoodBoundaries: NeighborhoodBoundarySet?
    @Published private(set) var selectedZipBundle: ZipLookupResult?
    @Published private(set) var isBoundaryLoading: Bool = false
    @Published private(set) var mapNotice: String?
    @Published private(set) var selectionFeedbackState: SelectionFeedbackState?
    @Published private(set) var isRefreshingScale: Bool = false

    private let service: any CensusNeighborhoodServing
    private let libraryStore: NeighborhoodLibraryStore
    private var activeSelectionRequestID = UUID()
    private var activeFetchTask: Task<Void, Never>?
    private var activeScaleTask: Task<Void, Never>?
    private var libraryStoreCancellable: AnyCancellable?
    private var resolvedCoordinate: CLLocationCoordinate2D?
    private var resolvedPlaceProfile: ResolvedPlaceProfile?

    init(service: any CensusNeighborhoodServing, libraryStore: NeighborhoodLibraryStore) {
        self.service = service
        self.libraryStore = libraryStore
        libraryStoreCancellable = libraryStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var hasActiveSelection: Bool {
        tappedCoordinate != nil
    }

    var isLoadingSelection: Bool {
        tappedCoordinate != nil && (censusMetrics == nil || isBoundaryLoading)
    }

    var savedPlaces: [NeighborhoodLibraryEntry] {
        libraryStore.savedPlaces
    }

    var recentLookups: [NeighborhoodLibraryEntry] {
        libraryStore.recentLookups
    }

    var isCurrentPlaceSaved: Bool {
        guard let currentLookupSnapshot else { return false }
        return libraryStore.isSaved(currentLookupSnapshot)
    }

    var currentLookupSnapshot: NeighborhoodLookupSnapshot? {
        guard let coordinate = resolvedCoordinate, let bundle = selectedZipBundle else { return nil }
        return makeLookupSnapshot(bundle: bundle, coordinate: coordinate)
    }

    var currentResolvedPlaceProfile: ResolvedPlaceProfile? {
        resolvedPlaceProfile
    }

    var currentLibraryEntry: NeighborhoodLibraryEntry? {
        guard let currentLookupSnapshot else { return nil }
        return libraryStore.entry(id: currentLookupSnapshot.id)
    }

    func handleMapSelection(_ coordinate: CLLocationCoordinate2D?) {
        tappedCoordinate = coordinate
        guard let coordinate else { return }
        refreshData(for: coordinate)
    }

    func selectBoundaryScale(_ scale: BoundaryOverlayScale) {
        boundaryScale = scale
        let requestID = activeSelectionRequestID
        activeScaleTask?.cancel()
        activeScaleTask = Task { [weak self] in
            guard let self else { return }
            await self.updateBoundaryAndDataForScale(scale, requestID: requestID)
        }
    }

    func clearMapNotice(ifMatches message: String) {
        if mapNotice == message {
            mapNotice = nil
        }
    }

    func retryCurrentSelection() {
        guard let coordinate = tappedCoordinate else { return }
        refreshData(for: coordinate)
    }

    func cancelCurrentSelectionRequest() {
        clearSelection()
    }

    func clearSelection() {
        activeSelectionRequestID = UUID()
        activeFetchTask?.cancel()
        activeScaleTask?.cancel()
        tappedCoordinate = nil
        selectedZipCode = nil
        censusMetrics = nil
        selectedDemographics = nil
        metricsSource = nil
        selectedBoundary = nil
        neighborhoodBoundaries = nil
        selectedZipBundle = nil
        resolvedCoordinate = nil
        resolvedPlaceProfile = nil
        isBoundaryLoading = false
        isRefreshingScale = false
        mapNotice = nil
        selectionFeedbackState = nil
    }

    func toggleSavedCurrentPlace() {
        guard let currentLookupSnapshot else { return }
        _ = libraryStore.toggleSaved(currentLookupSnapshot)
        objectWillChange.send()
    }

    func saveCurrentPlaceWithMetadata(
        customLabel: String,
        note: String,
        isPinned: Bool
    ) {
        guard let currentLookupSnapshot else { return }
        libraryStore.saveWithMetadata(
            currentLookupSnapshot,
            customLabel: customLabel,
            note: note,
            isPinned: isPinned
        )
        objectWillChange.send()
    }

    func openLibraryEntry(_ entry: NeighborhoodLibraryEntry) {
        boundaryScale = entry.preferredScale
        handleMapSelection(
            CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude)
        )
    }

    private func refreshData(for coordinate: CLLocationCoordinate2D) {
        let requestID = UUID()
        activeSelectionRequestID = requestID
        activeFetchTask?.cancel()
        activeScaleTask?.cancel()
        isBoundaryLoading = true
        isRefreshingScale = false
        mapNotice = nil
        selectionFeedbackState = nil

        activeFetchTask = Task { [weak self] in
            guard let self else { return }
            await self.fetchZipBundleMetrics(for: coordinate, requestID: requestID)
        }
    }

    private func fetchZipBundleMetrics(for coordinate: CLLocationCoordinate2D, requestID: UUID) async {
        do {
            let placeProfile = try await service.fetchPlaceProfile(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            let bundle = placeProfile.zipBundle

            guard isSelectionRequestCurrent(requestID) else { return }

            let (demographics, source) = demographicsForScale(boundaryScale, profile: placeProfile)
            let boundary = boundaryOverlay(for: placeProfile.boundaries, scale: boundaryScale)

            resolvedPlaceProfile = placeProfile
            resolvedCoordinate = coordinate

            withAnimation(.easeInOut(duration: 0.28)) {
                selectedZipCode = bundle.zcta
                censusMetrics = mapDemographicsToMetrics(demographics)
                selectedDemographics = demographics
                metricsSource = source
                selectedBoundary = boundary
                selectedZipBundle = bundle
                neighborhoodBoundaries = placeProfile.boundaries
                isBoundaryLoading = false
                selectionFeedbackState = nil
            }

            if let snapshot = makeLookupSnapshot(bundle: bundle, coordinate: coordinate) {
                libraryStore.recordLookup(snapshot)
            }
        } catch is CancellationError {
            return
        } catch let serviceError as CensusZipDemographicsService.ServiceError {
            guard isSelectionRequestCurrent(requestID) else { return }

            if case .noZCTAFound = serviceError {
                selectedZipCode = nil
                censusMetrics = nil
                selectedDemographics = nil
                metricsSource = nil
                selectedBoundary = nil
                neighborhoodBoundaries = nil
                selectedZipBundle = nil
                resolvedCoordinate = nil
                resolvedPlaceProfile = nil
                isBoundaryLoading = false
                mapNotice = AppStrings.Labels.noZipAvailableNotice
                selectionFeedbackState = .noCoverage
                return
            }

            applySampleFallbackState()
            #if DEBUG
            print(AppStrings.Debug.acsZipFailed, serviceError)
            #endif
        } catch {
            guard isSelectionRequestCurrent(requestID) else { return }
            applySampleFallbackState()
            #if DEBUG
            print(AppStrings.Debug.acsZipFailed, error)
            #endif
        }
    }

    private func updateBoundaryAndDataForScale(_ scale: BoundaryOverlayScale, requestID: UUID) async {
        guard isSelectionRequestCurrent(requestID) else { return }

        guard
            let boundaries = neighborhoodBoundaries,
            let placeProfile = resolvedPlaceProfile
        else {
            selectedBoundary = nil
            return
        }

        selectedBoundary = boundaryOverlay(for: boundaries, scale: scale)
        defer {
            if isSelectionRequestCurrent(requestID) {
                isRefreshingScale = false
            }
        }

        let (demographics, source) = demographicsForScale(scale, profile: placeProfile)

        guard isSelectionRequestCurrent(requestID) else { return }

        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
            censusMetrics = mapDemographicsToMetrics(demographics)
            selectedDemographics = demographics
            metricsSource = source
            selectionFeedbackState = nil
        }
    }

    private func demographicsForScale(
        _ scale: BoundaryOverlayScale,
        profile: ResolvedPlaceProfile
    ) -> (Demographics, MetricsSource) {
        switch scale {
        case .zip:
            return (profile.scaleDemographics.zip, .zcta)
        case .tract:
            if let demographics = profile.scaleDemographics.tract {
                return (demographics, .tract)
            }

            return (profile.scaleDemographics.zip, .zcta)
        }
    }

    private func isSelectionRequestCurrent(_ requestID: UUID) -> Bool {
        activeSelectionRequestID == requestID
    }

    private func applySampleFallbackState() {
        selectedZipCode = nil
        censusMetrics = SampleMetricsFactory.make(seedString: AppStrings.Network.defaultSeed)
        selectedDemographics = nil
        metricsSource = .sample
        selectedBoundary = nil
        neighborhoodBoundaries = nil
        selectedZipBundle = nil
        resolvedCoordinate = nil
        resolvedPlaceProfile = nil
        isBoundaryLoading = false
        selectionFeedbackState = .sampleFallback
    }

    private func mapDemographicsToMetrics(_ demographics: Demographics) -> CensusMetrics {
        CensusMetrics(
            population: demographics.population,
            medianIncome: demographics.medianHouseholdIncome,
            medianAge: demographics.medianAge,
            households: demographics.housingUnits,
            populationTrend: nil,
            ageBuckets: nil,
            educationLevels: nil,
            householdIncome: nil
        )
    }

    private func boundaryOverlay(
        for boundaries: NeighborhoodBoundarySet,
        scale: BoundaryOverlayScale
    ) -> GeoJSONFeatureCollection? {
        switch scale {
        case .zip:
            return boundaries.zip
        case .tract:
            return boundaries.tract
        }
    }

    private func makeLookupSnapshot(
        bundle: ZipLookupResult,
        coordinate: CLLocationCoordinate2D
    ) -> NeighborhoodLookupSnapshot? {
        let title: String
        if let placeName = bundle.place?.name, !placeName.isEmpty {
            title = placeName
        } else if !bundle.demographics.name.isEmpty {
            title = bundle.demographics.name
        } else {
            title = AppStrings.Formats.zip(bundle.zcta)
        }

        var subtitleParts: [String] = []
        if let countyName = bundle.county?.name, !countyName.isEmpty {
            subtitleParts.append(countyName)
        }
        subtitleParts.append(AppStrings.Formats.zip(bundle.zcta))
        if let tractCode = bundle.tract?.tractCode, !tractCode.isEmpty {
            subtitleParts.append(AppStrings.Formats.tract(tractCode))
        }

        let entryID = bundle.tract?.geoid ?? bundle.zcta
        guard !entryID.isEmpty else { return nil }

        return NeighborhoodLookupSnapshot(
            id: entryID,
            title: title,
            subtitle: subtitleParts.joined(separator: " · "),
            zipCode: bundle.zcta,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            preferredScale: boundaryScale
        )
    }
}
