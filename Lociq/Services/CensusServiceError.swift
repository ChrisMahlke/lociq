//
//  CensusServiceError.swift
//  Lociq
//
//  Defines shared Census service failures for geocoding, ACS, and TIGER clients.
//
//  This error type is intentionally service-level. It captures transport,
//  response, decoding, and no-data conditions before they are mapped into the
//  smaller user-facing `CityProfileLoadFailure` categories.
//

import Foundation

/// Service-level failures produced while loading Census-backed city profiles.
///
/// Endpoint clients should throw this type whenever possible. That gives the
/// loader enough information to decide whether to retry, show stale data, or
/// present a no-data state.
enum CensusServiceError: Error, Equatable, LocalizedError, Sendable {
    /// URL construction failed before a network request could be made.
    case invalidURL

    /// The request failed because the network path was unavailable or unstable.
    case networkUnavailable(String)

    /// The request exceeded the configured per-attempt timeout.
    case timedOut

    /// The service returned a non-success HTTP status code.
    case requestFailed(status: Int, bodySnippet: String)

    /// The response body could not be decoded into the expected model.
    case decodeFailed(String)

    /// TIGERweb returned no boundary features for the requested place.
    case noBoundaryFound

    /// ACS returned no usable demographic row for the requested place.
    case noDemographicsFound

    /// Human-readable diagnostic text for logs and failure classification.
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkUnavailable(let message): return "Network unavailable: \(message)"
        case .timedOut: return "Request timed out"
        case .requestFailed(let status, let body): return "HTTP \(status): \(body)"
        case .decodeFailed(let message): return "Decode failed: \(message)"
        case .noBoundaryFound: return "No boundary found"
        case .noDemographicsFound: return "No demographics returned"
        }
    }

    /// Normalizes transport errors from URLSession into service failure categories.
    ///
    /// URLSession reports many connectivity failures through `URLError`. This
    /// method groups those raw codes into the smaller service taxonomy used by
    /// the retry and loader layers.
    static func transport(_ error: Error) -> CensusServiceError {
        guard let urlError = error as? URLError else {
            return .networkUnavailable(error.localizedDescription)
        }

        switch urlError.code {
        case .timedOut:
            return .timedOut
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .networkUnavailable(urlError.localizedDescription)
        default:
            return .networkUnavailable(urlError.localizedDescription)
        }
    }

    /// Returns true when retrying the request may succeed without user action.
    ///
    /// Timeouts, network failures, rate limiting, and server-side errors are
    /// considered transient. Invalid requests, no-data responses, and decode
    /// failures are treated as deterministic for the current request.
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .timedOut:
            return true
        case .requestFailed(let status, _):
            return status == 408 || status == 425 || status == 429 || (500...599).contains(status)
        case .invalidURL, .decodeFailed, .noBoundaryFound, .noDemographicsFound:
            return false
        }
    }
}
