//
//  DebugLocationOverride.swift
//  Lociq
//
//  Provides launch-argument location overrides for deterministic local testing.
//
//  The override is intentionally narrow and explicit. It gives developers a
//  repeatable Cambridge, Massachusetts profile without adding visible test UI
//  or changing production location behavior.
//

import CoreLocation
import Foundation

/// Optional coordinate override derived from launch arguments or environment.
struct DebugLocationOverride {
    /// Coordinate used instead of Core Location when the override is active.
    let coordinate: CLLocationCoordinate2D

    /// Reads launch arguments and environment flags for deterministic city testing.
    ///
    /// Supported inputs:
    /// `--lociq-debug-cambridge` as a launch argument, or
    /// `LOCIQ_DEBUG_CITY=cambridge` as an environment variable.
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
