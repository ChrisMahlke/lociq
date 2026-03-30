//
//  LociqApp.swift
//  Lociq
//
//  App entry point that configures third-party SDKs and boots the root SwiftUI scene.
//

import SwiftUI
import GoogleMaps
import os

@main
struct LociqApp: App {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "io.chrismahlke.lociq", category: "App")
    @StateObject private var schoolAccessController = SchoolAccessController()

    /// Initializes app-level SDK configuration before the first view appears.
    init() {
        configureGoogleMaps()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(schoolAccessController)
                .task {
                    await schoolAccessController.prepare()
                }
        }
    }

    private func configureGoogleMaps() {
        let apiKey = AppConfig.googleMapsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            let diagnostics = AppConfig.googleMapsDiagnostics.summary
            #if DEBUG
            Self.logger.error("""
            Missing GOOGLE_MAPS_API_KEY. Copy Config/GoogleMaps.example.xcconfig \
            to Config/GoogleMaps.xcconfig and add your real key locally.

            \(diagnostics)
            """)
            #else
            Self.logger.error("Missing Google Maps API key. The app will show the missing-key fallback view.")
            #endif

            return
        }

        GMSServices.provideAPIKey(apiKey)
    }
}
