//
//  AppConfig.swift
//  Lociq
//
//  Centralized runtime configuration values used across services and SDK setup.
//

import Foundation

/// Environment and API configuration consumed by application services.
enum AppConfig {
    struct KeyDiagnostics {
        let environmentValue: String?
        let plistValue: String?

        var summary: String {
            [
                "GOOGLE_MAPS_API_KEY env: \(redacted(environmentValue))",
                "GoogleMapsAPIKey plist: \(redacted(plistValue))"
            ].joined(separator: "\n")
        }

        private func redacted(_ value: String?) -> String {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else {
                return "<empty>"
            }

            if trimmed.count <= 8 {
                return "<set>"
            }

            return "\(trimmed.prefix(6))...\(trimmed.suffix(4))"
        }
    }

    /// Google Maps iOS SDK key used when initializing `GMSServices`.
    ///
    /// Resolution order:
    /// 1) `GOOGLE_MAPS_API_KEY` environment variable for local debugging or CI
    /// 2) `GoogleMapsAPIKey` (or legacy `GOOGLE_MAPS_API_KEY`) in Info.plist,
    ///    typically populated from `Config/GoogleMaps.xcconfig`
    static var googleMapsAPIKey: String {
        value(forAnyOf: ["GOOGLE_MAPS_API_KEY", "GoogleMapsAPIKey"])
    }

    static var hasGoogleMapsAPIKey: Bool {
        !googleMapsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static var googleMapsDiagnostics: KeyDiagnostics {
        KeyDiagnostics(
            environmentValue: ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"],
            plistValue: Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String
        )
    }

    /// Optional Census API key. Leave blank to use anonymous quota.
    static var censusAPIKey: String {
        value(forAnyOf: ["CENSUS_API_KEY", "CensusAPIKey"])
    }

    /// Enables the Firebase callable backend for shared Census logic when the app is configured.
    static var useFirebaseLociqBackend: Bool {
        booleanValue(forAnyOf: ["USE_FIREBASE_LOCIQ_BACKEND", "UseFirebaseLociqBackend"])
    }

    /// Region used by the deployed callable Functions backend.
    static var firebaseFunctionsRegion: String {
        value(forAnyOf: ["FIREBASE_FUNCTIONS_REGION", "FirebaseFunctionsRegion"]).ifEmpty("us-central1")
    }

    /// Email address allowed to use the shared Firebase backend.
    static var allowedGoogleEmail: String {
        value(forAnyOf: ["ALLOWED_GOOGLE_EMAIL", "AllowedGoogleEmail"]).ifEmpty("cmahlke@gmail.com")
    }

    private static func value(forAnyOf keys: [String]) -> String {
        for key in keys {
            let resolved = value(for: key)
            if !resolved.isEmpty {
                return resolved
            }
        }
        return ""
    }

    private static func booleanValue(forAnyOf keys: [String]) -> Bool {
        let normalized = value(forAnyOf: keys).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["1", "true", "yes", "on"].contains(normalized)
    }

    private static func value(for key: String) -> String {
        if let env = ProcessInfo.processInfo.environment[key], !env.isEmpty {
            return env
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !plistValue.isEmpty {
            return plistValue
        }

        // Fallback for device builds: a local xcconfig can be copied into the app bundle
        // during the build so the app still has a production-friendly local config source.
        if let bundledConfigValue = bundledXCConfigValue(for: key),
           !bundledConfigValue.isEmpty {
            return bundledConfigValue
        }

        return ""
    }

    private static func bundledXCConfigValue(for key: String) -> String? {
        let configMappings: [String: [(file: String, setting: String)]] = [
            "GOOGLE_MAPS_API_KEY": [("GoogleMaps", "GOOGLE_MAPS_API_KEY")],
            "GoogleMapsAPIKey": [("GoogleMaps", "GOOGLE_MAPS_API_KEY")],
            "CENSUS_API_KEY": [("Secrets", "CENSUS_API_KEY")],
            "CensusAPIKey": [("Secrets", "CENSUS_API_KEY")],
            "USE_FIREBASE_LOCIQ_BACKEND": [("Secrets", "USE_FIREBASE_LOCIQ_BACKEND")],
            "UseFirebaseLociqBackend": [("Secrets", "USE_FIREBASE_LOCIQ_BACKEND")],
            "ALLOWED_GOOGLE_EMAIL": [("Secrets", "ALLOWED_GOOGLE_EMAIL")],
            "AllowedGoogleEmail": [("Secrets", "ALLOWED_GOOGLE_EMAIL")],
            "FIREBASE_FUNCTIONS_REGION": [("Secrets", "FIREBASE_FUNCTIONS_REGION")],
            "FirebaseFunctionsRegion": [("Secrets", "FIREBASE_FUNCTIONS_REGION")]
        ]

        guard let candidates = configMappings[key] else {
            return nil
        }

        for candidate in candidates {
            guard let url = Bundle.main.url(forResource: candidate.file, withExtension: "xcconfig"),
                  let contents = try? String(contentsOf: url),
                  let value = parseXCConfig(contents: contents, setting: candidate.setting),
                  !value.isEmpty else {
                continue
            }

            return value
        }

        return nil
    }

    private static func parseXCConfig(contents: String, setting: String) -> String? {
        for rawLine in contents.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("//"), !line.hasPrefix("#include") else {
                continue
            }

            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  parts[0].trimmingCharacters(in: .whitespacesAndNewlines) == setting else {
                continue
            }

            return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
