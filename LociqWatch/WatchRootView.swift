//
//  WatchRootView.swift
//  LociqWatch
//
//  Routes the watch app between its waiting, message, and profile screens.
//
//  The watch drives the same `LocationProfileViewModel` as the iPhone app, so
//  permission, freshness, failures, and refresh behave the same way. This view
//  owns composition, the brief refresh confirmation, and the record the
//  complications show.
//

import SwiftUI
import WidgetKit

/// Root view of the watch app.
struct WatchRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Location and city profile state machine, shared with the iPhone app.
    @StateObject private var locationProfile = LocationProfileViewModel.makeForLaunch()

    /// Briefly confirms a completed refresh in the status line.
    @State private var refreshStatusOverride: String?

    /// Task that clears the refresh confirmation.
    @State private var refreshConfirmationTask: Task<Void, Never>?

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

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("LOC IQ")
        }
        .onAppear {
            locationProfile.activate()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                locationProfile.activate()
            case .background:
                // What the wearer last saw becomes the complication's "as of" time.
                updateComplication()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onChange(of: complicationKey) { _, _ in
            updateComplication()
        }
        .onChange(of: locationProfile.refreshEvent) { _, event in
            guard let event else { return }
            showRefreshConfirmation(for: event.outcome)
        }
        .onDisappear {
            refreshConfirmationTask?.cancel()
        }
    }

    @ViewBuilder
    private var content: some View {
        #if DEBUG
        if WatchComplicationGallery.isRequested, !viewState.isWaitingForInitialData {
            WatchComplicationGallery(viewState: viewState, glyph: locationProfile.boundaryGlyph)
        } else {
            screen
        }
        #else
        screen
        #endif
    }

    @ViewBuilder
    private var screen: some View {
        if let stage = viewState.waitStage {
            WatchWaitingView(stage: stage, reduceMotion: reduceMotion)
        } else if displaySnapshot.hasDemographicData {
            WatchProfilePages(
                snapshot: displaySnapshot,
                viewState: viewState,
                glyph: locationProfile.boundaryGlyph,
                traceToken: locationProfile.traceToken,
                reduceMotion: reduceMotion,
                refresh: refreshButtonAction
            )
        } else {
            WatchMessageView(
                snapshot: displaySnapshot,
                primaryAction: viewState.primaryAction,
                onPrimaryAction: handlePrimaryAction
            )
        }
    }

    /// What the refresh button does, or `nil` when it has no use on the watch.
    ///
    /// With location off, iPhone opens Settings; watchOS apps cannot, and the
    /// status line already says the city is saved and location is off.
    private var refreshButtonAction: WatchRefreshAction? {
        switch viewState.refreshControl {
        case .refresh, .requestPermissionAndRefresh:
            return WatchRefreshAction(isBusy: viewState.isBusy) {
                Haptics.selectionChanged()
                Task { await locationProfile.refresh(trigger: .button) }
            }
        case .openSettings, .hidden:
            return nil
        }
    }

    /// Changes whenever the complication record would: a new answer about
    /// the wearer's place, a new place, or its outline arriving.
    private var complicationKey: String {
        [
            "\(viewState.placeAnswer)",
            viewState.placeKey ?? "",
            viewState.snapshot.market,
            viewState.snapshot.statusLine,
            locationProfile.boundaryGlyph == nil ? "no outline" : "outline"
        ].joined(separator: "|")
    }

    /// Writes what the screen says about the wearer's place for the
    /// complications, and reloads them.
    ///
    /// Only a definite answer is written: the current city, or a place
    /// without city data. A saved city that may not be current, location
    /// that is off, and failures leave the last record, whose "as of" time
    /// then shows its age.
    private func updateComplication() {
        #if DEBUG
        // Fixture data must never reach a real watch face.
        guard LociqLaunchFixture.current == nil else { return }
        #endif
        guard
            let record = ComplicationSnapshot(viewState: viewState, glyph: locationProfile.boundaryGlyph, confirmedAt: Date()),
            ComplicationSnapshotStore().save(record)
        else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: CityComplicationEntry.kind)
    }

    /// Routes the message screen's button.
    private func handlePrimaryAction() {
        switch viewState.primaryAction {
        case .requestPermission:
            Haptics.selectionChanged()
            locationProfile.requestLocationAccess()
        case .retry:
            Haptics.selectionChanged()
            locationProfile.retry()
        case .toggleDetails, .openSettings, .none:
            break
        }
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
}

/// The refresh button's state and action.
struct WatchRefreshAction {
    /// True while a location or Census request is under way.
    let isBusy: Bool

    /// Locates and reloads.
    let perform: () -> Void
}
