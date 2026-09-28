//
//  LociqWatchApp.swift
//  LociqWatch
//
//  App entry point for LOC IQ on Apple Watch.
//
//  The watch app is independent: it finds the watch's own location and loads
//  Census data with the same pipeline and state machine as the iPhone app, so
//  it works without the iPhone nearby.
//

import SwiftUI

@main
struct LociqWatchApp: App {
    /// Declares the app's only scene.
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}
