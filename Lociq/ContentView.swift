//
//  ContentView.swift
//  Lociq
//
//  Composes the root minimal city profile interface and routes its single action.
//

import CoreLocation
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var locationProfile: LocationProfileViewModel
    @State private var isShowingDetails = false
    @State private var isLoadingContent = false
    @State private var hasRevealedBoundary = false
    @State private var hasRevealedContent = false
    @State private var revealTask: Task<Void, Never>?

    /// Creates the root view with an optional launch-argument debug coordinate.
    init() {
        _locationProfile = StateObject(
            wrappedValue: LocationProfileViewModel(debugCoordinate: DebugLocationOverride.current?.coordinate)
        )
    }

    private var activeCoordinate: CLLocationCoordinate2D? {
        locationProfile.coordinate
    }

    private var displaySnapshot: DemographicSnapshot {
        locationProfile.snapshot
    }

    private var isWaitingForInitialData: Bool {
        locationProfile.isWaitingForInitialData
    }

    private var shouldShowBoundary: Bool {
        !isWaitingForInitialData && hasRevealedBoundary
    }

    private var shouldShowLoadedContent: Bool {
        !isWaitingForInitialData && hasRevealedContent
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = MinimalLayout(geometry: geometry)

            ZStack(alignment: .topTrailing) {
                MinimalBackground()
                boundaryLayer(layout: layout)
                contentLayer(layout: layout)
                bottomIdentity(layout: layout)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlayPreferenceValue(BoundaryCityConnectionPreferenceKey.self) { anchors in
                boundaryConnector(anchors: anchors)
            }
        }
        .background(Color.lociqInk)
        .preferredColorScheme(.dark)
        .onAppear {
            locationProfile.activate()
            handleInitialDataWaitingChange(isWaitingForInitialData)
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            locationProfile.activate()
        }
        .onChange(of: isWaitingForInitialData) { waiting in
            handleInitialDataWaitingChange(waiting)
        }
    }

    @ViewBuilder
    private func boundaryLayer(layout: MinimalLayout) -> some View {
        if shouldShowBoundary, locationProfile.canShowBoundary, let boundary = locationProfile.boundary {
            CityBoundaryPreview(
                boundary: boundary,
                coordinate: activeCoordinate,
                horizontalAccuracy: locationProfile.horizontalAccuracy,
                traceToken: locationProfile.traceToken,
                reduceMotion: reduceMotion
            )
            .frame(width: layout.boundarySize.width, height: layout.boundarySize.height)
            .padding(.top, layout.boundaryTop)
            .padding(.leading, layout.boundaryLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityLabel("City boundary")
        }
    }

    @ViewBuilder
    private func contentLayer(layout: MinimalLayout) -> some View {
        if shouldShowLoadedContent {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .trailing, spacing: 34) {
                    HeaderBlock(snapshot: displaySnapshot, layout: layout)

                    if displaySnapshot.hasDemographicData {
                        FadingContentPanel(
                            snapshot: displaySnapshot,
                            isShowingDetails: isShowingDetails,
                            layout: layout,
                            reduceMotion: reduceMotion
                        )
                        .frame(
                            maxWidth: isShowingDetails ? layout.detailContentWidth : .infinity,
                            alignment: .trailing
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(
                maxWidth: layout.contentWidth,
                maxHeight: layout.detailHeight,
                alignment: .topTrailing
            )
            .padding(.top, layout.topInset)
            .padding(.trailing, layout.trailingInset)
        }
    }

    private func bottomIdentity(layout: MinimalLayout) -> some View {
        BottomIdentity(
            snapshot: displaySnapshot,
            isShowingDetails: isShowingDetails,
            isLoading: isLoadingContent || locationProfile.isLoading,
            isWaitingForInitialData: isWaitingForInitialData,
            canRetry: locationProfile.canRetry,
            needsLocationPermission: locationProfile.needsLocationPermissionPrompt,
            canRefresh: locationProfile.canRefreshCurrentCity,
            shareText: locationProfile.shareText,
            layout: layout,
            reduceMotion: reduceMotion
        ) {
            handleBottomAction()
        } onRefresh: {
            Haptics.selectionChanged()
            locationProfile.refreshCurrentCity()
        }
        .padding(.horizontal, layout.horizontalInset)
        .padding(.bottom, layout.bottomInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    /// Sequences the first loaded frame so geography appears before the demographic text.
    private func handleInitialDataWaitingChange(_ waiting: Bool) {
        revealTask?.cancel()

        if waiting {
            hasRevealedBoundary = false
            hasRevealedContent = false
            return
        }

        revealTask = Task { @MainActor in
            let delay = LociqMotion.firstDataRevealDelay(reduceMotion: reduceMotion)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(LociqMotion.firstDataReveal(reduceMotion: reduceMotion)) {
                hasRevealedBoundary = true
            }

            guard locationProfile.canShowBoundary else {
                withAnimation(LociqMotion.firstDataReveal(reduceMotion: reduceMotion)) {
                    hasRevealedContent = true
                }
                return
            }

            let contentDelay = LociqMotion.contentRevealAfterBoundaryDelay(reduceMotion: reduceMotion)
            try? await Task.sleep(nanoseconds: UInt64(contentDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(LociqMotion.firstDataReveal(reduceMotion: reduceMotion)) {
                hasRevealedContent = true
            }
        }
    }

    private func boundaryConnector(anchors: BoundaryCityConnectionAnchors) -> some View {
        GeometryReader { proxy in
            if let boundaryAnchor = anchors.boundary, let cityAnchor = anchors.city {
                let boundaryRect = proxy[boundaryAnchor]
                let cityRect = proxy[cityAnchor]
                let boundaryPathCenter = anchors.boundaryCenter
                    ?? CGPoint(x: boundaryRect.width / 2, y: boundaryRect.height / 2)
                BoundaryCityConnectorLine(
                    start: CGPoint(
                        x: boundaryRect.minX + boundaryPathCenter.x,
                        y: boundaryRect.minY + boundaryPathCenter.y
                    ),
                    end: cityConnectorEnd(for: cityRect),
                    traceToken: locationProfile.traceToken,
                    reduceMotion: reduceMotion
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Places the connector near the city label baseline without touching the text.
    private func cityConnectorEnd(for cityRect: CGRect) -> CGPoint {
        CGPoint(
            x: cityRect.minX - 11,
            y: cityRect.maxY - max(5, cityRect.height * 0.22)
        )
    }

    /// Runs the minimal fade transition between summary metrics and the detail view.
    private func cycleContent() {
        guard !isLoadingContent else { return }
        guard displaySnapshot.hasDemographicData else { return }

        Haptics.selectionChanged()

        withAnimation(LociqMotion.quick(reduceMotion: reduceMotion)) {
            isLoadingContent = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + LociqMotion.phaseDelay(reduceMotion: reduceMotion)) {
            withAnimation(LociqMotion.content(reduceMotion: reduceMotion)) {
                isShowingDetails.toggle()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + LociqMotion.contentCycleDuration(reduceMotion: reduceMotion)) {
            withAnimation(LociqMotion.settle(reduceMotion: reduceMotion)) {
                isLoadingContent = false
            }
        }
    }

    /// Routes the single bottom action to data cycling, location permission, or retry.
    private func handleBottomAction() {
        if displaySnapshot.hasDemographicData {
            cycleContent()
        } else if locationProfile.needsLocationPermissionPrompt {
            locationProfile.requestLocationAccess()
        } else if locationProfile.canRetry {
            Haptics.selectionChanged()
            locationProfile.retry()
        }
    }
}

#Preview {
    ContentView()
}
