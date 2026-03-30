import Combine
import Foundation
import StoreKit

@MainActor
final class SchoolAccessController: ObservableObject {
    static let productID = "io.chrismahlke.lociq.schools.unlock"
    #if DEBUG
    private static let debugOverrideDefaultsKey = "debug.schoolAccessOverride"
    #endif

    @Published private(set) var product: Product?
    @Published private(set) var hasUnlockedSchoolData = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isLoadingProducts = false
    @Published var purchaseMessage: String?
    #if DEBUG
    @Published private(set) var debugOverride: DebugOverride = .live
    #endif

    private var updatesTask: Task<Void, Never>?

    init() {
        #if DEBUG
        if let stored = UserDefaults.standard.string(forKey: Self.debugOverrideDefaultsKey),
           let value = DebugOverride(rawValue: stored) {
            debugOverride = value
        }
        #endif
        updatesTask = observeTransactionUpdates()
    }

    deinit {
        updatesTask?.cancel()
    }

    func prepare() async {
        await loadProduct()
        await refreshEntitlements()
    }

    func loadProduct() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            purchaseMessage = "Unable to load purchase options right now."
        }
    }

    func purchaseSchoolsUnlock() async {
        guard !isPurchasing else { return }

        if product == nil {
            await loadProduct()
        }

        guard let product else {
            purchaseMessage = "Purchase option is not available yet."
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try verify(verification)
                hasUnlockedSchoolData = true
                purchaseMessage = nil
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                purchaseMessage = "Purchase is pending approval."
            @unknown default:
                purchaseMessage = "Purchase could not be completed."
            }
        } catch {
            purchaseMessage = "Purchase could not be completed."
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseMessage = "Unable to restore purchases right now."
        }
    }

    private func refreshEntitlements() async {
        var unlocked = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.productID else { continue }
            guard transaction.revocationDate == nil else { continue }
            unlocked = true
        }

        applyEffectiveAccess(storeKitUnlocked: unlocked)
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(transactionResult: result)
            }
        }
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = transactionResult else { return }

        if transaction.productID == Self.productID, transaction.revocationDate == nil {
            applyEffectiveAccess(storeKitUnlocked: true)
            purchaseMessage = nil
        } else if transaction.productID == Self.productID, transaction.revocationDate != nil {
            applyEffectiveAccess(storeKitUnlocked: false)
        }
    }

    private func applyEffectiveAccess(storeKitUnlocked: Bool) {
        #if DEBUG
        switch debugOverride {
        case .live:
            hasUnlockedSchoolData = storeKitUnlocked
        case .forceLocked:
            hasUnlockedSchoolData = false
        case .forceUnlocked:
            hasUnlockedSchoolData = true
        }
        #else
        hasUnlockedSchoolData = storeKitUnlocked
        #endif
    }

    #if DEBUG
    func setDebugOverride(_ override: DebugOverride) {
        debugOverride = override
        UserDefaults.standard.set(override.rawValue, forKey: Self.debugOverrideDefaultsKey)
        Task {
            await refreshEntitlements()
        }
    }
    #endif

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let signedType):
            return signedType
        case .unverified:
            throw SchoolAccessError.failedVerification
        }
    }
}

private enum SchoolAccessError: Error {
    case failedVerification
}

#if DEBUG
extension SchoolAccessController {
    enum DebugOverride: String, CaseIterable, Identifiable {
        case live
        case forceLocked
        case forceUnlocked

        var id: String { rawValue }

        var title: String {
            switch self {
            case .live:
                return "Use StoreKit"
            case .forceLocked:
                return "Force Locked"
            case .forceUnlocked:
                return "Force Unlocked"
            }
        }
    }
}
#endif
