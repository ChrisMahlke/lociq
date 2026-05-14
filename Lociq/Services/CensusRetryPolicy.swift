//
//  CensusRetryPolicy.swift
//  Lociq
//
//  Defines retry, backoff, and timeout behavior for Census service requests.
//

import Foundation

/// Retry and timeout configuration for Census-backed HTTP requests.
struct CensusRetryPolicy: Sendable {
    let maxAttempts: Int
    let requestTimeoutNanoseconds: UInt64
    let baseBackoffNanoseconds: UInt64

    /// Production retry policy tuned for short user-facing profile loads.
    static let live = CensusRetryPolicy(
        maxAttempts: 3,
        requestTimeoutNanoseconds: 8_000_000_000,
        baseBackoffNanoseconds: 280_000_000
    )

    /// Creates a retry policy with an attempt count, per-attempt timeout, and base backoff.
    init(maxAttempts: Int, requestTimeoutNanoseconds: UInt64, baseBackoffNanoseconds: UInt64) {
        self.maxAttempts = max(1, maxAttempts)
        self.requestTimeoutNanoseconds = requestTimeoutNanoseconds
        self.baseBackoffNanoseconds = baseBackoffNanoseconds
    }

    /// Returns the exponential backoff delay for a zero-based failed attempt.
    func backoffDelay(afterFailedAttempt attempt: Int) -> UInt64 {
        baseBackoffNanoseconds * UInt64(1 << min(max(attempt, 0), 4))
    }
}
