//
//  ContentView.swift
//  Lociq
//
//  Composes the root minimal city profile interface and routes its single action.
//
//  `ContentView` owns composition, not data loading. It observes
//  `LocationProfileViewModel`, lays out the minimal surface, sequences first
//  reveal animations, and routes the bottom action. Data state, formatting, and
//  Census service behavior live outside this view.
//

import CoreLocation
import SwiftUI

/// Root SwiftUI surface for LOC IQ.
///
/// The layout is intentionally phone-like on every supported device. On iPad,
/// `MinimalViewport` constrains the app surface so the design does not expand
/// into a dashboard or map-style interface.
struct ContentView: View {
    /// Scene phase used to resume location refreshes when the app becomes active.
    @Environment(\.scenePhase) private var scenePhase

    /// Accessibility reduced-motion setting used by all motion helpers.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Persisted explicit app theme. The app defaults to its original dark appearance.
    @AppStorage("lociq.themePreference") private var themePreferenceRawValue = LociqThemePreference.dark.rawValue

    /// Location and city profile state machine.
    @StateObject private var locationProfile: LocationProfileViewModel

    /// Whether the secondary details panel is visible.
    @State private var isShowingDetails = false

    /// Temporary loading state used while cycling home and details content.
    @State private var isLoadingContent = false

    /// Briefly confirms a completed manual refresh in the existing header status line.
    @State private var isShowingRefreshConfirmation = false

    /// Drives a one-time, very small pull hint after the first loaded content appears.
    @State private var contentPullHintOffset: CGFloat = 0

    /// Prevents the pull-to-refresh discovery hint from replaying in one app session.
    @State private var hasShownPullRefreshHint = false

    /// Whether the first loaded boundary has been revealed.
    @State private var hasRevealedBoundary = false

    /// Whether the first loaded content stack has been revealed.
    @State private var hasRevealedContent = false

    /// Task that sequences first boundary and content reveal.
    @State private var revealTask: Task<Void, Never>?

    /// Task that clears transient refresh confirmation copy.
    @State private var refreshConfirmationTask: Task<Void, Never>?

    /// Creates the root view with an optional launch-argument debug coordinate.
    init() {
        _locationProfile = StateObject(
            wrappedValue: LocationProfileViewModel(debugCoordinate: DebugLocationOverride.current?.coordinate)
        )
    }

    private var activeCoordinate: CLLocationCoordinate2D? {
        locationProfile.coordinate
    }

    /// Current user-selected theme, falling back to dark for unknown stored values.
    private var themePreference: LociqThemePreference {
        LociqThemePreference(rawValue: themePreferenceRawValue) ?? .dark
    }

    /// Snapshot currently projected by the view model.
    private var displaySnapshot: DemographicSnapshot {
        guard isShowingRefreshConfirmation, locationProfile.snapshot.hasDemographicData, !locationProfile.isLoading else {
            return locationProfile.snapshot
        }
        return locationProfile.snapshot.replacingDateLabel("UPDATED NOW")
    }

    /// True while the app should show only the initial spinner.
    private var isWaitingForInitialData: Bool {
        locationProfile.isWaitingForInitialData
    }

    /// True after initial data is ready and the boundary reveal phase has started.
    private var shouldShowBoundary: Bool {
        !isWaitingForInitialData && hasRevealedBoundary
    }

    /// True after initial data is ready and content reveal has started.
    private var shouldShowLoadedContent: Bool {
        !isWaitingForInitialData && hasRevealedContent
    }

    /// Composes the background, constrained viewport, boundary, content, and bottom identity.
    var body: some View {
        GeometryReader { geometry in
            let viewport = MinimalViewport(geometry: geometry)
            let layout = MinimalLayout(
                viewportSize: viewport.size,
                safeAreaInsets: viewport.safeAreaInsets
            )

            ZStack {
                // The outer background fills iPad and phone screens. The inner
                // surface can be constrained on iPad without exposing a blank
                // platform-default color.
                Color.lociqInk
                    .ignoresSafeArea()

                ZStack(alignment: .topTrailing) {
                    // The inner background is clipped to the constrained
                    // viewport, which preserves the phone composition on iPad.
                    MinimalBackground(ignoresSafeArea: false)
                    if isWaitingForInitialData {
                        InitialLoadingSpinner(
                            canvasSize: viewport.size,
                            reduceMotion: reduceMotion
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .transition(.opacity)
                    } else {
                        boundaryLayer(layout: layout)
                        contentLayer(layout: layout)
                        bottomIdentity(layout: layout)
                    }
                }
                .animation(LociqMotion.quick(reduceMotion: reduceMotion), value: isWaitingForInitialData)
                .frame(width: viewport.size.width, height: viewport.size.height)
                .clipped()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlayPreferenceValue(BoundaryCityConnectionPreferenceKey.self) { anchors in
                // The connector needs anchors from two separate child views:
                // the boundary glyph and the city label.
                boundaryConnector(anchors: anchors)
            }
        }
        .background(Color.lociqInk)
        .preferredColorScheme(themePreference.colorScheme)
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
        .onChange(of: shouldShowLoadedContent) { loaded in
            guard loaded else { return }
            runPullRefreshHintIfNeeded()
        }
        .onDisappear {
            revealTask?.cancel()
            refreshConfirmationTask?.cancel()
        }
    }

    /// Renders the geography layer when boundary geometry should be visible.
    ///
    /// Boundary visibility is staged after initial data arrives so the outline
    /// can trace before demographic text fades in.
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

    /// Renders the right-aligned city header and demographic content area.
    ///
    /// The scroll view is present to protect smaller devices and dynamic type
    /// cases from clipping while still appearing static in normal use.
    @ViewBuilder
    private func contentLayer(layout: MinimalLayout) -> some View {
        if shouldShowLoadedContent {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .trailing, spacing: 34) {
                    if !locationProfile.needsLocationPermissionPrompt {
                        HeaderBlock(snapshot: displaySnapshot, layout: layout)
                    }

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
            .offset(y: contentPullHintOffset)
            .refreshable {
                await refreshVisibleCity()
            }
        }
    }

    /// Renders the bottom brand/action surface.
    ///
    /// The bottom identity receives callbacks instead of owning view-model
    /// mutations, keeping action routing centralized in `ContentView`.
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
            themePreference: themePreference,
            reduceMotion: reduceMotion
        ) {
            handleBottomAction()
        } onRefresh: {
            Task {
                await refreshVisibleCity()
            }
        } onToggleTheme: {
            toggleThemePreference()
        }
        .padding(.horizontal, layout.horizontalInset)
        .padding(.bottom, layout.bottomInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    /// Sequences the first loaded frame so geography appears before the demographic text.
    ///
    /// The sequence is intentionally restrained:
    /// boundary first, then content. If no boundary is available, content
    /// appears immediately after the first reveal delay.
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

    /// Draws the connector line between the boundary projection center and city label.
    ///
    /// Anchor preferences are resolved in the root coordinate space here. The
    /// boundary view publishes the projected geometry center so the line starts
    /// from the visual center of the polygon rather than from the app center.
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
    ///
    /// The end point stops slightly before the city string, preserving legibility
    /// while still making the relationship clear.
    private func cityConnectorEnd(for cityRect: CGRect) -> CGPoint {
        CGPoint(
            x: cityRect.minX - 11,
            y: cityRect.maxY - max(5, cityRect.height * 0.22)
        )
    }

    /// Runs the minimal fade transition between summary metrics and the detail view.
    ///
    /// The bottom line enters loading state while the content swaps. This makes
    /// the mode change feel intentional without adding a navigation stack.
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

    /// Flips between the original dark appearance and the minimal light variant.
    private func toggleThemePreference() {
        Haptics.selectionChanged()
        withAnimation(LociqMotion.themeToggle(reduceMotion: reduceMotion)) {
            themePreferenceRawValue = themePreference.toggled.rawValue
        }
    }

    /// Refreshes the visible city from pull-to-refresh while keeping the native control active.
    private func refreshVisibleCity() async {
        guard locationProfile.canRefreshCurrentCity else { return }
        locationProfile.refreshCurrentCity()
        Haptics.selectionChanged()
        await locationProfile.waitForPendingLoad()
        showRefreshConfirmationIfNeeded()
    }

    /// Briefly shows a completed-refresh status without adding another visible component.
    private func showRefreshConfirmationIfNeeded() {
        guard locationProfile.snapshot.hasDemographicData, !locationProfile.isLoading else { return }
        refreshConfirmationTask?.cancel()
        withAnimation(LociqMotion.quick(reduceMotion: reduceMotion)) {
            isShowingRefreshConfirmation = true
        }
        refreshConfirmationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(LociqMotion.quick(reduceMotion: reduceMotion)) {
                isShowingRefreshConfirmation = false
            }
        }
    }

    /// Runs a restrained one-time hint that the content can be pulled down to refresh.
    private func runPullRefreshHintIfNeeded() {
        guard !hasShownPullRefreshHint else { return }
        guard displaySnapshot.hasDemographicData, locationProfile.canRefreshCurrentCity else { return }
        hasShownPullRefreshHint = true
        guard !reduceMotion else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(LociqMotion.pullHint) {
                contentPullHintOffset = 5
            }
            try? await Task.sleep(nanoseconds: 280_000_000)
            withAnimation(LociqMotion.pullHint) {
                contentPullHintOffset = 0
            }
        }
    }

    /// Routes the single bottom action to data cycling, location permission, or retry.
    ///
    /// The visible icon is decided by `BottomIdentity`, but this method owns the
    /// actual action order: data toggle, location request, then retry.
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
