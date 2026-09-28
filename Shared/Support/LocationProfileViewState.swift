//
//  LocationProfileViewState.swift
//  Lociq
//
//  Projects location profile state into view-facing display values.
//
//  This file keeps view-state derivation out of `ContentView`. SwiftUI reads a
//  simple immutable projection, while the view model keeps its richer internal
//  state machine. Actions are typed, so views route taps without comparing
//  display strings.
//

import CoreLocation
import Foundation

/// What the header says about a displayed profile.
///
/// A profile is presented as the user's place only while that is known to be
/// true. Every other case is labeled, so the status line never implies the
/// wrong place is current.
nonisolated enum ProfileStatus: Equatable, Sendable {
    /// The profile is for the place the latest fix is in.
    case current

    /// Shown without location access, for example after "Allow Once" expired.
    case lastLocation

    /// Shown while location access is off (denied) or restricted.
    case locationOff(restricted: Bool)

    /// The latest location fix failed; the user may have moved.
    case lastKnownArea

    /// The user left this place and the new place could not be loaded.
    case notCurrentLocation

    /// Same place, but the latest refresh failed; the saved data is shown.
    case savedAfterFailedRefresh(CityProfileLoadFailure)
}

/// Why a loaded profile is being reloaded.
nonisolated enum RefreshContext: Equatable, Sendable {
    /// Same place (a user refresh, or data from an older release).
    case sameArea

    /// The user has left the displayed place; the old place stays dimmed meanwhile.
    case newLocation
}

/// Stage of the initial wait, shown as one line under the spinner.
nonisolated enum WaitStage: Equatable, Sendable {
    case locating
    case readingCensus

    /// Stage line text.
    var label: String {
        switch self {
        case .locating: return "LOCATING…"
        case .readingCensus: return "READING CENSUS DATA…"
        }
    }

    /// Stage text for VoiceOver.
    var spokenLabel: String {
        switch self {
        case .locating: return "Finding your location"
        case .readingCensus: return "Loading Census data"
        }
    }
}

/// The one primary action the bottom button performs.
nonisolated enum PrimaryAction: Equatable, Sendable {
    /// Swap between the summary and the details.
    case toggleDetails

    /// Ask for location access (first run).
    case requestPermission

    /// Open LOC IQ's page in Settings (location denied).
    case openSettings

    /// Try the failed step again (transient failures only).
    case retry

    /// No action helps (restricted, permanent failures, waiting).
    case none
}

/// What the refresh control does for a displayed profile.
nonisolated enum RefreshControl: Equatable, Sendable {
    /// Find the current location, then reload.
    case refresh

    /// Ask for location access, then locate and reload.
    case requestPermissionAndRefresh

    /// Location is off: open Settings to turn it on.
    case openSettings

    /// Nothing can refresh (location restricted).
    case hidden
}

/// What the screen says about where the user is.
///
/// Surfaces that cannot check the location themselves, such as the watch
/// complications, repeat only a definite answer.
nonisolated enum PlaceAnswer: Equatable, Sendable {
    /// The displayed city is the user's current place.
    case city

    /// The user's location has no city data, such as outside city limits.
    case noCity

    /// Nothing definite: waiting, refreshing, a saved city that may not be
    /// current, location off, or a failure that says nothing about the place.
    case unknown
}

/// Immutable display state consumed by the root SwiftUI view.
///
/// The values are already reduced to exactly what the view needs. This prevents
/// view code from switching over `LocationProfileViewModel.State` directly.
struct LocationProfileViewState: Sendable {
    /// Display snapshot for title, status line, metrics, details, and share text.
    let snapshot: DemographicSnapshot

    /// Boundary geometry available to the boundary preview.
    let boundary: GeoJSONFeatureCollection?

    /// Coordinate used for the location marker.
    let coordinate: CLLocationCoordinate2D?

    /// Horizontal accuracy used to size or hide the marker.
    let horizontalAccuracy: CLLocationAccuracy?

    /// True when the fix came from approximate location.
    let isApproximate: Bool

    /// True while an active location or profile request is in flight.
    let isBusy: Bool

    /// True before the initial minimal loading screen can be replaced.
    let isWaitingForInitialData: Bool

    /// Stage line for the initial wait.
    let waitStage: WaitStage?

    /// What the primary bottom button does.
    let primaryAction: PrimaryAction

    /// What the refresh control does.
    let refreshControl: RefreshControl

    /// True when pulling down should do something useful.
    let canPullToRefresh: Bool

    /// True while the previous place stays visible, dimmed, as a new place loads.
    let isContentDimmed: Bool

    /// Stable identity of the displayed place.
    let placeKey: String?

    /// Optional text payload for the share sheet.
    let shareText: String?

    /// What the screen says about where the user is.
    let placeAnswer: PlaceAnswer

    /// Returns true when boundary geometry is available for a complete demographic profile.
    ///
    /// Boundaries are hidden during initial loading and non-demographic states
    /// so the outline never implies unavailable demographic data exists.
    var canShowBoundary: Bool {
        boundary != nil && !isWaitingForInitialData && snapshot.hasDemographicData
    }

    /// True in the first-run state that asks for location access.
    var needsLocationPermissionPrompt: Bool {
        primaryAction == .requestPermission
    }
}

/// Converts the ViewModel's state machine into simple view-facing values.
///
/// The mapper is pure. It does not mutate state, call services, or trigger
/// animation. That makes UI projection deterministic and easy to test.
enum LocationProfileViewStateMapper {
    /// Builds a view state for the supplied profile state and optional debug coordinate.
    ///
    /// - Parameters:
    ///   - state: Internal view-model state.
    ///   - debugCoordinate: Optional coordinate used by debug launches.
    /// - Returns: Immutable values needed by `ContentView`.
    static func make(
        from state: LocationProfileViewModel.State,
        debugCoordinate: CLLocationCoordinate2D?
    ) -> LocationProfileViewState {
        let snapshot = snapshot(from: state)
        let profile = displayedProfile(in: state)

        return LocationProfileViewState(
            snapshot: snapshot,
            boundary: profile?.boundary,
            coordinate: coordinate(from: state, debugCoordinate: debugCoordinate),
            horizontalAccuracy: horizontalAccuracy(from: state),
            isApproximate: profile?.isApproximate ?? false,
            isBusy: isBusy(state),
            isWaitingForInitialData: waitStage(state) != nil,
            waitStage: waitStage(state),
            primaryAction: primaryAction(state),
            refreshControl: refreshControl(state),
            canPullToRefresh: canPullToRefresh(state),
            isContentDimmed: isContentDimmed(state),
            placeKey: profile.map { $0.resolvedPlaceGeoid ?? $0.snapshot.market },
            shareText: snapshot.shareText,
            placeAnswer: placeAnswer(state)
        )
    }

    /// Header status line for a displayed profile.
    static func statusLine(for status: ProfileStatus, profile: CachedCityProfile) -> String {
        switch status {
        case .current:
            if profile.isApproximate == true { return "APPROXIMATE AREA" }
            if profile.snapshot.isSmallArea { return "SMALL-AREA ESTIMATE" }
            return ""
        case .lastLocation:
            return "LAST LOCATION"
        case .locationOff:
            return "SAVED CITY · LOCATION OFF"
        case .lastKnownArea:
            return "LAST KNOWN AREA"
        case .notCurrentLocation:
            return "LAST KNOWN AREA · NOT YOUR CURRENT LOCATION"
        case .savedAfterFailedRefresh(let failure):
            switch failure {
            case .networkUnavailable: return "SAVED · OFFLINE"
            case .timedOut: return "SAVED · NO RESPONSE"
            case .serviceUnavailable: return "SAVED · SERVICE UNAVAILABLE"
            default: return "SAVED"
            }
        }
    }

    /// Header status line while a displayed profile reloads.
    static func statusLine(for context: RefreshContext) -> String {
        switch context {
        case .sameArea: return "REFRESHING"
        case .newLocation: return "UPDATING FOR NEW LOCATION"
        }
    }

    /// Returns the snapshot that should be displayed for a state-machine state.
    private static func snapshot(from state: LocationProfileViewModel.State) -> DemographicSnapshot {
        switch state {
        case .idle, .requestingLocation, .loading:
            return .loading
        case .needsLocationPermission:
            return .permissionPrompt
        case .locationUnavailable(let reason):
            switch reason {
            case .denied: return .locationDenied
            case .restricted: return .locationRestricted
            case .noFix: return .locationNotFound
            }
        case .refreshing(let profile, let context):
            return profile.snapshot.withStatus(statusLine(for: context))
        case .loaded(let profile, let status):
            return profile.snapshot.withStatus(statusLine(for: status, profile: profile))
        case .profileUnavailable(let unavailable):
            return unavailable.snapshot
        }
    }

    /// The profile on screen, if any.
    private static func displayedProfile(in state: LocationProfileViewModel.State) -> CachedCityProfile? {
        switch state {
        case .refreshing(let profile, _), .loaded(let profile, _):
            return profile
        case .idle, .needsLocationPermission, .requestingLocation, .loading, .locationUnavailable, .profileUnavailable:
            return nil
        }
    }

    /// Returns the marker coordinate, falling back to a debug coordinate for tests.
    private static func coordinate(
        from state: LocationProfileViewModel.State,
        debugCoordinate: CLLocationCoordinate2D?
    ) -> CLLocationCoordinate2D? {
        switch state {
        case .refreshing(let profile, _), .loaded(let profile, _):
            return profile.markerCoordinate
        case .profileUnavailable(let unavailable):
            return unavailable.coordinate
        case .idle, .needsLocationPermission, .requestingLocation, .loading, .locationUnavailable:
            return debugCoordinate
        }
    }

    /// Returns the horizontal accuracy attached to the current state.
    ///
    /// Loading and permission states do not invent accuracy values.
    private static func horizontalAccuracy(from state: LocationProfileViewModel.State) -> CLLocationAccuracy? {
        switch state {
        case .refreshing(let profile, _), .loaded(let profile, _):
            return profile.markerAccuracy
        case .profileUnavailable(let unavailable):
            return unavailable.horizontalAccuracy
        case .idle, .needsLocationPermission, .requestingLocation, .loading, .locationUnavailable:
            return nil
        }
    }

    /// Returns true while a location or profile request is active.
    ///
    /// `refreshing` counts as busy even though data remains visible. Busy
    /// drives the loading line only; it never locks the details toggle.
    private static func isBusy(_ state: LocationProfileViewModel.State) -> Bool {
        switch state {
        case .idle, .requestingLocation, .loading, .refreshing:
            return true
        case .needsLocationPermission, .loaded, .locationUnavailable, .profileUnavailable:
            return false
        }
    }

    /// Returns the wait stage before any displayable data or fallback state is ready.
    private static func waitStage(_ state: LocationProfileViewModel.State) -> WaitStage? {
        switch state {
        case .idle, .requestingLocation:
            return .locating
        case .loading:
            return .readingCensus
        case .needsLocationPermission, .refreshing, .loaded, .locationUnavailable, .profileUnavailable:
            return nil
        }
    }

    /// Returns the primary bottom action for a state.
    ///
    /// Retry is offered only where it can help: a missing fix and transient
    /// service failures. A denial routes to Settings; restrictions and
    /// permanent conditions offer nothing rather than a retry loop.
    private static func primaryAction(_ state: LocationProfileViewModel.State) -> PrimaryAction {
        switch state {
        case .idle, .requestingLocation, .loading:
            return .none
        case .needsLocationPermission:
            return .requestPermission
        case .locationUnavailable(let reason):
            switch reason {
            case .denied: return .openSettings
            case .restricted: return .none
            case .noFix: return .retry
            }
        case .profileUnavailable(let unavailable):
            return unavailable.failure.isRetryable ? .retry : .none
        case .refreshing, .loaded:
            return .toggleDetails
        }
    }

    /// Returns what the refresh control does for a displayed profile.
    private static func refreshControl(_ state: LocationProfileViewModel.State) -> RefreshControl {
        switch state {
        case .loaded(_, let status):
            switch status {
            case .lastLocation: return .requestPermissionAndRefresh
            case .locationOff(let restricted): return restricted ? .hidden : .openSettings
            case .current, .lastKnownArea, .notCurrentLocation, .savedAfterFailedRefresh: return .refresh
            }
        case .refreshing:
            return .refresh
        case .idle, .needsLocationPermission, .requestingLocation, .loading, .locationUnavailable, .profileUnavailable:
            return .hidden
        }
    }

    /// Returns true when a pull-down gesture should refresh or retry.
    ///
    /// While a profile is shown, pulling always stays available so the scroll
    /// view keeps its identity and position when location access changes; the
    /// view model decides what a pull can do (it never opens Settings).
    private static func canPullToRefresh(_ state: LocationProfileViewModel.State) -> Bool {
        switch state {
        case .loaded, .refreshing:
            return true
        case .profileUnavailable(let unavailable):
            return unavailable.failure.isRetryable
        case .locationUnavailable(let reason):
            return reason == .noFix
        case .idle, .needsLocationPermission, .requestingLocation, .loading:
            return false
        }
    }

    /// Returns what the state says about where the user is.
    ///
    /// Only a current city, or a located place without city data, is a
    /// definite answer.
    private static func placeAnswer(_ state: LocationProfileViewModel.State) -> PlaceAnswer {
        switch state {
        case .loaded(_, .current):
            return .city
        case .profileUnavailable(let unavailable):
            switch unavailable.failure {
            case .cityUnavailable, .outsideCoverage, .demographicsUnavailable:
                return .noCity
            case .networkUnavailable, .timedOut, .serviceUnavailable, .censusKeyMissing, .boundaryUnavailable:
                return .unknown
            }
        case .idle, .needsLocationPermission, .requestingLocation, .loading, .refreshing, .loaded, .locationUnavailable:
            return .unknown
        }
    }

    /// Returns true while the previous place stays visible as a new place loads.
    private static func isContentDimmed(_ state: LocationProfileViewModel.State) -> Bool {
        if case .refreshing(_, .newLocation) = state { return true }
        return false
    }
}
