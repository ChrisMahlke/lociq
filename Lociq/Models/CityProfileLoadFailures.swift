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

import Foundation

/// User-facing categories for failures encountered while loading a city profile.
///
/// These cases intentionally describe product states rather than implementation
/// details. For example, several different HTTP or decoding failures can become
/// `.serviceUnavailable`, while a timeout remains distinct because the app can
/// communicate slow service behavior differently from missing data.
enum CityProfileLoadFailure: Codable, Equatable, Sendable {
    case censusKeyMissing
    case cityUnavailable
    case demographicsUnavailable
    case boundaryUnavailable
    case networkUnavailable
    case timedOut
    case serviceUnavailable
}

/// Profile-loading subrequest stages that can fail while another stage succeeds.
///
/// A city profile is assembled from multiple independent Census services. ACS
/// data can succeed when TIGER geometry fails, and geocoding can succeed when
/// demographics fail. The stage value preserves that partial-failure context.
enum CityProfileLoadStage: String, Codable, Sendable {
    case geocoder
    case demographics
    case boundary
}

/// Typed partial failure attached to a profile when one service fails but useful data remains.
///
/// Partial failures travel with `CachedCityProfile` so stale or incomplete data
/// can still be displayed honestly without turning every subrequest failure
/// into a full-screen unavailable state.
struct CityProfilePartialFailure: Codable, Equatable, Sendable {
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
    init(error: Error) {
        guard let serviceError = error as? CensusServiceError else {
            self = .serviceUnavailable
            return
        }

        switch serviceError {
        case .networkUnavailable:
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
