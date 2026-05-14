//
//  CityProfileLoadFailures.swift
//  Lociq
//
//  Defines typed failures for full and partial city-profile loading.
//

import Foundation

/// User-facing categories for failures encountered while loading a city profile.
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
enum CityProfileLoadStage: String, Codable, Sendable {
    case geocoder
    case demographics
    case boundary
}

/// Typed partial failure attached to a profile when one service fails but useful data remains.
struct CityProfilePartialFailure: Codable, Equatable, Sendable {
    let stage: CityProfileLoadStage
    let failure: CityProfileLoadFailure

    /// Creates a typed partial failure for one profile-loading stage.
    init(stage: CityProfileLoadStage, failure: CityProfileLoadFailure) {
        self.stage = stage
        self.failure = failure
    }
}

extension CityProfileLoadFailure {
    /// Converts low-level Census errors into stable UI/domain failure categories.
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
