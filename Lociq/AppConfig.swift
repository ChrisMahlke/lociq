//
//  AppConfig.swift
//  Lociq
//
//  Centralized runtime configuration values used across services.
//

import Foundation

enum AppConfig {
    /// Resolves the Census API key from environment variables or Info.plist build settings.
    nonisolated static var censusAPIKey: String {
        value(forAnyOf: ["CENSUS_API_KEY", "CensusAPIKey"])
    }

    /// Returns the first non-empty configuration value for the supplied keys.
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
