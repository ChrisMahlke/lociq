//
//  CityProfileCachePolicy.swift
//  Lociq
//
//  Centralizes profile cache freshness rules.
//

import Foundation

/// Defines when cached city profiles should be treated as stale.
struct CityProfileCachePolicy: Sendable {
    let maxAge: TimeInterval

    /// Production policy: cached profiles remain fresh for one day.
    static let live = CityProfileCachePolicy(maxAge: 86_400)

    /// Creates a freshness policy with a maximum profile age in seconds.
    init(maxAge: TimeInterval) {
        self.maxAge = maxAge
    }

    /// Returns true when the profile is older than the policy allows.
    func isStale(_ profile: CachedCityProfile, at date: Date) -> Bool {
        profile.isExpired(at: date, maxAge: maxAge)
    }
}
