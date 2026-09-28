//
//  ProfileLoadPlanner.swift
//  Lociq
//
//  Decides whether a location fix needs a new city-profile load.
//
//  Freshness is defined by place and data vintage, not by the clock: ACS
//  5-year estimates change once a year, so a profile stays valid for as long
//  as the user is still in its place and the app still requests its vintage.
//  The planner is pure and testable. It does not start tasks or mutate state.
//

import CoreLocation
import Foundation

/// What to do with one location fix.
enum ProfileLoadDecision {
    /// A load for the same coordinate cell is already known; do nothing.
    case suppressDuplicate

    /// The user is still in the displayed place and its data is current: no
    /// network request. The profile carries the marker moved to the new fix.
    case keepProfile(CachedCityProfile)

    /// Load a profile, entering `preLoadState` while it is in flight.
    case load(coordinateKey: String, preLoadState: LocationProfileViewModel.State)
}

/// Whether a fix is still in the displayed profile's place.
nonisolated enum PlaceRelation: Equatable, Sendable {
    case samePlace
    case elsewhere
}

/// Encapsulates reload decisions for location fixes.
struct ProfileLoadPlanner: Sendable {
    /// A fix this close to the coordinate the place was looked up for is the same spot.
    static let sameSpotRadiusMeters: CLLocationDistance = 250

    /// Minimum distance from the boundary edge before "inside" is trusted.
    ///
    /// Generalized outlines are simplified, and fixes have error, so a point
    /// just inside the drawn edge may be in the neighboring place.
    static let minimumEdgeClearanceMeters: CLLocationDistance = 150

    /// How long a profile without its boundary waits before the next fix retries it.
    static let missingBoundaryRetryInterval: TimeInterval = 3_600

    /// Data vintage the app currently requests.
    let vintage: CensusDataVintage

    /// Date provider injected for deterministic tests.
    let now: @Sendable () -> Date

    /// Decides what one fix requires.
    ///
    /// - Parameters:
    ///   - fix: The new location fix.
    ///   - currentProfile: The profile on screen, if any.
    ///   - lastCoordinateKey: Key of the last load started without a profile on screen.
    ///   - force: True for a user-initiated refresh, which always loads.
    func decide(
        fix: LocationFix,
        currentProfile: CachedCityProfile?,
        lastCoordinateKey: String?,
        force: Bool
    ) -> ProfileLoadDecision {
        let coordinateKey = Self.coordinateKey(for: fix.coordinate)

        guard let currentProfile else {
            guard force || coordinateKey != lastCoordinateKey else { return .suppressDuplicate }
            return .load(coordinateKey: coordinateKey, preLoadState: .loading)
        }

        let relation = Self.relation(of: fix, to: currentProfile)
        if !force, relation == .samePlace, currentProfile.isCurrent(for: vintage), !needsBoundaryRetry(currentProfile) {
            return .keepProfile(currentProfile.withMarker(at: fix))
        }

        return .load(
            coordinateKey: coordinateKey,
            preLoadState: .refreshing(currentProfile, context: relation == .samePlace ? .sameArea : .newLocation)
        )
    }

    /// True when a profile lacks its boundary and has waited long enough to try again.
    private func needsBoundaryRetry(_ profile: CachedCityProfile) -> Bool {
        guard profile.isMissingBoundary else { return false }
        guard let cachedAt = profile.cachedAt else { return true }
        return now().timeIntervalSince(cachedAt) > Self.missingBoundaryRetryInterval
    }

    /// Decides whether a fix is still inside the displayed profile's place.
    ///
    /// A fix is in the same place when it is within 250 m of the coordinate the
    /// place was looked up for, or clearly inside the boundary: inside, and
    /// farther from the edge than the fix's own uncertainty.
    static func relation(of fix: LocationFix, to profile: CachedCityProfile) -> PlaceRelation {
        let distance = CLLocation(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude)
            .distance(from: CLLocation(latitude: profile.latitude, longitude: profile.longitude))
        if distance <= sameSpotRadiusMeters { return .samePlace }

        guard let boundary = profile.boundary, let result = BoundaryContainment.test(fix.coordinate, in: boundary) else {
            return .elsewhere
        }
        let clearance = max(fix.horizontalAccuracy ?? 0, minimumEdgeClearanceMeters)
        return result.isInside && result.edgeDistanceMeters >= clearance ? .samePlace : .elsewhere
    }

    /// Rounds a coordinate into a stable key for suppressing duplicate loads.
    ///
    /// Four decimal places (about 11 m) filter repeated callbacks for the
    /// same fix while still changing when the user moves.
    static func coordinateKey(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }
}
