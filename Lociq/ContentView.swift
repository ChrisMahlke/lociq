//
//  ContentView.swift
//  Lociq
//
//  Composes the root minimal city profile interface and routes its actions.
//
//  `ContentView` owns composition, not data loading. It observes
//  `LocationProfileViewModel`, lays out the minimal surface, sequences first
//  reveal timing, and routes the bottom actions. Data state, formatting, and
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

    /// The user's text size, which scales type and switches to one column.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Persisted appearance. The app defaults to its original dark appearance.
    @AppStorage("lociq.themePreference") private var themePreferenceRawValue = LociqThemePreference.dark.rawValue

    /// Location and city profile state machine.
    @StateObject private var locationProfile: LocationProfileViewModel

    /// VoiceOver focus on the city title after the first reveal.
    @AccessibilityFocusState private var isTitleFocused: Bool

    /// Whether the secondary details panel is visible.
    @State private var isShowingDetails = false

    /// True while the summary/details swap animates.
    @State private var isSwappingContent = false

    /// Briefly confirms a completed refresh in the header status line.
    @State private var refreshStatusOverride: String?

    /// Drives a one-time, very small pull hint after the first loaded content appears.
    @State private var contentPullHintOffset: CGFloat = 0

    /// Prevents the pull-to-refresh discovery hint from replaying in one app session.
    @State private var hasShownPullRefreshHint = false

    /// Whether the first loaded frame has been revealed.
    @State private var hasRevealedContent = false

    /// Prevents moving VoiceOver focus more than once per session.
    @State private var hasMovedFocusToTitle = false

    /// True when the content is taller than its scroll area.
    @State private var isContentOverflowing = false

    /// Measured height of the scroll content.
    @State private var contentHeight: CGFloat = 0

    /// Measured height of the scroll area.
    @State private var scrollAreaHeight: CGFloat = 0

    /// Task that sequences the first loaded frame reveal.
    @State private var revealTask: Task<Void, Never>?

    /// Task that clears transient refresh confirmation copy.
    @State private var refreshConfirmationTask: Task<Void, Never>?

    /// Creates the root view with the launch configuration's view model.
    init() {
        _locationProfile = StateObject(wrappedValue: LocationProfileViewModel.makeForLaunch())
        #if DEBUG
        _isShowingDetails = State(initialValue: LociqLaunchFixture.showsDetailsOnLaunch)
        #endif
    }

    /// Current appearance, falling back to dark for unknown stored values.
    private var themePreference: LociqThemePreference {
        LociqThemePreference(rawValue: themePreferenceRawValue) ?? .dark
    }

    /// View-facing state projected by the view model.
    private var viewState: LocationProfileViewState {
        locationProfile.viewState
    }

    /// Snapshot shown, with a brief refresh confirmation when one is active.
    private var displaySnapshot: DemographicSnapshot {
        guard let refreshStatusOverride, viewState.snapshot.hasDemographicData, !viewState.isBusy else {
            return viewState.snapshot
        }
        return viewState.snapshot.withStatus(refreshStatusOverride)
    }

    /// True after initial data is ready and the loaded frame reveal has started.
    private var shouldShowLoadedContent: Bool {
        !viewState.isWaitingForInitialData && hasRevealedContent
    }

    /// Composes the background, constrained viewport, content, and bottom identity.
    var body: some View {
        GeometryReader { geometry in
            let viewport = MinimalViewport(geometry: geometry)
            let layout = MinimalLayout(
                viewportSize: viewport.size,
                safeAreaInsets: viewport.safeAreaInsets,
                dynamicTypeSize: dynamicTypeSize
            )

            ZStack {
                // The outer background fills iPad and phone screens. The inner
                // surface can be constrained on iPad without exposing a blank
                // platform-default color.
                Color.lociqInk
                    .ignoresSafeArea()

                ZStack(alignment: .topLeading) {
                    MinimalBackground(ignoresSafeArea: false, isSparse: !viewState.snapshot.hasDemographicData)

                    // The bottom bar sits below the content, not over it, so
                    // content always ends above the controls at any text size.
                    VStack(spacing: 0) {
                        mainArea(layout: layout, canvasSize: viewport.size)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        bottomIdentity(layout: layout)
                            .padding(.horizontal, layout.horizontalInset)
                            .padding(.top, 12)
                            .padding(.bottom, layout.bottomInset)
                    }
                }
                .animation(LociqMotion.quick(reduceMotion: reduceMotion), value: viewState.isWaitingForInitialData)
                .frame(width: viewport.size.width, height: viewport.size.height)
                .clipped()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlayPreferenceValue(BoundaryCityConnectionPreferenceKey.self) { anchors in
                // The connector needs anchors from two separate child views:
                // the boundary glyph and the city label.
                boundaryConnector(anchors: anchors, layout: layout)
            }
        }
        .background(Color.lociqInk)
        .preferredColorScheme(themePreference.colorScheme)
        .onAppear {
            LociqAppearance.apply(themePreference, animated: false, reduceMotion: reduceMotion)
            locationProfile.activate()
            handleInitialDataWaitingChange(viewState.isWaitingForInitialData)
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            locationProfile.activate()
        }
        .onChange(of: viewState.isWaitingForInitialData) { waiting in
            handleInitialDataWaitingChange(waiting)
        }
        .onChange(of: shouldShowLoadedContent) { loaded in
            guard loaded else { return }
            runPullRefreshHintIfNeeded()
            moveFocusToTitleIfNeeded()
        }
        .onChange(of: locationProfile.refreshEvent) { event in
            guard let event else { return }
            showRefreshConfirmation(for: event.outcome)
        }
        .onChange(of: announcementKey) { _ in
            announceUnavailableStateIfNeeded()
        }
        .onChange(of: viewState.snapshot.hasDemographicData) { hasData in
            // A failure or permission state has no details view to return to.
            if !hasData { isShowingDetails = false }
        }
        .onDisappear {
            revealTask?.cancel()
            refreshConfirmationTask?.cancel()
        }
    }

    // MARK: - Layout

    /// Renders the spinner and stage line while waiting, otherwise the content.
    @ViewBuilder
    private func mainArea(layout: MinimalLayout, canvasSize: CGSize) -> some View {
        if let stage = viewState.waitStage {
            InitialLoadingSpinner(
                canvasSize: canvasSize,
                stage: stage,
                layout: layout,
                reduceMotion: reduceMotion
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .transition(.opacity)
        } else {
            ZStack(alignment: .topLeading) {
                if !layout.usesSingleColumn {
                    boundaryColumn(layout: layout)
                }
                contentScroll(layout: layout)
            }
        }
    }

    /// Renders the geography column in the two-column layout.
    ///
    /// Boundary visibility is tied to the loaded-content reveal so the outline
    /// does not draw, disappear, and restart as the city text arrives.
    @ViewBuilder
    private func boundaryColumn(layout: MinimalLayout) -> some View {
        if shouldShowLoadedContent, viewState.canShowBoundary, let glyph = locationProfile.boundaryGlyph {
            boundaryStack(glyph: glyph, layout: layout)
                .padding(.top, layout.boundaryTop)
                .padding(.leading, layout.boundaryLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .opacity(viewState.isContentDimmed ? 0.45 : 1)
                .animation(LociqMotion.quick(reduceMotion: reduceMotion), value: viewState.isContentDimmed)
        }
    }

    /// The boundary glyph with its optional density label.
    private func boundaryStack(glyph: BoundaryGlyph, layout: MinimalLayout) -> some View {
        VStack(alignment: .center, spacing: 8) {
            CityBoundaryPreview(
                glyph: glyph,
                coordinate: viewState.coordinate,
                horizontalAccuracy: viewState.horizontalAccuracy,
                isApproximate: viewState.isApproximate,
                densityPerSquareMile: viewState.snapshot.densityPerSquareMile,
                traceToken: locationProfile.traceToken,
                reduceMotion: reduceMotion
            )
            .frame(width: layout.boundarySize.width, height: layout.boundarySize.height)

            if let density = viewState.snapshot.densityPerSquareMile {
                VStack(spacing: 2) {
                    Text("DENSITY")
                        .foregroundStyle(Color.lociq(.secondary))
                    Text(CityDensityCalculator.formatted(density))
                        .foregroundStyle(Color.lociq(.densityValue))
                        .monospacedDigit()
                }
                .font(LociqTypeScale.densityLabel(layout))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Population density")
                .accessibilityValue(CityDensityCalculator.spoken(density))
                .accessibilityIdentifier("boundary.density")
            }
        }
    }

    /// Renders the right-aligned city header and demographic content area.
    ///
    /// The scroll area ends above the bottom bar. When content is taller than
    /// the area, a short fade and the scroll indicator show that more follows.
    private func contentScroll(layout: MinimalLayout) -> some View {
        ScrollView(.vertical, showsIndicators: isContentOverflowing) {
            VStack(alignment: .trailing, spacing: 34) {
                if shouldShowLoadedContent {
                    if layout.usesSingleColumn, viewState.canShowBoundary, let glyph = locationProfile.boundaryGlyph {
                        boundaryStack(glyph: glyph, layout: layout)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .opacity(viewState.isContentDimmed ? 0.45 : 1)
                            .accessibilitySortPriority(0)
                    }

                    if viewState.needsLocationPermissionPrompt {
                        firstRunDescriptor(layout: layout)
                    } else {
                        HeaderBlock(snapshot: displaySnapshot, layout: layout, titleFocus: $isTitleFocused)
                            .accessibilitySortPriority(2)
                    }

                    if displaySnapshot.hasDemographicData {
                        FadingContentPanel(
                            snapshot: displaySnapshot,
                            isShowingDetails: isShowingDetails,
                            layout: layout,
                            reduceMotion: reduceMotion,
                            themePreference: themePreference,
                            onSelectTheme: selectTheme
                        )
                        .frame(
                            maxWidth: isShowingDetails ? layout.detailContentWidth : .infinity,
                            alignment: .trailing
                        )
                        .opacity(viewState.isContentDimmed ? 0.45 : 1)
                        .animation(LociqMotion.quick(reduceMotion: reduceMotion), value: viewState.isContentDimmed)
                        .accessibilitySortPriority(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.bottom, 24)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ContentHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
            .accessibilityElement(children: .contain)
            // Stable identity prevents refresh-only snapshot updates from
            // resetting the user's vertical reading position.
            .id("profile-scroll-content")
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: ScrollAreaHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
            contentHeight = height
            updateOverflow()
        }
        .onPreferenceChange(ScrollAreaHeightPreferenceKey.self) { height in
            scrollAreaHeight = height
            updateOverflow()
        }
        .mask {
            VStack(spacing: 0) {
                Rectangle()
                LinearGradient(colors: [.black, .black.opacity(isContentOverflowing ? 0 : 1)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 24)
            }
        }
        .frame(
            maxWidth: layout.usesSingleColumn ? .infinity : layout.contentWidth,
            maxHeight: .infinity,
            alignment: .topTrailing
        )
        .padding(.top, layout.topInset)
        .padding(.trailing, layout.trailingInset)
        .padding(.leading, layout.usesSingleColumn ? layout.horizontalInset : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .offset(y: contentPullHintOffset)
        .modifier(PullToRefresh(isEnabled: viewState.canPullToRefresh) {
            await refresh(trigger: .pull)
        })
    }

    /// One quiet line that says what the app shows, before location is shared.
    private func firstRunDescriptor(layout: MinimalLayout) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("CITY DEMOGRAPHICS")
                .font(LociqTypeScale.metricLabel(layout))
                .foregroundStyle(Color.lociq(.metricLabel))
            Text("FOR WHERE YOU ARE, FROM THE U.S. CENSUS BUREAU")
                .font(LociqTypeScale.statusLabel(layout))
                .foregroundStyle(Color.lociq(.status))
        }
        .multilineTextAlignment(.trailing)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("firstRun.descriptor")
    }

    /// Renders the bottom brand/action surface.
    ///
    /// The bottom identity receives callbacks instead of owning view-model
    /// mutations, keeping action routing centralized in `ContentView`.
    private func bottomIdentity(layout: MinimalLayout) -> some View {
        BottomIdentity(
            snapshot: displaySnapshot,
            isShowingDetails: isShowingDetails,
            isBusy: viewState.isBusy || isSwappingContent,
            isInteractionLocked: isSwappingContent,
            isWaitingForInitialData: viewState.isWaitingForInitialData,
            primaryAction: viewState.primaryAction,
            refreshControl: viewState.refreshControl,
            shareText: viewState.shareText,
            layout: layout,
            themePreference: themePreference,
            reduceMotion: reduceMotion
        ) {
            handlePrimaryAction()
        } onRefresh: {
            Task { await refresh(trigger: .button) }
        } onSelectTheme: { preference in
            selectTheme(preference)
        }
    }

    /// Draws the connector line between the glyph's interior point and the city label.
    ///
    /// Anchor preferences are resolved in the root coordinate space here. The
    /// boundary view publishes an interior point of the fitted part so the line
    /// starts inside the city rather than from empty space between parts.
    private func boundaryConnector(anchors: BoundaryCityConnectionAnchors, layout: MinimalLayout) -> some View {
        GeometryReader { proxy in
            if !layout.usesSingleColumn,
               proxy.size.width >= 350,
               let boundaryAnchor = anchors.boundary,
               let cityAnchor = anchors.city {
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
                .opacity(viewState.isContentDimmed ? 0.45 : 1)
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

    // MARK: - Sequencing

    /// Reveals the first loaded frame once initial data is ready.
    ///
    /// Boundary and content enter together to avoid a partial geography trace
    /// being replaced by the fully composed city profile frame.
    private func handleInitialDataWaitingChange(_ waiting: Bool) {
        revealTask?.cancel()

        if waiting {
            hasRevealedContent = false
            return
        }

        revealTask = Task { @MainActor in
            let delay = LociqMotion.firstDataRevealDelay(reduceMotion: reduceMotion)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(LociqMotion.firstDataReveal(reduceMotion: reduceMotion)) {
                hasRevealedContent = true
            }
        }
    }

    /// Moves VoiceOver focus to the city title after the first reveal.
    private func moveFocusToTitleIfNeeded() {
        guard !hasMovedFocusToTitle, !viewState.needsLocationPermissionPrompt else { return }
        hasMovedFocusToTitle = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            isTitleFocused = true
        }
    }

    /// Identity of the visible failure or permission state, for announcements.
    private var announcementKey: String {
        guard !viewState.snapshot.hasDemographicData, !viewState.isWaitingForInitialData else { return "" }
        return "\(viewState.snapshot.market)|\(viewState.snapshot.statusLine)"
    }

    /// Speaks a failure or location state that replaced the screen.
    private func announceUnavailableStateIfNeeded() {
        guard !announcementKey.isEmpty, hasMovedFocusToTitle || shouldShowLoadedContent else { return }
        let snapshot = viewState.snapshot
        AccessibilityAnnouncer.announce(
            [snapshot.market.capitalized, snapshot.statusLine.capitalized]
                .filter { !$0.isEmpty }
                .joined(separator: ". ")
        )
    }

    // MARK: - Actions

    /// Routes the primary bottom action.
    private func handlePrimaryAction() {
        switch viewState.primaryAction {
        case .toggleDetails:
            cycleContent()
        case .requestPermission:
            Haptics.selectionChanged()
            locationProfile.requestLocationAccess()
        case .openSettings:
            locationProfile.openLocationSettings()
        case .retry:
            Haptics.selectionChanged()
            locationProfile.retry()
        case .none:
            break
        }
    }

    /// Runs the minimal fade transition between summary metrics and the detail view.
    ///
    /// The bottom line sweeps while the content swaps. This makes the mode
    /// change feel intentional without adding a navigation stack.
    private func cycleContent() {
        guard !isSwappingContent, displaySnapshot.hasDemographicData else { return }

        Haptics.selectionChanged()

        withAnimation(LociqMotion.quick(reduceMotion: reduceMotion)) {
            isSwappingContent = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(LociqMotion.phaseDelay(reduceMotion: reduceMotion) * 1_000_000_000))
            withAnimation(LociqMotion.content(reduceMotion: reduceMotion)) {
                isShowingDetails.toggle()
            }
            AccessibilityAnnouncer.announce(isShowingDetails ? "Showing details" : "Showing summary")
            try? await Task.sleep(nanoseconds: UInt64(
                (LociqMotion.contentCycleDuration(reduceMotion: reduceMotion) - LociqMotion.phaseDelay(reduceMotion: reduceMotion)) * 1_000_000_000
            ))
            withAnimation(LociqMotion.settle(reduceMotion: reduceMotion)) {
                isSwappingContent = false
            }
        }
    }

    /// Stores and applies an appearance choice.
    private func selectTheme(_ preference: LociqThemePreference) {
        guard preference != themePreference else { return }
        Haptics.selectionChanged()
        themePreferenceRawValue = preference.rawValue
        LociqAppearance.apply(preference, animated: true, reduceMotion: reduceMotion)
    }

    /// Refreshes from the refresh button, the menu, or pull-to-refresh.
    ///
    /// Pull-to-refresh awaits this, which keeps the system control active until done.
    private func refresh(trigger: LocationProfileViewModel.RefreshTrigger) async {
        Haptics.selectionChanged()
        await locationProfile.refresh(trigger: trigger)
    }

    /// Briefly confirms a refresh result in the status line and for VoiceOver.
    private func showRefreshConfirmation(for outcome: LocationProfileViewModel.RefreshOutcome) {
        refreshConfirmationTask?.cancel()
        let status: String
        let spoken: String
        switch outcome {
        case .updated:
            status = "UPDATED NOW"
            spoken = "Updated"
            Haptics.softImpact()
        case .failed:
            status = "UNABLE TO REFRESH · SAVED DATA"
            spoken = "Couldn't refresh. Showing saved data."
        case .unableToLocate:
            status = "CAN'T FIND YOUR LOCATION"
            spoken = "Couldn't find your location. Showing your last known area."
        }
        AccessibilityAnnouncer.announce(spoken)
        guard viewState.snapshot.hasDemographicData else { return }
        withAnimation(LociqMotion.quick(reduceMotion: reduceMotion)) {
            refreshStatusOverride = status
        }
        refreshConfirmationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(LociqMotion.quick(reduceMotion: reduceMotion)) {
                refreshStatusOverride = nil
            }
        }
    }

    /// Runs a restrained one-time hint that the content can be pulled down to refresh.
    private func runPullRefreshHintIfNeeded() {
        guard !hasShownPullRefreshHint else { return }
        guard displaySnapshot.hasDemographicData, viewState.canPullToRefresh else { return }
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

    /// Recomputes whether content overflows its scroll area.
    private func updateOverflow() {
        let overflowing = contentHeight > scrollAreaHeight + 1
        if overflowing != isContentOverflowing {
            isContentOverflowing = overflowing
        }
    }
}

/// Attaches pull-to-refresh only when pulling can do something useful.
///
/// Without it, pulling in a permission or permanent-failure state would show
/// the system spinner and then nothing.
private struct PullToRefresh: ViewModifier {
    let isEnabled: Bool
    let action: @Sendable () async -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.refreshable {
                await action()
            }
        } else {
            content
        }
    }
}

/// Height of the scroll content, used to detect overflow.
private struct ContentHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Height of the scroll area, used to detect overflow.
private struct ScrollAreaHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    ContentView()
}
