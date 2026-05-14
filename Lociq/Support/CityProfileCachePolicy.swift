//
//  CityProfileCachePolicy.swift
//  Lociq
//
//  Centralizes profile cache freshness rules.
//
//  Cache age decisions are kept out of the view model so refresh behavior stays
//  testable and consistent anywhere cached profiles are evaluated.
//

import Foundation

/// Defines when cached city profiles should be treated as stale.
///
/// A stale profile can still be useful as fallback UI while a live refresh is
/// attempted. The policy only answers freshness. It does not decide whether the
/// profile should be displayed.
struct CityProfileCachePolicy: Sendable {
    /// Maximum age, in seconds, before cached data is considered stale.
    let maxAge: TimeInterval

    /// Production policy: cached profiles remain fresh for one day.
    static let live = CityProfileCachePolicy(maxAge: 86_400)

    /// Creates a freshness policy with a maximum profile age in seconds.
    ///
    /// - Parameter maxAge: Maximum acceptable cache age in seconds.
    init(maxAge: TimeInterval) {
        self.maxAge = maxAge
    }

    /// Returns true when the profile is older than the policy allows.
    ///
    /// Profiles without a timestamp are treated as stale by
    /// `CachedCityProfile.isExpired`.
    func isStale(_ profile: CachedCityProfile, at date: Date) -> Bool {
        profile.isExpired(at: date, maxAge: maxAge)
    }
}
