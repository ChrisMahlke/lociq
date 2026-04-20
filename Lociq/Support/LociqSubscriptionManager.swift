//
//  LociqSubscriptionManager.swift
//  Lociq
//
//  StoreKit 2 + Firebase entitlement sync for premium AI features.
//

import Foundation
import os
import StoreKit
import Combine

@MainActor
final class LociqSubscriptionManager: ObservableObject {
    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var isBusy = false
    @Published private(set) var isGeneratingBrief = false
    @Published private(set) var premiumStatus: PremiumAccessStatus?
    @Published var aiBriefError: String?
    @Published var latestAIBrief: String?
    @Published var purchaseError: String?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.chrismahlke.lociq",
        category: "Premium"
    )
    private let callableClient = FirebaseLociqCallableClient.makeDefaultIfAvailable()
    private var transactionUpdatesTask: Task<Void, Never>?
    private weak var authSession: LociqAuthSession?

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var hasActivePremium: Bool {
        premiumStatus?.active == true
    }

    func configure(authSession: LociqAuthSession) {
        self.authSession = authSession

        guard AppConfig.useFirebaseLociqBackend else { return }
        if transactionUpdatesTask == nil {
            transactionUpdatesTask = observeTransactionUpdates()
        }
    }

    func refresh() async {
        guard AppConfig.useFirebaseLociqBackend else {
            premiumStatus = nil
            availableProducts = []
            return
        }

        guard let authSession else { return }
        await authSession.ensureSignedIn()

        isBusy = true
        purchaseError = nil
        defer { isBusy = false }

        do {
            availableProducts = try await Product.products(for: AppConfig.lociqPremiumProductIDs)
                .sorted(by: { $0.displayPrice < $1.displayPrice })

            if let callableClient {
                let status = try await callableClient.fetchPremiumAccessStatus(
                    subscriptionAccountToken: authSession.subscriptionAccountToken
                )
                authSession.updateSubscriptionAccountToken(status.recommendedSubscriptionAccountToken)
                premiumStatus = status
            }
        } catch {
            logger.error("Failed to refresh premium status: \(error.localizedDescription)")
            purchaseError = error.localizedDescription
        }
    }

    func purchasePremium() async {
        guard let authSession else { return }
        await authSession.ensureSignedIn()

        if availableProducts.isEmpty {
            await refresh()
        }

        guard let product = availableProducts.first else {
            purchaseError = "No premium subscription products are available in this build."
            return
        }

        isBusy = true
        purchaseError = nil
        defer { isBusy = false }

        do {
            let accountToken = UUID(uuidString: authSession.subscriptionAccountToken) ?? UUID()
            let result = try await product.purchase(options: [.appAccountToken(accountToken)])

            switch result {
            case .pending:
                purchaseError = "Your subscription purchase is pending approval."
            case .userCancelled:
                purchaseError = nil
            case .success(let verification):
                let verified = try verifiedTransaction(from: verification)
                try await syncPremiumTransaction(jwsRepresentation: verification.jwsRepresentation)
                await verified.finish()
            @unknown default:
                purchaseError = "The App Store returned an unsupported purchase state."
            }
        } catch {
            logger.error("Premium purchase failed: \(error.localizedDescription)")
            purchaseError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        guard callableClient != nil else { return }

        isBusy = true
        purchaseError = nil
        defer { isBusy = false }

        do {
            try await AppStore.sync()

            for await entitlement in Transaction.currentEntitlements {
                _ = try verifiedTransaction(from: entitlement)
                try await syncPremiumTransaction(jwsRepresentation: entitlement.jwsRepresentation)
            }

            await refresh()
        } catch {
            logger.error("Restore purchases failed: \(error.localizedDescription)")
            purchaseError = error.localizedDescription
        }
    }

    func generateNeighborhoodBrief(
        areaTitle: String,
        areaSubtitle: String,
        zcta: String?,
        tractGeoid: String?,
        demographics: [String: Any]
    ) async {
        guard let callableClient else {
            aiBriefError = "Firebase callable client is unavailable in this build."
            return
        }

        guard hasActivePremium else {
            aiBriefError = "A premium subscription is required for AI features."
            return
        }

        isGeneratingBrief = true
        aiBriefError = nil
        defer { isGeneratingBrief = false }

        do {
            let response = try await callableClient.generatePremiumAreaBrief(
                areaTitle: areaTitle,
                areaSubtitle: areaSubtitle,
                zcta: zcta,
                tractGeoid: tractGeoid,
                demographics: demographics
            )
            latestAIBrief = response.text
        } catch {
            logger.error("Premium AI request failed: \(error.localizedDescription)")
            aiBriefError = error.localizedDescription
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await update in Transaction.updates {
                do {
                    let verified = try verifiedTransaction(from: update)
                    try await syncPremiumTransaction(jwsRepresentation: update.jwsRepresentation)
                    await verified.finish()
                } catch {
                    logger.error("Transaction update sync failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func syncPremiumTransaction(jwsRepresentation: String) async throws {
        guard let callableClient, let authSession else { return }

        let status = try await callableClient.syncPremiumSubscription(
            signedTransactionInfo: jwsRepresentation,
            subscriptionAccountToken: authSession.subscriptionAccountToken
        )

        authSession.updateSubscriptionAccountToken(status.recommendedSubscriptionAccountToken)
        premiumStatus = status
    }

    private func verifiedTransaction(
        from verification: VerificationResult<Transaction>
    ) throws -> Transaction {
        switch verification {
        case .verified(let transaction):
            return transaction
        case .unverified(_, let error):
            throw error
        }
    }
}
