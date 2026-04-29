//
//  ContentView.swift
//  Lociq
//
//  Created by Chris Mahlke on 3/6/26.
//

import SwiftUI
import CoreLocation
import UIKit

enum TabSelection {
    case map, more
}

enum BoundaryOverlayScale: String, CaseIterable, Identifiable {
    case zip = "ZIP"
    case tract = "Tract"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .zip:
            return AppStrings.More.zipTitle
        case .tract:
            return AppStrings.More.tractTitle
        }
    }

    var themeColor: Color {
        switch self {
        case .zip: return .blue
        case .tract: return .teal
        }
    }
}

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
    @State private var selection: TabSelection = .map
    @State private var sheetOffset: CGFloat = 0
    @State private var showOnboarding: Bool = false
    @State private var showSearchExperience: Bool = false
    @State private var showComparePicker: Bool = false
    @State private var mapFocusRequest: MapFocusRequest?

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

    private var floatingMapControlsBottomPadding: CGFloat {
        if usesSidebarLayout {
            return 20
        }

        return mapBottomInset + 18
    }

    private var shouldShowMapQuickTip: Bool {
        selection == .map && !showOnboarding && !hasSeenMapQuickTip && selectionModel.tappedCoordinate == nil
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
                    hasSeenMapQuickTip = true
                    if usesSidebarLayout {
                        selection = .map
                    }
                    Haptics.selectionChanged()
                    showSearchExperience = false
                    showComparePicker = false
                    compareModel.clear()
                    searchModel.dismissResults()
                }
                selectionModel.handleMapSelection(newValue)
            }
        )
    }

    @ViewBuilder
    private func mapPane(ignoresSafeAreaTop: Bool) -> some View {
        ZStack(alignment: .top) {
            if AppConfig.hasGoogleMapsAPIKey {
                GoogleMapViewRepresentable(
                    tappedCoordinate: tappedBinding,
                    focusRequest: mapFocusRequest,
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
                        showSearchExperience = true
                    }
                        .padding(.horizontal, 12)
                        .padding(.top, 14)
                }

                if selectionModel.isBoundaryLoading {
                    BoundaryLoadingBadge()
                        .padding(.horizontal, 12)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var activeScreen: some View {
        Group {
            switch selection {
            case .map:
                mapPane(ignoresSafeAreaTop: true)
            case .more:
                MoreScreen(
                    libraryStore: libraryStore,
                    discoveryModel: discoveryModel,
                    hasCurrentDiscoverySeed: currentDiscoverySeed != nil,
                    onRefreshDiscovery: refreshDiscovery,
                    onSelectDiscoveryRecommendation: openDiscoveryRecommendation,
                    onSelectPlace: openLibraryEntry,
                    onSelectComparison: openSavedComparison
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidebarContent: some View {
        Group {
            switch selection {
            case .map:
                InsightsSheetContent(
                    zipCode: selectionModel.selectedZipCode,
                    metrics: selectionModel.censusMetrics,
                    demographics: selectionModel.selectedDemographics,
                    zipBundle: selectionModel.selectedZipBundle,
                    metricsSource: selectionModel.metricsSource,
                    hasActiveSelection: selectionModel.hasActiveSelection,
                    isLoadingSelection: selectionModel.isLoadingSelection,
                    selectionFeedbackState: selectionModel.selectionFeedbackState,
                    isRefreshingScale: selectionModel.isRefreshingScale,
                    onRetrySelection: selectionModel.retryCurrentSelection,
                    comparisonProfile: compareModel.secondaryProfile,
                    pendingComparisonTitle: compareModel.pendingComparisonTitle,
                    isLoadingComparison: compareModel.isLoadingComparison,
                    comparisonErrorMessage: compareModel.comparisonErrorMessage,
                    onStartCompare: openComparePicker,
                    onReplaceCompare: openComparePicker,
                    onClearCompare: compareModel.clear,
                    isCurrentPlaceSaved: selectionModel.isCurrentPlaceSaved,
                    onToggleSaved: selectionModel.toggleSavedCurrentPlace,
                    currentLibraryEntry: selectionModel.currentLibraryEntry,
                    onSavePlaceDetails: selectionModel.saveCurrentPlaceWithMetadata,
                    isCurrentComparisonSaved: isCurrentComparisonSaved,
                    onSaveComparison: saveCurrentComparison,
                    boundaryScale: boundaryScaleBinding,
                    sheetOffset: .constant(1000)
                )
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)
            case .more:
                MoreScreen(
                    libraryStore: libraryStore,
                    discoveryModel: discoveryModel,
                    hasCurrentDiscoverySeed: currentDiscoverySeed != nil,
                    onRefreshDiscovery: refreshDiscovery,
                    onSelectDiscoveryRecommendation: openDiscoveryRecommendation,
                    onSelectPlace: openLibraryEntry,
                    onSelectComparison: openSavedComparison
                )
            }
        }
    }

    private func openLibraryEntry(_ entry: NeighborhoodLibraryEntry) {
        selection = .map
        hasSeenMapQuickTip = true
        showSearchExperience = false
        showComparePicker = false
        compareModel.clear()
        searchModel.dismissResults()
        mapFocusRequest = MapFocusRequest(
            id: UUID(),
            coordinate: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude),
            minimumZoom: 13
        )
        selectionModel.openLibraryEntry(entry)
    }

    private func openSavedComparison(_ entry: SavedComparisonEntry) {
        selection = .map
        hasSeenMapQuickTip = true
        showSearchExperience = false
        showComparePicker = false
        searchModel.dismissResults()
        selectionModel.boundaryScale = entry.boundaryScale
        compareModel.clear()

        let primaryCoordinate = CLLocationCoordinate2D(
            latitude: entry.primaryLatitude,
            longitude: entry.primaryLongitude
        )
        mapFocusRequest = MapFocusRequest(
            id: UUID(),
            coordinate: primaryCoordinate,
            minimumZoom: 13
        )
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
        selection = .map
        hasSeenMapQuickTip = true
        showSearchExperience = false
        showComparePicker = false
        compareModel.clear()
        searchModel.dismissResults()
        selectionModel.boundaryScale = recommendation.destination.preferredScale
        let coordinate = CLLocationCoordinate2D(
            latitude: recommendation.destination.latitude,
            longitude: recommendation.destination.longitude
        )
        mapFocusRequest = MapFocusRequest(
            id: UUID(),
            coordinate: coordinate,
            minimumZoom: 13
        )
        selectionModel.handleMapSelection(coordinate)
    }

    private func openSearchResult(_ result: PlaceSearchResult) {
        selection = .map
        hasSeenMapQuickTip = true
        showSearchExperience = false
        showComparePicker = false
        compareModel.clear()
        searchModel.selectResult(result)
        mapFocusRequest = MapFocusRequest(
            id: UUID(),
            coordinate: result.coordinate,
            minimumZoom: 13
        )
        selectionModel.handleMapSelection(result.coordinate)
    }

    private func openComparePicker() {
        compareSearchModel.clear()
        showComparePicker = true
    }

    private func focusMapOnUserArea() {
        hasSeenMapQuickTip = true
        GoogleMapViewRepresentable.focusOnUserOrSelection(selection: selectionModel.tappedCoordinate)
    }

    private func chooseComparisonResult(_ result: PlaceSearchResult) {
        showComparePicker = false
        compareSearchModel.selectResult(result)
        compareModel.beginComparison(with: result, scale: selectionModel.boundaryScale)
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
                            IPadSidebarHeader(selection: $selection)
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

                    if selection == .map {
                        BottomSheet(sheetOffset: $sheetOffset) {
                            InsightsSheetContent(
                                zipCode: selectionModel.selectedZipCode,
                                metrics: selectionModel.censusMetrics,
                                demographics: selectionModel.selectedDemographics,
                                zipBundle: selectionModel.selectedZipBundle,
                                metricsSource: selectionModel.metricsSource,
                                hasActiveSelection: selectionModel.hasActiveSelection,
                                isLoadingSelection: selectionModel.isLoadingSelection,
                                selectionFeedbackState: selectionModel.selectionFeedbackState,
                                isRefreshingScale: selectionModel.isRefreshingScale,
                                onRetrySelection: selectionModel.retryCurrentSelection,
                                comparisonProfile: compareModel.secondaryProfile,
                                pendingComparisonTitle: compareModel.pendingComparisonTitle,
                                isLoadingComparison: compareModel.isLoadingComparison,
                                comparisonErrorMessage: compareModel.comparisonErrorMessage,
                                onStartCompare: openComparePicker,
                                onReplaceCompare: openComparePicker,
                                onClearCompare: compareModel.clear,
                                isCurrentPlaceSaved: selectionModel.isCurrentPlaceSaved,
                                onToggleSaved: selectionModel.toggleSavedCurrentPlace,
                                currentLibraryEntry: selectionModel.currentLibraryEntry,
                                onSavePlaceDetails: selectionModel.saveCurrentPlaceWithMetadata,
                                isCurrentComparisonSaved: isCurrentComparisonSaved,
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
                        BottomRibbon(selection: $selection)
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
        .onChange(of: selection) { newSelection in
            if newSelection == .more, discoveryModel.result == nil, !discoveryModel.isLoading {
                refreshDiscovery()
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingExperienceView {
                hasSeenOnboarding = true
                showOnboarding = false
            }
        }
        .fullScreenCover(isPresented: $showSearchExperience) {
            MapSearchExperienceView(
                model: searchModel,
                promptTitle: AppStrings.Labels.searchPromptTitle,
                promptBody: AppStrings.Labels.searchPromptBody,
                onDismiss: {
                    showSearchExperience = false
                },
                onSelectResult: openSearchResult
            )
        }
        .fullScreenCover(isPresented: $showComparePicker) {
            MapSearchExperienceView(
                model: compareSearchModel,
                promptTitle: AppStrings.Labels.comparePickerTitle,
                promptBody: AppStrings.Labels.comparePickerBody,
                onDismiss: {
                    showComparePicker = false
                },
                onSelectResult: chooseComparisonResult
            )
        }
    }

}

private enum Haptics {
    static func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func softImpact() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.8)
    }
}

private struct MapFloatingControls: View {
    let onFocusMyArea: () -> Void

    var body: some View {
        button(
            icon: "location.fill",
            title: AppStrings.More.myArea,
            action: onFocusMyArea
        )
    }

    private func button(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .frame(width: 18, height: 18)
            .foregroundStyle(.primary)
            .frame(width: 42, height: 42)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.10), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.10), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct MissingGoogleMapsKeyView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.93, green: 0.96, blue: 0.99), Color(red: 0.90, green: 0.94, blue: 0.98)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 14) {
                Image(systemName: "key.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.orange)

                Text(AppStrings.Labels.googleMapsKeyRequired)
                    .font(.title3.weight(.semibold))

                Text(AppStrings.Labels.googleMapsKeyBody)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
        }
    }
}

private struct MapQuickTipCard: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(Color.blue.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(AppStrings.Labels.mapTipTitle)
                    .font(.subheadline.weight(.semibold))
                Text(AppStrings.Labels.mapTipBody)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Color(.systemBackground).opacity(0.7), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppStrings.Labels.dismiss)
        }
        .padding(12)
        .frame(maxWidth: 250, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.blue.opacity(0.15), lineWidth: 0.9)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
    }
}

private struct BoundaryLoadingBadge: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text(AppStrings.Labels.loadingBoundary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(AppStrings.Labels.updatingNeighborhoodOutline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.blue.opacity(0.16), lineWidth: 0.9)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }
}

private struct MapNoticeBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mappin.slash.circle.fill")
                .font(.title3)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text(AppStrings.Labels.locationUnavailable)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color(red: 0.91, green: 0.30, blue: 0.28), Color(red: 0.78, green: 0.18, blue: 0.27)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 3)
    }
}

#Preview {
    ContentView()
}

private struct IPadSidebarHeader: View {
    @Binding var selection: TabSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppStrings.Labels.appTitle)
                    .font(.title2.weight(.bold))
                Text(AppStrings.Labels.ipadSidebarBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                button(
                    title: AppStrings.Labels.profile,
                    systemImage: selection == .map ? IconNames.mapFilled : IconNames.map,
                    tab: .map
                )
                button(
                    title: AppStrings.Labels.guide,
                    systemImage: selection == .more ? IconNames.moreFilled : IconNames.more,
                    tab: .more
                )
            }
        }
    }

    private func button(title: String, systemImage: String, tab: TabSelection) -> some View {
        let isSelected = selection == tab

        return Button {
            selection = tab
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.07), lineWidth: 0.9)
            )
        }
        .accessibilityIdentifier(tab == .map ? "sidebar.profile" : "sidebar.guide")
        .buttonStyle(.plain)
    }
}

private struct OptionalTopSafeAreaIgnoring: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.ignoresSafeArea(edges: .top)
        } else {
            content
        }
    }
}
