//
//  LociqAuthSession.swift
//  Lociq
//
//  Google Sign-In backed Firebase auth flow for the shared callable backend.
//

import Combine
import Foundation
import os
import UIKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@MainActor
final class LociqAuthSession: ObservableObject {
    @Published private(set) var currentEmail: String?
    @Published private(set) var isBusy = false
    @Published private(set) var isSignedIn = false
    @Published var errorMessage: String?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.chrismahlke.lociq",
        category: "FirebaseAuth"
    )

    var allowedEmail: String {
        AppConfig.allowedGoogleEmail.lowercased()
    }

    func restoreIfPossible() async {
        guard AppConfig.useFirebaseLociqBackend else {
            clearState()
            return
        }

        #if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(GoogleSignIn)
        if let user = Auth.auth().currentUser {
            do {
                try applyAuthenticatedUser(user)
                return
            } catch {
                logger.error("Discarding invalid cached Firebase user: \(error.localizedDescription)")
                signOut()
            }
        }

        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else {
            clearState()
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let googleUser = try await restoreGoogleUser()
            let firebaseUser = try await signInToFirebase(with: googleUser)
            try applyAuthenticatedUser(firebaseUser)
        } catch {
            logger.error("Failed to restore Google sign-in: \(error.localizedDescription)")
            clearState()
        }
        #else
        clearState()
        #endif
    }

    func signInWithGoogle() async {
        guard AppConfig.useFirebaseLociqBackend else {
            errorMessage = "Firebase backend is disabled in local configuration."
            return
        }

        #if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(GoogleSignIn)
        guard FirebaseApp.app() != nil else {
            errorMessage = "Firebase is not configured in this build."
            return
        }

        guard let clientID = FirebaseApp.app()?.options.clientID, !clientID.isEmpty else {
            errorMessage = "Missing Firebase Google client configuration."
            return
        }

        guard let presentingViewController = Self.presentingViewController() else {
            errorMessage = "Unable to start Google Sign-In from the current window."
            return
        }

        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            let result = try await signIn(presentingViewController: presentingViewController)
            let firebaseUser = try await signInToFirebase(with: result.user)
            try applyAuthenticatedUser(firebaseUser)
        } catch let authError as AuthSessionError {
            signOut()
            errorMessage = authError.localizedDescription
        } catch {
            logger.error("Google sign-in failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        #else
        errorMessage = "FirebaseAuth and GoogleSignIn are not linked into this build."
        #endif
    }

    func signOut() {
        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
        } catch {
            logger.error("Firebase sign-out failed: \(error.localizedDescription)")
        }
        #endif

        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif

        clearState()
    }

    func handleOpenURL(_ url: URL) -> Bool {
        #if canImport(GoogleSignIn)
        return GIDSignIn.sharedInstance.handle(url)
        #else
        return false
        #endif
    }

    private func clearState() {
        currentEmail = nil
        errorMessage = nil
        isSignedIn = false
    }
}

#if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(GoogleSignIn)
@MainActor
private extension LociqAuthSession {
    enum AuthSessionError: LocalizedError {
        case missingGoogleTokens
        case unverifiedEmail
        case unauthorizedAccount(String)

        var errorDescription: String? {
            switch self {
            case .missingGoogleTokens:
                return "Google Sign-In did not return the tokens needed for Firebase Auth."
            case .unverifiedEmail:
                return "Firebase requires a verified Google email for this backend."
            case .unauthorizedAccount(let email):
                return "Only \(email) is allowed to use the shared Firebase backend."
            }
        }
    }

    func applyAuthenticatedUser(_ user: User) throws {
        let normalizedEmail = user.email?.lowercased() ?? ""

        guard user.isEmailVerified else {
            throw AuthSessionError.unverifiedEmail
        }

        guard normalizedEmail == allowedEmail else {
            throw AuthSessionError.unauthorizedAccount(AppConfig.allowedGoogleEmail)
        }

        currentEmail = normalizedEmail
        errorMessage = nil
        isSignedIn = true
    }

    func restoreGoogleUser() async throws -> GIDGoogleUser {
        try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let user else {
                    continuation.resume(throwing: AuthSessionError.missingGoogleTokens)
                    return
                }

                continuation.resume(returning: user)
            }
        }
    }

    func signIn(presentingViewController: UIViewController) async throws -> GIDSignInResult {
        try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result else {
                    continuation.resume(throwing: AuthSessionError.missingGoogleTokens)
                    return
                }

                continuation.resume(returning: result)
            }
        }
    }

    func signInToFirebase(with googleUser: GIDGoogleUser) async throws -> User {
        guard
            let idToken = googleUser.idToken?.tokenString,
            !idToken.isEmpty
        else {
            throw AuthSessionError.missingGoogleTokens
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: googleUser.accessToken.tokenString
        )

        return try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(with: credential) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let user = result?.user else {
                    continuation.resume(throwing: AuthSessionError.missingGoogleTokens)
                    return
                }

                continuation.resume(returning: user)
            }
        }
    }

    static func presentingViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController?
            .topMostPresentedViewController
    }
}

private extension UIViewController {
    var topMostPresentedViewController: UIViewController {
        if let presentedViewController = presentedViewController {
            return presentedViewController.topMostPresentedViewController
        }

        return self
    }
}
#endif
