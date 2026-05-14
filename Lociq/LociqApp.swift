//
//  LociqApp.swift
//  Lociq
//
//  App entry point for the stripped-down SwiftUI experience.
//
//  The app has a single scene and a single root view. Service construction and
//  location activation are delegated to `ContentView` and its view model so the
//  entry point remains a pure SwiftUI shell.
//

import SwiftUI

@main
struct LociqApp: App {
    /// Declares the app's only window scene.
    ///
    /// LOC IQ does not expose secondary scenes or document windows. Keeping the
    /// entry point small makes launch behavior predictable across iPhone and
    /// iPad while the root view handles the minimal responsive surface.
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
