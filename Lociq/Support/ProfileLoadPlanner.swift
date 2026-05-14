//
//  ProfileLoadPlanner.swift
//  Lociq
//
//  Plans duplicate suppression and pre-load UI state for city profile requests.
//
//  Location updates can arrive repeatedly with tiny coordinate differences. The
//  planner centralizes the decision about whether a new profile load is needed
//  and what state should be shown while that load is in flight.
//

import CoreLocation
import Foundation

/// Planning result for one coordinate-driven profile load.
///
/// A plan carries both duplicate-suppression identity and the state the view
/// model should enter before the async request starts.
struct ProfileLoadPlan: Sendable {
    /// Rounded coordinate key saved as the last requested location.
    let coordinateKey: String

    /// State to publish before the load task begins.
    let preLoadState: LocationProfileViewModel.State
}

/// Encapsulates profile request duplicate checks and refresh/loading state selection.
///
/// The planner is pure and testable. It does not start tasks or mutate the view
/// model. It only decides whether a load should happen and whether existing data
/// should remain visible during the load.
struct ProfileLoadPlanner: Sendable {
    /// Maximum cache age used to mark a visible profile stale during refresh.
    let cacheMaxAge: TimeInterval

    /// Movement threshold before the visible profile should be replaced by a full loading state.
    let moveThresholdMeters: CLLocationDistance

    /// Date provider injected for deterministic cache freshness tests.
    let now: @Sendable () -> Date

    /// Returns a load plan or `nil` when the coordinate is a suppressed duplicate.
    ///
    /// If the coordinate is close to the current profile, the previous profile
    /// remains visible in `.refreshing`. If the user has moved far enough, the
    /// app enters `.loading` so stale city data is not shown for a different
    /// place.
    func plan(
        coordinate: CLLocationCoordinate2D,
        previousProfile: CachedCityProfile?,
        previousStale: Bool,
        lastCoordinateKey: String?,
        force: Bool
    ) -> ProfileLoadPlan? {
        let coordinateKey = Self.coordinateKey(for: coordinate)
        guard force || coordinateKey != lastCoordinateKey else { return nil }

        let preLoadState: LocationProfileViewModel.State
        if let previousProfile,
           !Self.isMeaningfullyDifferent(
            previousProfile.coordinate,
            from: coordinate,
            thresholdMeters: moveThresholdMeters
           ) {
            preLoadState = .refreshing(
                previousProfile,
                isStale: previousStale || previousProfile.isExpired(at: now(), maxAge: cacheMaxAge)
            )
        } else {
            preLoadState = .loading
        }

        return ProfileLoadPlan(coordinateKey: coordinateKey, preLoadState: preLoadState)
    }

    /// Rounds a coordinate into a stable key for suppressing duplicate loads.
    ///
    /// Four decimal places roughly filters GPS jitter while still changing when
    /// the user moves a meaningful distance.
    static func coordinateKey(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    /// Returns true when two coordinates are far enough apart to justify replacing the visible profile immediately.
    ///
    /// Core Location distance calculation is used instead of raw latitude and
    /// longitude deltas because degree distances vary by latitude.
    static func isMeaningfullyDifferent(
        _ lhs: CLLocationCoordinate2D,
        from rhs: CLLocationCoordinate2D,
        thresholdMeters: CLLocationDistance
    ) -> Bool {
        let start = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
        let end = CLLocation(latitude: rhs.latitude, longitude: rhs.longitude)
        return start.distance(from: end) > thresholdMeters
    }
}
