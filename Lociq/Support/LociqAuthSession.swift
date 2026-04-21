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
            errorMessage = nil
            clearState()
            return
        }

        #if canImport(FirebaseAuth) && canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else {
            errorMessage = "Firebase is not configured in this build."
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
        errorMessage = "FirebaseAuth is not linked into this build."
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

    func handleOpenURL(_ url: URL) -> Bool {
        _ = url
        return false
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
            errorMessage = error.localizedDescription
            clearState()
        }
    }

    func applyAuthenticatedUser(_ user: User) {
        currentEmail = user.email
        currentUserID = user.uid
        errorMessage = nil
        isAnonymous = user.isAnonymous
        isSignedIn = true
    }
}
#endif
