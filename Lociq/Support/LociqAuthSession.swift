//
//  LociqAuthSession.swift
//  Lociq
//
//  Silent Firebase auth for all users of the shared backend.
//

import Combine
import Foundation
import os

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

@MainActor
final class LociqAuthSession: ObservableObject {
    @Published private(set) var currentEmail: String?
    @Published private(set) var currentUserID: String?
    @Published private(set) var isAnonymous = true
    @Published private(set) var isBusy = false
    @Published private(set) var isSignedIn = false
    @Published var errorMessage: String?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.chrismahlke.lociq",
        category: "FirebaseAuth"
    )

    func restoreIfPossible() async {
        guard AppConfig.useFirebaseLociqBackend else {
            LociqFirebaseRuntime.clearDisableReason()
            errorMessage = nil
            clearState()
            return
        }

        #if canImport(FirebaseAuth) && canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else {
            let message = "Firebase is not configured in this build."
            LociqFirebaseRuntime.disableForCurrentSession(reason: message)
            errorMessage = message
            clearState()
            return
        }

        if let user = Auth.auth().currentUser {
            applyAuthenticatedUser(user)
            return
        }

        await signInAnonymouslyIfNeeded()
        #else
        clearState()
        let message = "FirebaseAuth is not linked into this build."
        LociqFirebaseRuntime.disableForCurrentSession(reason: message)
        errorMessage = message
        #endif
    }

    func ensureSignedIn() async {
        guard AppConfig.useFirebaseLociqBackend else { return }

        #if canImport(FirebaseAuth)
        if let user = Auth.auth().currentUser {
            applyAuthenticatedUser(user)
            return
        }
        await signInAnonymouslyIfNeeded()
        #endif
    }

    func resetSession() async {
        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
        } catch {
            logger.error("Firebase sign-out failed: \(error.localizedDescription)")
        }
        #endif

        clearState()
        errorMessage = nil
        await signInAnonymouslyIfNeeded()
    }

    private func clearState() {
        currentEmail = nil
        currentUserID = nil
        isAnonymous = true
        isSignedIn = false
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

    func signInAnonymouslyIfNeeded() async {
        guard AppConfig.useFirebaseLociqBackend else {
            clearState()
            return
        }

        if let currentUser = Auth.auth().currentUser {
            applyAuthenticatedUser(currentUser)
            return
        }

        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

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
            errorMessage = message
            clearState()
        }
    }

    func applyAuthenticatedUser(_ user: User) {
        LociqFirebaseRuntime.clearDisableReason()
        currentEmail = user.email
        currentUserID = user.uid
        errorMessage = nil
        isAnonymous = user.isAnonymous
        isSignedIn = true
    }

    func userFacingAuthErrorMessage(for error: Error) -> String {
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
