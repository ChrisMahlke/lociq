//
//  DebugLocationOverride.swift
//  Lociq
//
//  Provides launch-argument location overrides for deterministic local testing.
//

import CoreLocation
import Foundation

struct DebugLocationOverride {
    let coordinate: CLLocationCoordinate2D

    /// Reads launch arguments and environment flags for deterministic city testing.
    static var current: DebugLocationOverride? {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment

        if arguments.contains("--lociq-debug-cambridge")
            || environment["LOCIQ_DEBUG_CITY"]?.lowercased() == "cambridge" {
            return DebugLocationOverride(
                coordinate: CLLocationCoordinate2D(latitude: 42.3736, longitude: -71.1056)
            )
        }

        return nil
    }
}
