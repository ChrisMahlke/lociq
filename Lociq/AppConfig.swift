//
//  AppConfig.swift
//  Lociq
//
//  Centralized runtime configuration values used across services.
//
//  Configuration is intentionally read from two places. Unit tests and command
//  line builds can inject values through environment variables, while the
//  production app resolves build settings from `Info.plist`. This keeps service
//  construction simple and avoids passing configuration through the SwiftUI
//  view tree.
//

import Foundation

enum AppConfig {
    /// Resolves the Census API key from environment variables or `Info.plist` build settings.
    ///
    /// Environment variables win over bundle values so tests and local
    /// development can override the key without editing the app target.
    nonisolated static var censusAPIKey: String {
        value(forAnyOf: ["CENSUS_API_KEY", "CensusAPIKey"])
    }

    /// Returns the first non-empty configuration value for the supplied keys.
    ///
    /// The keys are checked in order. This lets callers define explicit
    /// precedence while still keeping value lookup centralized.
    nonisolated private static func value(forAnyOf keys: [String]) -> String {
        for key in keys {
            let resolved = value(for: key)
            if !resolved.isEmpty {
                return resolved
            }
        }
        return ""
    }

    /// Resolves a single configuration value from the process environment or application bundle.
    ///
    /// - Parameter key: The environment variable or bundle key to read.
    /// - Returns: The configured string, or an empty string when the value is
    ///   missing. Empty strings are treated as unavailable configuration.
    nonisolated private static func value(for key: String) -> String {
        if let env = ProcessInfo.processInfo.environment[key], !env.isEmpty {
            return env
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !plistValue.isEmpty {
            return plistValue
        }

        return ""
    }
}
