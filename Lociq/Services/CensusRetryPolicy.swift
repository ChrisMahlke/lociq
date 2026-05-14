//
//  CensusRetryPolicy.swift
//  Lociq
//
//  Defines retry, backoff, and timeout behavior for Census service requests.
//
//  Public data services can be slower and less predictable than an app-owned
//  backend. This policy keeps retry behavior explicit and testable.
//

import Foundation

/// Retry and timeout configuration for Census-backed HTTP requests.
///
/// The values are expressed in nanoseconds because Swift concurrency APIs use
/// nanosecond sleep durations. The policy clamps attempts to at least one so a
/// caller cannot accidentally create a client that never tries the request.
struct CensusRetryPolicy: Sendable {
    /// Total attempts including the first request.
    let maxAttempts: Int

    /// Timeout applied to each individual request attempt.
    let requestTimeoutNanoseconds: UInt64

    /// Base delay used for exponential backoff between retryable failures.
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
    ///
    /// The exponent is capped to avoid very large sleeps if a test constructs a
    /// policy with many attempts.
    func backoffDelay(afterFailedAttempt attempt: Int) -> UInt64 {
        baseBackoffNanoseconds * UInt64(1 << min(max(attempt, 0), 4))
    }
}
