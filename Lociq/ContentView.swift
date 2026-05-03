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

private struct MapLoadingOverlay: View {
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.08)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.blue)
                    .scaleEffect(1.15)

                VStack(spacing: 4) {
                    Text(AppStrings.Labels.loadingBoundary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(AppStrings.Labels.updatingNeighborhoodOutline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                }

                Button(AppStrings.Labels.cancel, action: onCancel)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, y: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    title: AppStrings.Tabs.map,
                    systemImage: selection == .map ? IconNames.mapFilled : IconNames.map,
                    tab: .map
                )
                button(
                    title: AppStrings.Tabs.library,
                    systemImage: selection == .library ? IconNames.libraryFilled : IconNames.library,
                    tab: .library
                )
                button(
                    title: AppStrings.Tabs.guide,
                    systemImage: selection == .guide ? IconNames.guideFilled : IconNames.guide,
                    tab: .guide
                )
            }
        }
    }

    private func button(title: String, systemImage: String, tab: TabSelection) -> some View {
        let isSelected = selection == tab
        let identifier: String = switch tab {
        case .map:
            "sidebar.map"
        case .library:
            "sidebar.library"
        case .guide:
            "sidebar.guide"
        }

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
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.systemBackground))
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(height: 2)
                    .padding(.horizontal, 14)
            }
        }
        .accessibilityIdentifier(identifier)
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
