//
//  ContentView.swift
//  Lociq
//
//  Created by Chris Mahlke on 3/6/26.
//

import SwiftUI
import CoreLocation
import UIKit

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @AppStorage("hasSeenMapQuickTip") private var hasSeenMapQuickTip: Bool = false

    @StateObject private var selectionModel: MapSelectionModel
    @StateObject private var searchModel: MapSearchModel
    @StateObject private var compareSearchModel: MapSearchModel
    @StateObject private var compareModel: CompareModeModel
    @StateObject private var discoveryModel: NeighborhoodDiscoveryModel
    @StateObject private var libraryStore: NeighborhoodLibraryStore
    @StateObject private var flowCoordinator = ContentFlowCoordinator()
    @State private var sheetOffset: CGFloat = 0
    @State private var showOnboarding: Bool = false

    init(dependencies: AppDependencies = .live) {
        _libraryStore = StateObject(wrappedValue: dependencies.neighborhoodLibraryStore)
        _searchModel = StateObject(wrappedValue: MapSearchModel(service: dependencies.makePlaceSearchService()))
        _compareSearchModel = StateObject(wrappedValue: MapSearchModel(service: dependencies.makePlaceSearchService()))
        _compareModel = StateObject(wrappedValue: CompareModeModel(service: dependencies.makeCensusLookupService()))
        _discoveryModel = StateObject(
            wrappedValue: NeighborhoodDiscoveryModel(
                service: dependencies.makeNeighborhoodDiscoveryService(),
                libraryStore: dependencies.neighborhoodLibraryStore
            )
        )
        _selectionModel = StateObject(
            wrappedValue: MapSelectionModel(
                service: dependencies.makeCensusLookupService(),
                libraryStore: dependencies.neighborhoodLibraryStore
            )
        )
    }

    private var isUITestSkippingOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_SKIP_ONBOARDING")
    }

    private var isUITestResettingState: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_RESET_STATE")
    }

    private var defaultSheetPeekHeight: CGFloat {
        max(140, min(220, UIScreen.main.bounds.height * 0.25))
    }

    private var usesSidebarLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    private var mapBottomInset: CGFloat {
        if usesSidebarLayout {
            return 20
        }

        return max(defaultSheetPeekHeight, sheetOffset) + 12
    }

    private var boundaryThemeTint: Color {
        selectionModel.boundaryScale.themeColor
    }

    private var insightsPresentation: InsightsSheetPresentation {
        InsightsSheetPresentation(
            zipCode: selectionModel.selectedZipCode,
            metrics: selectionModel.censusMetrics,
            demographics: selectionModel.selectedDemographics,
            zipBundle: selectionModel.selectedZipBundle,
            metricsSource: selectionModel.metricsSource,
            hasActiveSelection: selectionModel.hasActiveSelection,
            isLoadingSelection: selectionModel.isLoadingSelection,
            selectionFeedbackState: selectionModel.selectionFeedbackState,
            isRefreshingScale: selectionModel.isRefreshingScale,
            comparisonProfile: compareModel.secondaryProfile,
            pendingComparisonTitle: compareModel.pendingComparisonTitle,
            isLoadingComparison: compareModel.isLoadingComparison,
            comparisonErrorMessage: compareModel.comparisonErrorMessage,
            isCurrentPlaceSaved: selectionModel.isCurrentPlaceSaved,
            currentLibraryEntry: selectionModel.currentLibraryEntry,
            isCurrentComparisonSaved: isCurrentComparisonSaved
        )
    }

    private var floatingMapControlsBottomPadding: CGFloat {
        if usesSidebarLayout {
            return 20
        }

        return mapBottomInset + 18
    }

    private var shouldShowMapQuickTip: Bool {
        flowCoordinator.selection == .map && !showOnboarding && !hasSeenMapQuickTip && selectionModel.tappedCoordinate == nil
    }

    private var boundaryScaleBinding: Binding<BoundaryOverlayScale> {
        Binding(
            get: { selectionModel.boundaryScale },
            set: { newValue in
                guard newValue != selectionModel.boundaryScale else { return }
                Haptics.softImpact()
                selectionModel.selectBoundaryScale(newValue)
            }
        )
    }

    private var tappedBinding: Binding<CLLocationCoordinate2D?> {
        Binding(
            get: { selectionModel.tappedCoordinate },
            set: { newValue in
                if newValue != nil {
                    Haptics.selectionChanged()
                }
                flowCoordinator.handleMapSelection(
                    newValue,
                    usesSidebarLayout: usesSidebarLayout,
                    markMapQuickTipSeen: markMapQuickTipSeen,
                    selectionModel: selectionModel,
                    searchModel: searchModel,
                    compareModel: compareModel
                )
            }
        )
    }

    @ViewBuilder
    private func mapPane(ignoresSafeAreaTop: Bool) -> some View {
        ZStack(alignment: .top) {
            if AppConfig.hasGoogleMapsAPIKey {
                GoogleMapViewRepresentable(
                    tappedCoordinate: tappedBinding,
                    focusRequest: flowCoordinator.mapFocusRequest,
                    selectedBoundary: selectionModel.selectedBoundary,
                    selectedScale: selectionModel.boundaryScale,
                    contentInsetBottom: mapBottomInset
                )
                .modifier(OptionalTopSafeAreaIgnoring(enabled: ignoresSafeAreaTop))
            } else {
                MissingGoogleMapsKeyView()
                    .modifier(OptionalTopSafeAreaIgnoring(enabled: ignoresSafeAreaTop))
            }

            VStack(alignment: .leading, spacing: 10) {
                if AppConfig.hasGoogleMapsAPIKey {
                    MapSearchLauncher(query: searchModel.query) {
                        flowCoordinator.showSearch()
                    }
                        .padding(.horizontal, 12)
                        .padding(.top, 14)
                }

                if let mapNotice = selectionModel.mapNotice {
                    MapNoticeBanner(message: mapNotice)
                        .padding(.horizontal, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: mapNotice) {
                            try? await Task.sleep(nanoseconds: 4_500_000_000)
                            selectionModel.clearMapNotice(ifMatches: mapNotice)
                        }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if AppConfig.hasGoogleMapsAPIKey {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MapFloatingControls(onFocusMyArea: focusMapOnUserArea)
                    }
                }
                .padding(.trailing, 12)
                .padding(.bottom, floatingMapControlsBottomPadding)
                .animation(.easeInOut(duration: 0.2), value: floatingMapControlsBottomPadding)
            }

            if AppConfig.hasGoogleMapsAPIKey && shouldShowMapQuickTip {
                VStack {
                    Spacer()
                    HStack {
                        MapQuickTipCard {
                            withAnimation(.easeOut(duration: 0.2)) {
                                hasSeenMapQuickTip = true
                            }
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))

                        Spacer()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, mapBottomInset + 28)
                .animation(.easeInOut(duration: 0.2), value: mapBottomInset)
            }

            if AppConfig.hasGoogleMapsAPIKey && selectionModel.isLoadingSelection {
                MapLoadingOverlay(onCancel: selectionModel.cancelCurrentSelectionRequest)
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var activeScreen: some View {
        Group {
            switch flowCoordinator.selection {
            case .map:
                mapPane(ignoresSafeAreaTop: true)
            case .library:
                LibraryScreen(
                    libraryStore: libraryStore,
                    discoveryModel: discoveryModel,
                    hasCurrentDiscoverySeed: currentDiscoverySeed != nil,
                    onRefreshDiscovery: refreshDiscovery,
                    onSelectDiscoveryRecommendation: openDiscoveryRecommendation,
                    onSelectPlace: openLibraryEntry,
                    onSelectComparison: openSavedComparison
                )
            case .guide:
                GuideScreen()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidebarContent: some View {
        Group {
            switch flowCoordinator.selection {
            case .map:
                InsightsSheetContent(
                    presentation: insightsPresentation,
                    onRetrySelection: selectionModel.retryCurrentSelection,
                    onStartCompare: openComparePicker,
                    onReplaceCompare: openComparePicker,
                    onClearCompare: compareModel.clear,
                    onToggleSaved: selectionModel.toggleSavedCurrentPlace,
                    onSavePlaceDetails: selectionModel.saveCurrentPlaceWithMetadata,
                    onSaveComparison: saveCurrentComparison,
                    boundaryScale: boundaryScaleBinding,
                    sheetOffset: .constant(1000)
                )
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)
            case .library:
                LibraryScreen(
                    libraryStore: libraryStore,
                    discoveryModel: discoveryModel,
                    hasCurrentDiscoverySeed: currentDiscoverySeed != nil,
                    onRefreshDiscovery: refreshDiscovery,
                    onSelectDiscoveryRecommendation: openDiscoveryRecommendation,
                    onSelectPlace: openLibraryEntry,
                    onSelectComparison: openSavedComparison
                )
            case .guide:
                GuideScreen()
            }
        }
    }

    private func openLibraryEntry(_ entry: NeighborhoodLibraryEntry) {
        flowCoordinator.openLibraryEntry(
            entry,
            markMapQuickTipSeen: markMapQuickTipSeen,
            selectionModel: selectionModel,
            searchModel: searchModel,
            compareModel: compareModel
        )
    }

    private func openSavedComparison(_ entry: SavedComparisonEntry) {
        flowCoordinator.openSavedComparison(
            entry,
            markMapQuickTipSeen: markMapQuickTipSeen,
            selectionModel: selectionModel,
            searchModel: searchModel,
            compareModel: compareModel
        )
    }

    private var currentDiscoverySeed: NeighborhoodDiscoverySeed? {
        guard let snapshot = selectionModel.currentLookupSnapshot else { return nil }
        return NeighborhoodDiscoverySeed(
            snapshot: snapshot,
            profile: selectionModel.currentResolvedPlaceProfile
        )
    }

    private func refreshDiscovery() {
        discoveryModel.refresh(
            currentSeed: currentDiscoverySeed,
            fallbackEntry: libraryStore.recentLookups.first
        )
    }

    private func openDiscoveryRecommendation(_ recommendation: NeighborhoodDiscoveryRecommendation) {
        flowCoordinator.openDiscoveryRecommendation(
            recommendation,
            markMapQuickTipSeen: markMapQuickTipSeen,
            selectionModel: selectionModel,
            searchModel: searchModel,
            compareModel: compareModel
        )
    }

    private func openSearchResult(_ result: PlaceSearchResult) {
        flowCoordinator.openSearchResult(
            result,
            markMapQuickTipSeen: markMapQuickTipSeen,
            selectionModel: selectionModel,
            searchModel: searchModel,
            compareModel: compareModel
        )
    }

    private func openComparePicker() {
        flowCoordinator.openComparePicker(compareSearchModel: compareSearchModel)
    }

    private func focusMapOnUserArea() {
        markMapQuickTipSeen()
        GoogleMapViewRepresentable.focusOnUserOrSelection(selection: selectionModel.tappedCoordinate)
    }

    private func chooseComparisonResult(_ result: PlaceSearchResult) {
        flowCoordinator.chooseComparisonResult(
            result,
            compareSearchModel: compareSearchModel,
            compareModel: compareModel,
            boundaryScale: selectionModel.boundaryScale
        )
    }

    private func markMapQuickTipSeen() {
        hasSeenMapQuickTip = true
    }

    private var currentComparisonSnapshot: SavedComparisonSnapshot? {
        guard let primarySnapshot = selectionModel.currentLookupSnapshot else { return nil }
        return compareModel.makeSavedComparisonSnapshot(
            primary: primarySnapshot,
            scale: selectionModel.boundaryScale
        )
    }

    private var isCurrentComparisonSaved: Bool {
        guard let currentComparisonSnapshot else { return false }
        return libraryStore.isComparisonSaved(id: currentComparisonSnapshot.id)
    }

    private func saveCurrentComparison() {
        guard let currentComparisonSnapshot else { return }
        if libraryStore.isComparisonSaved(id: currentComparisonSnapshot.id) {
            libraryStore.removeSavedComparison(id: currentComparisonSnapshot.id)
        } else {
            libraryStore.saveComparison(currentComparisonSnapshot)
        }
    }

    var body: some View {
        Group {
            if usesSidebarLayout {
                GeometryReader { geo in
                    let sidebarWidth = min(max(geo.size.width * 0.34, 360), 460)

                    HStack(spacing: 0) {
                        VStack(spacing: 0) {
                            IPadSidebarHeader(selection: $flowCoordinator.selection)
                                .padding(.horizontal, 20)
                                .padding(.top, 18)
                                .padding(.bottom, 14)

                            Divider()

                            sidebarContent
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        }
                        .frame(width: sidebarWidth)
                        .background(Color(.secondarySystemGroupedBackground))

                        Divider()

                        mapPane(ignoresSafeAreaTop: false)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground))
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            } else {
                ZStack(alignment: .bottom) {
                    activeScreen

                    if flowCoordinator.selection == .map {
                        BottomSheet(sheetOffset: $sheetOffset) {
                            InsightsSheetContent(
                                presentation: insightsPresentation,
                                onRetrySelection: selectionModel.retryCurrentSelection,
                                onStartCompare: openComparePicker,
                                onReplaceCompare: openComparePicker,
                                onClearCompare: compareModel.clear,
                                onToggleSaved: selectionModel.toggleSavedCurrentPlace,
                                onSavePlaceDetails: selectionModel.saveCurrentPlaceWithMetadata,
                                onSaveComparison: saveCurrentComparison,
                                boundaryScale: boundaryScaleBinding,
                                sheetOffset: $sheetOffset
                            )
                        }
                        .tint(boundaryThemeTint)
                        .animation(.easeInOut(duration: 0.25), value: selectionModel.boundaryScale)
                        .accessibilitySortPriority(1)
                        .zIndex(1)
                    }

                    VStack(spacing: 0) {
                        BottomRibbon(selection: $flowCoordinator.selection)
                    }
                    .zIndex(2)
                    .allowsHitTesting(true)
                }
            }
        }
        .onAppear {
            if isUITestResettingState {
                hasSeenOnboarding = false
                hasSeenMapQuickTip = false
            }
            if isUITestSkippingOnboarding {
                hasSeenOnboarding = true
            }
            if !hasSeenOnboarding {
                showOnboarding = true
            }
        }
        .onChange(of: selectionModel.boundaryScale) { newScale in
            compareModel.refreshComparison(for: newScale)
        }
        .onChange(of: flowCoordinator.selection) { newSelection in
            if newSelection == .library, discoveryModel.result == nil, !discoveryModel.isLoading {
                refreshDiscovery()
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingExperienceView {
                hasSeenOnboarding = true
                showOnboarding = false
            }
        }
        .fullScreenCover(isPresented: $flowCoordinator.showSearchExperience) {
            MapSearchExperienceView(
                model: searchModel,
                promptTitle: AppStrings.Labels.searchPromptTitle,
                promptBody: AppStrings.Labels.searchPromptBody,
                onDismiss: {
                    flowCoordinator.dismissSearch()
                },
                onSelectResult: openSearchResult
            )
        }
        .fullScreenCover(isPresented: $flowCoordinator.showComparePicker) {
            MapSearchExperienceView(
                model: compareSearchModel,
                promptTitle: AppStrings.Labels.comparePickerTitle,
                promptBody: AppStrings.Labels.comparePickerBody,
                onDismiss: {
                    flowCoordinator.dismissComparePicker()
                },
                onSelectResult: chooseComparisonResult
            )
        }
    }

}

#Preview {
    ContentView()
}
