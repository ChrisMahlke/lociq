//
//  ProfileLoadPlanner.swift
//  Lociq
//
//  Plans duplicate suppression and pre-load UI state for city profile requests.
//

import CoreLocation
import Foundation

/// Planning result for one coordinate-driven profile load.
struct ProfileLoadPlan: Sendable {
    let coordinateKey: String
    let preLoadState: LocationProfileViewModel.State
}

/// Encapsulates profile request duplicate checks and refresh/loading state selection.
struct ProfileLoadPlanner: Sendable {
    let cacheMaxAge: TimeInterval
    let moveThresholdMeters: CLLocationDistance
    let now: @Sendable () -> Date

    /// Returns a load plan or `nil` when the coordinate is a suppressed duplicate.
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
    static func coordinateKey(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    /// Returns true when two coordinates are far enough apart to justify replacing the visible profile immediately.
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
