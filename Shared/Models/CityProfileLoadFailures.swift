//
//  CityProfileLoadFailures.swift
//  Lociq
//
//  Defines typed failures for full and partial city-profile loading.
//
//  The UI deliberately exposes very little text, so the data layer needs stable
//  categories instead of raw networking or decoding errors. These types are the
//  contract between service failures, cache fallback, and display state.
//
//  Persisted with cached profiles: keep existing case names, add cases only.
//

import Foundation

/// User-facing categories for failures encountered while loading a city profile.
///
/// These cases intentionally describe product states rather than implementation
/// details. For example, several different HTTP or decoding failures can become
/// `.serviceUnavailable`, while a timeout remains distinct because the app can
/// communicate slow service behavior differently from missing data.
nonisolated enum CityProfileLoadFailure: Codable, Equatable, Sendable {
    /// No Census API key is configured (a build problem, never retried).
    case censusKeyMissing

    /// The location is outside every incorporated place and CDP ("outside city limits").
    case cityUnavailable

    /// The place exists but ACS has no usable estimates for it.
    case demographicsUnavailable

    /// The boundary outline could not be loaded (only ever a partial failure).
    case boundaryUnavailable

    /// The device is offline or the connection failed.
    case networkUnavailable

    /// A Census service did not respond in time.
    case timedOut

    /// A Census service returned an error or an unreadable response.
    case serviceUnavailable

    /// The location resolved to no county and no place: outside U.S. Census coverage.
    case outsideCoverage

    /// True when trying again without any user action may succeed.
    ///
    /// Only transient causes are retryable. Permanent conditions, such as a
    /// location outside every place, never offer a retry that cannot help.
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .timedOut, .serviceUnavailable:
            return true
        case .censusKeyMissing, .cityUnavailable, .demographicsUnavailable, .boundaryUnavailable, .outsideCoverage:
            return false
        }
    }
}

/// Profile-loading subrequest stages that can fail while another stage succeeds.
///
/// A city profile is assembled from multiple independent Census services. ACS
/// data can succeed when TIGER geometry fails, and geocoding can succeed when
/// demographics fail. The stage value preserves that partial-failure context.
nonisolated enum CityProfileLoadStage: String, Codable, Sendable {
    case geocoder
    case demographics
    case boundary
}

/// Typed partial failure attached to a profile when one service fails but useful data remains.
///
/// Partial failures travel with `CachedCityProfile` so stale or incomplete data
/// can still be displayed honestly without turning every subrequest failure
/// into a full-screen unavailable state.
nonisolated struct CityProfilePartialFailure: Codable, Equatable, Sendable {
    let stage: CityProfileLoadStage
    let failure: CityProfileLoadFailure

    /// Creates a typed partial failure for one profile-loading stage.
    ///
    /// - Parameters:
    ///   - stage: The subrequest stage that failed.
    ///   - failure: The normalized failure category for that stage.
    init(stage: CityProfileLoadStage, failure: CityProfileLoadFailure) {
        self.stage = stage
        self.failure = failure
    }
}

extension CityProfileLoadFailure {
    /// Converts low-level Census errors into stable UI/domain failure categories.
    ///
    /// Raw service errors can include transport, status, URL, and JSON decoding
    /// details. The UI should not depend on that raw surface. This initializer
    /// maps service errors into a small set of displayable states.
    nonisolated init(error: Error) {
        guard let serviceError = error as? CensusServiceError else {
            self = .serviceUnavailable
            return
        }

        switch serviceError {
        case .networkUnavailable, .cancelled:
            self = .networkUnavailable
        case .timedOut:
            self = .timedOut
        case .noDemographicsFound:
            self = .demographicsUnavailable
        case .noBoundaryFound:
            self = .boundaryUnavailable
        case .invalidURL, .requestFailed, .decodeFailed:
            self = .serviceUnavailable
        }
    }
}
