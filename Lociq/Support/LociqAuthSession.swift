//
//  LociqAuthSession.swift
//  Lociq
//
//  Silent Firebase auth for all users, with optional Sign in with Apple linking.
//

import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import os
import Security
import UIKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

@MainActor
final class LociqAuthSession: NSObject, ObservableObject {
    @Published private(set) var currentEmail: String?
    @Published private(set) var currentUserID: String?
    @Published private(set) var isAnonymous = true
    @Published private(set) var isBusy = false
    @Published private(set) var isLinkedAppleAccount = false
    @Published private(set) var isSignedIn = false
    @Published var errorMessage: String?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.chrismahlke.lociq",
        category: "FirebaseAuth"
    )
    private let subscriptionAccountTokenKey = "io.chrismahlke.lociq.subscriptionAccountToken"

    var subscriptionAccountToken: String {
        if let existing = UserDefaults.standard.string(forKey: subscriptionAccountTokenKey),
           !existing.isEmpty {
            return existing
        }

        let created = UUID().uuidString.lowercased()
        UserDefaults.standard.set(created, forKey: subscriptionAccountTokenKey)
        return created
    }

    func updateSubscriptionAccountToken(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.set(trimmed, forKey: subscriptionAccountTokenKey)
    }

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

    func linkWithApple() async {
        guard AppConfig.useFirebaseLociqBackend else {
            errorMessage = "Firebase backend is disabled in local configuration."
            return
        }

        #if canImport(FirebaseAuth) && canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else {
            errorMessage = "Firebase is not configured in this build."
            return
        }

        let rawNonce = Self.randomNonce()

        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            let authorization = try await AppleSignInCoordinator().performSignIn(
                requestedScopes: [.email, .fullName],
                nonce: Self.sha256(rawNonce)
            )

            guard
                let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let identityToken = appleCredential.identityToken,
                let identityTokenString = String(data: identityToken, encoding: .utf8)
            else {
                throw AuthSessionError.invalidAppleCredential
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: identityTokenString,
                rawNonce: rawNonce,
                fullName: appleCredential.fullName
            )

            let authenticatedUser: User
            if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
                authenticatedUser = try await link(currentUser: currentUser, credential: firebaseCredential)
            } else {
                authenticatedUser = try await signIn(with: firebaseCredential)
            }

            applyAuthenticatedUser(authenticatedUser)
        } catch is CancellationError {
            errorMessage = nil
        } catch {
            logger.error("Sign in with Apple failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        #else
        errorMessage = "FirebaseAuth is not linked into this build."
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
        isLinkedAppleAccount = false
        isSignedIn = false
    }
}

#if canImport(FirebaseAuth) && canImport(FirebaseCore)
@MainActor
private extension LociqAuthSession {
    enum AuthSessionError: LocalizedError {
        case invalidAppleCredential

        var errorDescription: String? {
            switch self {
            case .invalidAppleCredential:
                return "Sign in with Apple did not return a valid identity token."
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
                        continuation.resume(throwing: AuthSessionError.invalidAppleCredential)
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

    func link(currentUser: User, credential: AuthCredential) async throws -> User {
        try await withCheckedThrowingContinuation { continuation in
            currentUser.link(with: credential) { authResult, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let user = authResult?.user else {
                    continuation.resume(throwing: AuthSessionError.invalidAppleCredential)
                    return
                }

                continuation.resume(returning: user)
            }
        }
    }

    func signIn(with credential: AuthCredential) async throws -> User {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let user = authResult?.user else {
                    continuation.resume(throwing: AuthSessionError.invalidAppleCredential)
                    return
                }

                continuation.resume(returning: user)
            }
        }
    }

    func applyAuthenticatedUser(_ user: User) {
        currentEmail = user.email
        currentUserID = user.uid
        errorMessage = nil
        isAnonymous = user.isAnonymous
        isLinkedAppleAccount = user.providerData.contains(where: { $0.providerID == "apple.com" })
        isSignedIn = true
    }

    static func randomNonce(length: Int = 32) -> String {
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)

        while result.count < length {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            guard status == errSecSuccess else {
                fatalError("Unable to generate random nonce. OSStatus \(status)")
            }

            randomBytes.forEach { byte in
                if result.count < length {
                    result.append(charset[Int(byte) % charset.count])
                }
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
private final class AppleSignInCoordinator: NSObject {
    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    func performSignIn(
        requestedScopes: [ASAuthorization.Scope],
        nonce: String
    ) async throws -> ASAuthorization {
        guard continuation == nil else {
            throw CancellationError()
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = requestedScopes
            request.nonce = nonce

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        continuation?.resume(returning: authorization)
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
#endif
