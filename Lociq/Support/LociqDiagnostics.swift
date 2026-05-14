//
//  LociqDiagnostics.swift
//  Lociq
//
//  Records lightweight diagnostics for profile loading without changing the UI.
//
//  The app's UI intentionally avoids exposing technical failure detail. This
//  logger preserves those details for development and production diagnostics.
//

import Foundation
import OSLog

/// Centralizes lightweight diagnostics so production code can record failure context without changing the minimal UI.
///
/// Coordinates are logged as private values. Failure categories and stages are
/// public because they do not identify the user and are useful for aggregate
/// debugging.
enum LociqDiagnostics {
    /// OSLog logger dedicated to city profile loading.
    private static let logger = Logger(subsystem: "io.chrismahlke.lociq", category: "city-profile")

    /// Records a city-profile load failure with enough context to debug service behavior.
    ///
    /// Latitude and longitude are private to avoid exposing location in logs.
    static func cityProfileLoadFailed(_ failure: CityProfileLoadFailure, latitude: Double, longitude: Double) {
        logger.error(
            "City profile load failed: \(String(describing: failure), privacy: .public), latitude: \(latitude, privacy: .private), longitude: \(longitude, privacy: .private)"
        )
    }

    /// Records the elapsed time for a successful city-profile load.
    ///
    /// Duration is public because it is not user-identifying and helps tune
    /// timeout and retry behavior.
    static func cityProfileLoadCompleted(duration: TimeInterval) {
        logger.info("City profile load completed in \(duration, privacy: .public) seconds")
    }

    /// Records an intentionally non-fatal service failure that falls back to partial UI state.
    ///
    /// Partial failures are expected when one Census service succeeds and
    /// another is unavailable.
    static func cityProfilePartialLoadFailed(_ error: Error, stage: String) {
        logger.warning("City profile partial load failed at \(stage, privacy: .public): \(String(describing: error), privacy: .public)")
    }

    /// Records a local cache failure that should not interrupt the minimal UI.
    ///
    /// Cache failures are diagnostics only. The app can still attempt live
    /// loading or continue with currently visible data.
    static func cityProfileCacheFailed(_ error: Error, operation: String) {
        logger.warning("City profile cache \(operation, privacy: .public) failed: \(String(describing: error), privacy: .public)")
    }
}
