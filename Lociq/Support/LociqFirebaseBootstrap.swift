//
//  LociqFirebaseBootstrap.swift
//  Lociq
//
//  Optional Firebase bootstrap for the shared callable backend.
//

import Foundation
import os

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

enum LociqFirebaseBootstrap {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.chrismahlke.lociq",
        category: "Firebase"
    )

    static func configureIfAvailable() {
        guard AppConfig.useFirebaseLociqBackend else {
            return
        }

        #if canImport(FirebaseCore)
        guard FirebaseApp.app() == nil else {
            return
        }

        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            logger.error("""
            Firebase backend is enabled but GoogleService-Info.plist is missing from the app bundle.
            Copy Config/GoogleService-Info.plist into the app resources before enabling the callable backend.
            """)
            return
        }

        #if canImport(FirebaseAppCheck)
        AppCheck.setAppCheckProviderFactory(LociqAppCheckProviderFactory())
        #endif

        #if DEBUG
        FirebaseConfiguration.shared.setLoggerLevel(.debug)
        #endif

        FirebaseApp.configure()
        logger.info("Configured Firebase for the callable Census backend.")
        #else
        logger.error("""
        Firebase backend is enabled but Firebase Apple SDKs are not linked in this build.
        Add FirebaseCore, FirebaseFunctions, and FirebaseAppCheck before enabling the callable backend.
        """)
        #endif
    }
}

#if canImport(FirebaseCore) && canImport(FirebaseAppCheck)
private final class LociqAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
        #if targetEnvironment(simulator)
        return AppCheckDebugProvider(app: app)
        #else
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        } else {
            return DeviceCheckProvider(app: app)
        }
        #endif
    }
}
#endif
