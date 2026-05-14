//
//  LociqDiagnostics.swift
//  Lociq
//
//  Records lightweight diagnostics for profile loading without changing the UI.
//

import Foundation
import OSLog

/// Centralizes lightweight diagnostics so production code can record failure context without changing the minimal UI.
enum LociqDiagnostics {
    private static let logger = Logger(subsystem: "io.chrismahlke.lociq", category: "city-profile")

    /// Records a city-profile load failure with enough context to debug service behavior.
    static func cityProfileLoadFailed(_ failure: CityProfileLoadFailure, latitude: Double, longitude: Double) {
        logger.error(
            "City profile load failed: \(String(describing: failure), privacy: .public), latitude: \(latitude, privacy: .private), longitude: \(longitude, privacy: .private)"
        )
    }

    /// Records the elapsed time for a successful city-profile load.
    static func cityProfileLoadCompleted(duration: TimeInterval) {
        logger.info("City profile load completed in \(duration, privacy: .public) seconds")
    }

    /// Records an intentionally non-fatal service failure that falls back to partial UI state.
    static func cityProfilePartialLoadFailed(_ error: Error, stage: String) {
        logger.warning("City profile partial load failed at \(stage, privacy: .public): \(String(describing: error), privacy: .public)")
    }

    /// Records a local cache failure that should not interrupt the minimal UI.
    static func cityProfileCacheFailed(_ error: Error, operation: String) {
        logger.warning("City profile cache \(operation, privacy: .public) failed: \(String(describing: error), privacy: .public)")
    }
}
