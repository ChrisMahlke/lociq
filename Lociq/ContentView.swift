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
/// iPhone, and narrow iPad windows, use the original phone composition. On
/// larger iPad windows `MinimalLayout` grows the same composition to the
/// canvas, and wide windows show the details beside the summary. It stays one
/// quiet, editorial screen on every device, never a dashboard or a map.
struct ContentView: View {
    /// Scene phase used to resume location refreshes when the app becomes active.
    @Environment(\.scenePhase) private var scenePhase

    /// Accessibility reduced-motion setting used by all motion helpers.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The user's text size, which scales type and switches to one column.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Persisted appearance. The app defaults to its original dark appearance.
    @AppStorage("lociq.themePreference") private var themePreferenceRawValue = LociqThemePreference.dark.rawValue

    /// Set once the details have been opened, which retires the "DATA" hint.
    @AppStorage("lociq.hasDiscoveredDataView") private var hasDiscoveredDataView = false

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

    /// Composes the background, content, and bottom identity for the window.
    var body: some View {
        GeometryReader { geometry in
            let layout = MinimalLayout(
                viewportSize: geometry.size,
                safeAreaInsets: geometry.safeAreaInsets,
                dynamicTypeSize: dynamicTypeSize
            )

            ZStack {
                // The ink fills the whole screen, including the safe areas.
                Color.lociqInk
                    .ignoresSafeArea()

                ZStack(alignment: .topLeading) {
                    MinimalBackground(
                        ignoresSafeArea: false,
                        isSparse: !viewState.snapshot.hasDemographicData,
                        scale: layout.backgroundScale
                    )

                    // The bottom bar sits below the content, not over it, so
                    // content always ends above the controls at any text size.
                    VStack(spacing: 0) {
                        mainArea(layout: layout, canvasSize: geometry.size)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        bottomIdentity(layout: layout)
                            .padding(.horizontal, layout.horizontalInset)
                            .padding(.top, layout.space(12))
                            .padding(.bottom, layout.bottomInset)
                    }
                }
                .animation(LociqMotion.quick(reduceMotion: reduceMotion), value: viewState.isWaitingForInitialData)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlayPreferenceValue(BoundaryCityConnectionPreferenceKey.self) { anchors in
                // The connector needs anchors from two separate child views:
                // the boundary glyph and the city label.
                boundaryConnector(anchors: anchors, layout: layout)
            }
            .focusedSceneValue(\.lociqCommandActions, commandActions(layout: layout))
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
    ///
    /// On large canvases the glyph's frame hugs the outline, so the density
    /// label sits right under it instead of under the empty part of a frame
    /// sized for any shape.
    private func boundaryStack(glyph: BoundaryGlyph, layout: MinimalLayout) -> some View {
        let glyphSize = layout.canvas == .phone ? layout.boundarySize : glyph.fittedSize(within: layout.boundarySize)
        return VStack(alignment: .center, spacing: layout.space(8)) {
            CityBoundaryPreview(
                glyph: glyph,
                coordinate: viewState.coordinate,
                horizontalAccuracy: viewState.horizontalAccuracy,
                isApproximate: viewState.isApproximate,
                densityPerSquareMile: viewState.snapshot.densityPerSquareMile,
                traceToken: locationProfile.traceToken,
                reduceMotion: reduceMotion,
                graphicScale: layout.graphicScale,
                markerFrameSize: layout.canvas == .phone ? nil : layout.boundarySize
            )
            .frame(width: glyphSize.width, height: glyphSize.height)

            if let density = viewState.snapshot.densityPerSquareMile {
                VStack(spacing: layout.space(2)) {
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
        // Keeps the hugging frame centered in the geography column.
        .frame(width: layout.canvas != .phone && !layout.usesSingleColumn ? layout.boundarySize.width : nil)
    }

    /// True when the details are shown beside the summary, on a wide iPad window.
    private func showsDetailsBeside(_ layout: MinimalLayout) -> Bool {
        layout.showsDetailsBeside && displaySnapshot.hasDemographicData
    }

    /// Renders the right-aligned city header and demographic content area.
    ///
    /// The scroll area ends above the bottom bar. When content is taller than
    /// the area, a short fade and the scroll indicator show that more follows.
    /// On a spread, the details sit in a quieter column right of the city and
    /// its summary, from the top, so they fit the window whole and the
    /// connector never crosses them.
    private func contentScroll(layout: MinimalLayout) -> some View {
        let isSpread = showsDetailsBeside(layout)
        let columnWidth: CGFloat = layout.usesSingleColumn
            ? .infinity
            : (isSpread ? layout.contentWidth + layout.columnGap + layout.detailSidebarWidth : layout.contentWidth)

        return ScrollView(.vertical, showsIndicators: isContentOverflowing) {
            VStack(alignment: .trailing, spacing: layout.space(34)) {
                if shouldShowLoadedContent {
                    if isSpread {
                        spread(layout: layout)
                    } else {
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
                                .accessibilitySortPriority(3)
                        }

                        if displaySnapshot.hasDemographicData {
                            summaryPanel(layout: layout, showsDetails: isShowingDetails)
                                .frame(
                                    maxWidth: isShowingDetails ? layout.detailContentWidth : .infinity,
                                    alignment: .trailing
                                )
                                .accessibilitySortPriority(2)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.bottom, layout.space(24))
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
                    .frame(height: layout.space(24))
            }
        }
        .frame(
            maxWidth: columnWidth,
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

    /// A wide iPad window: the city and its summary, with the details beside them.
    ///
    /// VoiceOver reads the city and summary first, then the details.
    private func spread(layout: MinimalLayout) -> some View {
        HStack(alignment: .top, spacing: layout.columnGap) {
            VStack(alignment: .trailing, spacing: layout.space(34)) {
                HeaderBlock(snapshot: displaySnapshot, layout: layout, titleFocus: $isTitleFocused)
                    .accessibilitySortPriority(1)
                summaryPanel(layout: layout, showsDetails: false)
            }
            .frame(width: layout.contentWidth, alignment: .trailing)
            .accessibilityElement(children: .contain)
            .accessibilitySortPriority(2)

            DetailContent(
                snapshot: displaySnapshot,
                layout: layout,
                themePreference: themePreference,
                onSelectTheme: selectTheme,
                isSecondary: true
            )
            .frame(width: layout.detailSidebarWidth)
            .opacity(viewState.isContentDimmed ? 0.45 : 1)
            .animation(LociqMotion.quick(reduceMotion: reduceMotion), value: viewState.isContentDimmed)
            .accessibilityElement(children: .contain)
            .accessibilitySortPriority(1)
        }
        .transition(.opacity)
    }

    /// The summary metrics, or the details when toggled, dimmed while a new place loads.
    private func summaryPanel(layout: MinimalLayout, showsDetails: Bool) -> some View {
        FadingContentPanel(
            snapshot: displaySnapshot,
            isShowingDetails: showsDetails,
            layout: layout,
            reduceMotion: reduceMotion,
            themePreference: themePreference,
            onSelectTheme: selectTheme
        )
        .opacity(viewState.isContentDimmed ? 0.45 : 1)
        .animation(LociqMotion.quick(reduceMotion: reduceMotion), value: viewState.isContentDimmed)
    }

    /// One quiet line that says what the app shows, before location is shared.
    private func firstRunDescriptor(layout: MinimalLayout) -> some View {
        VStack(alignment: .trailing, spacing: layout.space(6)) {
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
            showsDetailsToggle: !showsDetailsBeside(layout),
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
                    reduceMotion: reduceMotion,
                    lineScale: layout.graphicScale
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
            [SpokenText.title(snapshot.market), SpokenText.title(snapshot.statusLine)]
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

    /// Refreshes from the refresh button, the menus, or pull-to-refresh.
    ///
    /// Pull-to-refresh awaits this, which keeps the system control active until done.
    private func refresh(trigger: LocationProfileViewModel.RefreshTrigger) async {
        Haptics.selectionChanged()
        await locationProfile.refresh(trigger: trigger)
    }

    /// Shows the details or the summary, from the menu bar or keyboard.
    private func showDetails(_ show: Bool) {
        guard show != isShowingDetails else { return }
        if show { hasDiscoveredDataView = true }
        cycleContent()
    }

    /// What the menu bar and keyboard shortcuts can do right now.
    ///
    /// The Refresh command takes the pull-to-refresh route, which never
    /// leaves the app: a command named Refresh should not open Settings.
    private func commandActions(layout: MinimalLayout) -> LociqCommandActions {
        let hasProfile = viewState.snapshot.hasDemographicData
        let canRefresh = !viewState.isBusy && (hasProfile
            ? viewState.refreshControl == .refresh || viewState.refreshControl == .requestPermissionAndRefresh
            : viewState.canPullToRefresh)
        return LociqCommandActions(
            canRefresh: canRefresh,
            refresh: { Task { await refresh(trigger: .pull) } },
            canSwitchView: hasProfile && !showsDetailsBeside(layout) && !isSwappingContent,
            isShowingDetails: isShowingDetails,
            showDetails: showDetails,
            themePreference: themePreference,
            selectTheme: selectTheme
        )
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
