//
//  LociqAuthSession.swift
//  Lociq
//
//  Anonymous Firebase auth bootstrap for the shared callable backend.
//

import Foundation
import os

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

@MainActor
enum LociqAuthSession {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.chrismahlke.lociq",
        category: "FirebaseAuth"
    )

    static func restoreIfPossible() async {
        guard AppConfig.useFirebaseLociqBackend else {
            LociqFirebaseRuntime.clearDisableReason()
            return
        }

        #if canImport(FirebaseAuth) && canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else {
            let message = "Firebase is not configured in this build."
            LociqFirebaseRuntime.disableForCurrentSession(reason: message)
            return
        }

        if let user = Auth.auth().currentUser {
            applyAuthenticatedUser(user)
            return
        }

        await signInAnonymouslyIfNeeded()
        #else
        let message = "FirebaseAuth is not linked into this build."
        LociqFirebaseRuntime.disableForCurrentSession(reason: message)
        #endif
    }
}

#if canImport(FirebaseAuth) && canImport(FirebaseCore)
@MainActor
private extension LociqAuthSession {
    enum AuthSessionError: LocalizedError {
        case missingAuthResult

        var errorDescription: String? {
            switch self {
            case .missingAuthResult:
                return "Firebase did not return a user for this session."
            }
        }
    }

    static func signInAnonymouslyIfNeeded() async {
        guard AppConfig.useFirebaseLociqBackend else {
            LociqFirebaseRuntime.clearDisableReason()
            return
        }

        if let currentUser = Auth.auth().currentUser {
            applyAuthenticatedUser(currentUser)
            return
        }

        do {
            let result: AuthDataResult = try await withCheckedThrowingContinuation { continuation in
                Auth.auth().signInAnonymously { authResult, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let authResult else {
                        continuation.resume(throwing: AuthSessionError.missingAuthResult)
                        return
                    }

                    continuation.resume(returning: authResult)
                }
            }

            applyAuthenticatedUser(result.user)
        } catch {
            logger.error("Anonymous Firebase sign-in failed: \(error.localizedDescription)")
            let message = userFacingAuthErrorMessage(for: error)
            LociqFirebaseRuntime.disableForCurrentSession(reason: message)
        }
    }

    static func applyAuthenticatedUser(_ user: User) {
        LociqFirebaseRuntime.clearDisableReason()
        logger.debug("Firebase auth ready for user \(user.uid, privacy: .private(mask: .hash))")
    }

    static func userFacingAuthErrorMessage(for error: Error) -> String {
        let nsError = error as NSError

        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code) else {
            return error.localizedDescription
        }

        switch code {
        case .operationNotAllowed:
            return "Anonymous Firebase Auth is not enabled for this project. Enable Anonymous in Firebase Authentication or turn off USE_FIREBASE_LOCIQ_BACKEND."
        case .appNotAuthorized:
            return "This iOS app is not authorized for the configured Firebase project. Verify that GoogleService-Info.plist matches bundle ID io.chrismahlke.lociq."
        case .invalidAPIKey:
            return "The Firebase app configuration is invalid. Verify GoogleService-Info.plist and rebuild the app."
        case .networkError:
            return "Firebase could not reach the network to start the shared backend session."
        case .internalError:
            return "Firebase Auth returned an internal error while starting the shared backend session. This usually means the Firebase Authentication project is missing Anonymous sign-in or the iOS app configuration does not match the project."
        default:
            return error.localizedDescription
        }
    }
}
#endif
