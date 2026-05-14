//
//  CensusServiceError.swift
//  Lociq
//
//  Defines shared Census service failures for geocoding, ACS, and TIGER clients.
//

import Foundation

/// Service-level failures produced while loading Census-backed city profiles.
enum CensusServiceError: Error, LocalizedError {
    case invalidURL
    case requestFailed(status: Int, bodySnippet: String)
    case decodeFailed(String)
    case noBoundaryFound
    case noDemographicsFound

    /// Human-readable diagnostic text for logs and failure classification.
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .requestFailed(let status, let body): return "HTTP \(status): \(body)"
        case .decodeFailed(let message): return "Decode failed: \(message)"
        case .noBoundaryFound: return "No boundary found"
        case .noDemographicsFound: return "No demographics returned"
        }
    }
}
