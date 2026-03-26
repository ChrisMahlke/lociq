//
//  LociqApp.swift
//  Lociq
//
//  App entry point that configures third-party SDKs and boots the root SwiftUI scene.
//

import SwiftUI
import GoogleMaps

@main
struct LociqApp: App {
    /// Initializes app-level SDK configuration before the first view appears.
    init() {
        configureGoogleMaps()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func configureGoogleMaps() {
        let apiKey = AppConfig.googleMapsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            let diagnostics = AppConfig.googleMapsDiagnostics.summary
            let message = """
            Missing GOOGLE_MAPS_API_KEY. Copy Config/GoogleMaps.example.xcconfig \
            to Config/GoogleMaps.xcconfig and add your real key locally.

            \(diagnostics)
            """

            #if DEBUG
            print(message)
            #else
            print(message)
            #endif

            return
        }

        GMSServices.provideAPIKey(apiKey)
    }
}
