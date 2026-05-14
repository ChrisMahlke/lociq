//
//  CensusServiceError.swift
//  Lociq
//
//  Defines shared Census service failures for geocoding, ACS, and TIGER clients.
//

import Foundation

/// Service-level failures produced while loading Census-backed city profiles.
enum CensusServiceError: Error, Equatable, LocalizedError, Sendable {
    case invalidURL
    case networkUnavailable(String)
    case timedOut
    case requestFailed(status: Int, bodySnippet: String)
    case decodeFailed(String)
    case noBoundaryFound
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
