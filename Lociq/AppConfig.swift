//
//  AppConfig.swift
//  Lociq
//
//  Centralized runtime configuration values used across services.
//

import Foundation

enum AppConfig {
    nonisolated static var censusAPIKey: String {
        value(forAnyOf: ["CENSUS_API_KEY", "CensusAPIKey"])
    }

    nonisolated private static func value(forAnyOf keys: [String]) -> String {
        for key in keys {
            let resolved = value(for: key)
            if !resolved.isEmpty {
                return resolved
            }
        }
        return ""
    }

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
