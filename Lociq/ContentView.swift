//
//  ContentView.swift
//  Lociq
//
//  Created by Chris Mahlke on 3/6/26.
//

import SwiftUI
import CoreLocation

enum TabSelection {
    case map, more
}

enum BoundaryOverlayScale: String, CaseIterable, Identifiable {
    case zip = "ZIP"
    case tract = "Tract"

    var id: String { rawValue }

    var themeColor: Color {
        switch self {
        case .zip: return .blue
        case .tract: return .teal
        }
    }
}

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

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

    // Keeps floating controls above the ribbon and visible when the sheet is at peek height.
    private var mapControlsBottomPadding: CGFloat {
        max(214, sheetOffset + 54)
    }

    private var boundaryThemeTint: Color {
        boundaryScale.themeColor
    }

    private var tappedBinding: Binding<CLLocationCoordinate2D?> {
        Binding(
            get: { tappedCoordinate },
            set: { newValue in
                tappedCoordinate = newValue
                if let coord = newValue {
                    refreshData(for: coord)
                }
            }
        )
    }

    private var activeScreen: some View {
        Group {
            switch selection {
            case .map:
                ZStack(alignment: .top) {
                    if AppConfig.hasGoogleMapsAPIKey {
                        GoogleMapViewRepresentable(
                            tappedCoordinate: tappedBinding,
                            selectedBoundary: selectedBoundary,
                            selectedScale: boundaryScale
                        )
                        .ignoresSafeArea(edges: .top)
                    } else {
                        MissingGoogleMapsKeyView()
                            .ignoresSafeArea(edges: .top)
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

                    if AppConfig.hasGoogleMapsAPIKey {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                MapCameraPresetsPanel(
                                    onFocusArea: {
                                        GoogleMapViewRepresentable.focusOnUserOrSelection(selection: tappedCoordinate)
                                    },
                                    onReset: {
                                        GoogleMapViewRepresentable.resetCamera()
                                    }
                                )
                            }
                        }
                        .padding(.trailing, 12)
                        .padding(.bottom, mapControlsBottomPadding)
                        .animation(.easeInOut(duration: 0.2), value: mapControlsBottomPadding)
                    }

                }
            case .more:
                MoreScreen()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content behind the sheet
            activeScreen

            // Bottom sheet is only visible while exploring the map.
            if selection == .map {
                BottomSheet(sheetOffset: $sheetOffset) {
                    InsightsSheetContent(
                        zipCode: selectedZipCode,
                        metrics: censusMetrics,
                        demographics: selectedDemographics,
                        zipBundle: selectedZipBundle,
                        metricsSource: metricsSource,
                        boundaryScale: $boundaryScale,
                        sheetOffset: $sheetOffset
                    )
                }
                .tint(boundaryThemeTint)
                .animation(.easeInOut(duration: 0.25), value: boundaryScale)
                .accessibilitySortPriority(1)
                .zIndex(1)
            }

            // Bottom ribbon at the very front
            VStack(spacing: 0) {
                BottomRibbon(selection: $selection)
            }
            .zIndex(2)
            .padding(.bottom, 0)
            .allowsHitTesting(true)
        }
        .onChange(of: boundaryScale) { _, newScale in
            let requestID = activeSelectionRequestID
            activeScaleTask?.cancel()
            activeScaleTask = Task {
                await updateBoundaryAndDataForScale(newScale, requestID: requestID)
            }
        }
        .onAppear {
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
                    self.mapNotice = "No ZIP code is available for this location. Try a nearby area on land."
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

                Text("Google Maps Key Required")
                    .font(.title3.weight(.semibold))

                Text("Add GOOGLE_MAPS_API_KEY in Config/GoogleMaps.xcconfig or your scheme environment variables.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
        }
    }
}

private struct BoundaryLoadingBadge: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
            Text("Loading boundary...")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.78), in: Capsule())
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
                Text("Location unavailable")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.95))
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

private struct MapCameraPresetsPanel: View {
    let onFocusArea: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            iconButton(systemImage: "location.fill", accessibilityLabel: "My Area", action: onFocusArea)
            iconButton(systemImage: "scope", accessibilityLabel: "Reset Map", action: onReset)
        }
    }

    private func iconButton(systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        .accessibilityLabel(accessibilityLabel)
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
