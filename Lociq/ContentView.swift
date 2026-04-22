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

    @State private var selection: TabSelection = .map
    @State private var tappedCoordinate: CLLocationCoordinate2D?
    @State private var selectedZipCode: String? = nil
    @State private var censusMetrics: CensusMetrics? = nil
    @State private var selectedDemographics: Demographics? = nil
    @State private var sheetOffset: CGFloat = 0
    @State private var metricsSource: MetricsSource? = nil
    @State private var selectedBoundary: GeoJSONFeatureCollection? = nil
    @State private var neighborhoodBoundaries: NeighborhoodBoundarySet? = nil
    @State private var boundaryScale: BoundaryOverlayScale = .zip
    @State private var selectedZipBundle: ZipLookupResult? = nil
    @State private var activeSelectionRequestID: UUID = UUID()
    @State private var activeFetchTask: Task<Void, Never>? = nil
    @State private var activeScaleTask: Task<Void, Never>? = nil
    @State private var isBoundaryLoading: Bool = false
    @State private var mapNotice: String? = nil
    @State private var showOnboarding: Bool = false

    private var isUITestSkippingOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_SKIP_ONBOARDING")
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
        boundaryScale.themeColor
    }

    private var shouldShowMapQuickTip: Bool {
        selection == .map && !showOnboarding && !hasSeenMapQuickTip && tappedCoordinate == nil
    }

    private var tappedBinding: Binding<CLLocationCoordinate2D?> {
        Binding(
            get: { tappedCoordinate },
            set: { newValue in
                tappedCoordinate = newValue
                if let coord = newValue {
                    hasSeenMapQuickTip = true
                    if usesSidebarLayout {
                        selection = .map
                    }
                    Haptics.selectionChanged()
                    refreshData(for: coord)
                }
            }
        )
    }

    @ViewBuilder
    private func mapPane(ignoresSafeAreaTop: Bool) -> some View {
        ZStack(alignment: .top) {
            if AppConfig.hasGoogleMapsAPIKey {
                GoogleMapViewRepresentable(
                    tappedCoordinate: tappedBinding,
                    selectedBoundary: selectedBoundary,
                    selectedScale: boundaryScale,
                    contentInsetBottom: mapBottomInset
                )
                .modifier(OptionalTopSafeAreaIgnoring(enabled: ignoresSafeAreaTop))
            } else {
                MissingGoogleMapsKeyView()
                    .modifier(OptionalTopSafeAreaIgnoring(enabled: ignoresSafeAreaTop))
            }

            if isBoundaryLoading {
                BoundaryLoadingBadge()
                    .padding(.top, 14)
            }

            if let mapNotice {
                MapNoticeBanner(message: mapNotice)
                    .padding(.top, isBoundaryLoading ? 62 : 14)
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: mapNotice) {
                        try? await Task.sleep(nanoseconds: 4_500_000_000)
                        if self.mapNotice == mapNotice {
                            self.mapNotice = nil
                        }
                    }
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
                MoreScreen()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidebarContent: some View {
        Group {
            switch selection {
            case .map:
                InsightsSheetContent(
                    zipCode: selectedZipCode,
                    metrics: censusMetrics,
                    demographics: selectedDemographics,
                    zipBundle: selectedZipBundle,
                    metricsSource: metricsSource,
                    hasActiveSelection: tappedCoordinate != nil,
                    isLoadingSelection: tappedCoordinate != nil && (censusMetrics == nil || isBoundaryLoading),
                    boundaryScale: $boundaryScale,
                    sheetOffset: .constant(1000)
                )
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)
            case .more:
                MoreScreen()
            }
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
                                zipCode: selectedZipCode,
                                metrics: censusMetrics,
                                demographics: selectedDemographics,
                                zipBundle: selectedZipBundle,
                                metricsSource: metricsSource,
                                hasActiveSelection: tappedCoordinate != nil,
                                isLoadingSelection: tappedCoordinate != nil && (censusMetrics == nil || isBoundaryLoading),
                                boundaryScale: $boundaryScale,
                                sheetOffset: $sheetOffset
                            )
                        }
                        .tint(boundaryThemeTint)
                        .animation(.easeInOut(duration: 0.25), value: boundaryScale)
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
        .onChange(of: boundaryScale) { newScale in
            Haptics.softImpact()
            let requestID = activeSelectionRequestID
            activeScaleTask?.cancel()
            activeScaleTask = Task {
                await updateBoundaryAndDataForScale(newScale, requestID: requestID)
            }
        }
        .onAppear {
            if isUITestSkippingOnboarding {
                hasSeenOnboarding = true
            }
            if !hasSeenOnboarding {
                showOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingExperienceView {
                hasSeenOnboarding = true
                showOnboarding = false
            }
        }
    }

    private func refreshData(for coordinate: CLLocationCoordinate2D) {
        let requestID = UUID()
        activeSelectionRequestID = requestID
        activeFetchTask?.cancel()
        activeScaleTask?.cancel()
        isBoundaryLoading = true
        mapNotice = nil

        // Reset metrics first so the sheet can immediately show a loading state for
        // the newly selected coordinate.
        Task { @MainActor in
            censusMetrics = nil
            selectedDemographics = nil
            metricsSource = nil
            selectedZipBundle = nil
            selectedBoundary = nil
            neighborhoodBoundaries = nil
        }

        activeFetchTask = Task {
            await fetchZipBundleMetrics(for: coordinate, requestID: requestID)
        }
    }

    // MARK: - ZIP bundle service (ZCTA + boundary + demographics)
    private func fetchZipBundleMetrics(for coordinate: CLLocationCoordinate2D, requestID: UUID) async {
        let service = CensusZipDemographicsService(censusApiKey: AppConfig.censusAPIKey)

        do {
            let bundle = try await service.fetchZipBundle(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )

            guard await isSelectionRequestCurrent(requestID) else { return }

            let metrics = mapDemographicsToMetrics(bundle.demographics)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.28)) {
                    self.selectedZipCode = bundle.zcta
                    self.censusMetrics = metrics
                    self.selectedDemographics = bundle.demographics
                    self.metricsSource = .zcta
                    self.selectedBoundary = bundle.boundary
                    self.selectedZipBundle = bundle
                }
            }

            let boundaries = await service.fetchNeighborhoodBoundaries(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                tractGeoid: bundle.tract?.geoid,
                zipBoundary: bundle.boundary
            )

            guard await isSelectionRequestCurrent(requestID) else { return }

            await MainActor.run {
                self.neighborhoodBoundaries = boundaries
                self.selectedBoundary = boundaryOverlay(for: boundaries, scale: boundaryScale)
                self.isBoundaryLoading = false
            }

            if boundaryScale != .zip {
                await updateBoundaryAndDataForScale(boundaryScale, requestID: requestID)
            }
        } catch is CancellationError {
            return
        } catch let serviceError as CensusZipDemographicsService.ServiceError {
            guard await isSelectionRequestCurrent(requestID) else { return }

            if case .noZCTAFound = serviceError {
                await MainActor.run {
                    self.selectedZipCode = nil
                    self.censusMetrics = nil
                    self.metricsSource = nil
                    self.selectedBoundary = nil
                    self.neighborhoodBoundaries = nil
                    self.selectedZipBundle = nil
                    self.isBoundaryLoading = false
                    self.mapNotice = AppStrings.Labels.noZipAvailableNotice
                }
                return
            }

            let fallback = SampleMetricsFactory.make(seedString: AppStrings.Network.defaultSeed)
            await MainActor.run {
                self.selectedZipCode = nil
                self.censusMetrics = fallback
                self.selectedDemographics = nil
                self.metricsSource = .sample
                self.selectedBoundary = nil
                self.neighborhoodBoundaries = nil
                self.selectedZipBundle = nil
                self.isBoundaryLoading = false
            }
            #if DEBUG
            print(AppStrings.Debug.acsZipFailed, serviceError)
            #endif
        } catch {
            guard await isSelectionRequestCurrent(requestID) else { return }
            let fallback = SampleMetricsFactory.make(seedString: AppStrings.Network.defaultSeed)
            await MainActor.run {
                self.selectedZipCode = nil
                self.censusMetrics = fallback
                self.selectedDemographics = nil
                self.metricsSource = .sample
                self.selectedBoundary = nil
                self.neighborhoodBoundaries = nil
                self.selectedZipBundle = nil
                self.isBoundaryLoading = false
            }
            #if DEBUG
            print(AppStrings.Debug.acsZipFailed, error)
            #endif
        }
    }

    private func mapDemographicsToMetrics(_ demographics: Demographics) -> CensusMetrics {
        return CensusMetrics(
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

    private func boundaryOverlay(for boundaries: NeighborhoodBoundarySet, scale: BoundaryOverlayScale) -> GeoJSONFeatureCollection? {
        switch scale {
        case .zip:
            return boundaries.zip
        case .tract:
            return boundaries.tract
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

extension ContentView {
    private func updateBoundaryAndDataForScale(_ scale: BoundaryOverlayScale, requestID: UUID) async {
        guard await isSelectionRequestCurrent(requestID) else { return }

        guard
            let boundaries = neighborhoodBoundaries,
            let coordinate = tappedCoordinate,
            let bundle = selectedZipBundle
        else {
            selectedBoundary = nil
            return
        }

        await MainActor.run {
            selectedBoundary = boundaryOverlay(for: boundaries, scale: scale)
        }

        let service = CensusZipDemographicsService(censusApiKey: AppConfig.censusAPIKey)
        let requestedScale: NeighborhoodScale = {
            switch scale {
            case .zip: return .zip
            case .tract: return .tract
            }
        }()

        do {
            let (demographics, source) = try await fetchScaleDemographicsWithFallback(
                for: requestedScale,
                service: service,
                bundle: bundle,
                coordinate: coordinate
            )

            guard await isSelectionRequestCurrent(requestID) else { return }
            let metrics = mapDemographicsToMetrics(demographics)
            await MainActor.run {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
                    censusMetrics = metrics
                    selectedDemographics = demographics
                    metricsSource = source
                }
            }
        } catch is CancellationError {
            return
        } catch {
            guard await isSelectionRequestCurrent(requestID) else { return }
            await MainActor.run {
                metricsSource = .zcta
                censusMetrics = mapDemographicsToMetrics(bundle.demographics)
                selectedDemographics = bundle.demographics
            }
        }
    }

    private func isSelectionRequestCurrent(_ requestID: UUID) async -> Bool {
        await MainActor.run {
            activeSelectionRequestID == requestID
        }
    }

    private func fetchScaleDemographicsWithFallback(
        for scale: NeighborhoodScale,
        service: CensusZipDemographicsService,
        bundle: ZipLookupResult,
        coordinate: CLLocationCoordinate2D
    ) async throws -> (Demographics, MetricsSource) {
        switch scale {
        case .zip:
            let demographics = try await service.fetchDemographics(
                for: .zip,
                zcta: bundle.zcta,
                tractGeoid: bundle.tract?.geoid,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            return (demographics, .zcta)
        case .tract:
            if let demographics = try? await service.fetchDemographics(
                for: .tract,
                zcta: bundle.zcta,
                tractGeoid: bundle.tract?.geoid,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ) {
                return (demographics, .tract)
            }
            let fallback = try await service.fetchDemographics(
                for: .zip,
                zcta: bundle.zcta,
                tractGeoid: bundle.tract?.geoid,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            return (fallback, .zcta)
        }
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
