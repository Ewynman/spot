import Foundation
import StoreKit
import UIKit

/// Thrown when StoreKit returns a `Product.PurchaseResult` case this app was not built to handle (e.g. new API in a future OS).
enum SubscriptionPurchaseError: LocalizedError {
    case unknownPurchaseOutcome
    case nonProTransaction
    case subscriptionLinkedToDifferentAccount

    var errorDescription: String? {
        switch self {
        case .unknownPurchaseOutcome:
            return "Unexpected purchase result from the App Store. Update Spot or try again, and contact support if it continues."
        case .nonProTransaction:
            return "Unable to confirm Spot Pro. Please try again."
        case .subscriptionLinkedToDifferentAccount:
            return "This subscription is linked to another Spot account."
        }
    }
}

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    private init() {}

    @Published var isPurchasing: Bool = false
    @Published var isRestoring: Bool = false
    @Published var hasProduct: Bool = false
    @Published var productLoadError: String?

    static let userFacingProductLoadError = "Unable to load plan. Please try again."

    let productIds = SpotProProducts.all

    private var cachedProduct: Product?
    private var transactionUpdatesTask: Task<Void, Never>?

    func loadProduct() async throws -> Product {
        if let p = cachedProduct { return p }
        SpotLogger.log(SubscriptionManagerLogs.productLoadStarted, details: ["ids": Array(productIds).sorted()])
        let products = try await Product.products(for: productIds)
        guard let product = products.first(where: { $0.id == SpotProProducts.yearly }) else {
            SpotLogger.log(
                SubscriptionManagerLogs.noMatchingProduct,
                details: [
                    "requestedIDs": Array(productIds).sorted(),
                    "returnedIDs": products.map(\.id).sorted()
                ]
            )
            let message = Self.userFacingProductLoadError
            hasProduct = false
            cachedProduct = nil
            productLoadError = message
            throw NSError(domain: "StoreKit", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        cachedProduct = product
        hasProduct = true
        productLoadError = nil
        SpotLogger.log(SubscriptionManagerLogs.productLoadSucceeded, details: ["productID": product.id])
        return product
    }

    func ensureProductLoaded() async {
        if cachedProduct != nil { hasProduct = true; return }
        do {
            _ = try await loadProduct()
        } catch {
            hasProduct = false
            if productLoadError == nil {
                productLoadError = error.localizedDescription
            }
            SpotLogger.log(SubscriptionManagerLogs.ensureProductLoadedFailed, details: ["error": error.localizedDescription])
        }
    }

    /// Resets cached product-load state so the next `ensureProductLoaded()`
    /// call performs a fresh `Product.products(for:)` request. Used by the
    /// paywall "Try Again" button to recover from a transient StoreKit
    /// failure without rebuilding the entire view.
    func resetProductLoadStateForRetry() {
        cachedProduct = nil
        hasProduct = false
        productLoadError = nil
    }

    enum PurchaseProResult: Sendable {
        case purchased(expirationDate: Date?)
        case pending
        case userCancelled
    }

    enum EntitlementRefreshResult: Sendable, Equatable {
        case active(expirationDate: Date?)
        case linkedToDifferentAccount
        case inactive

        var isActive: Bool {
            if case .active = self { return true }
            return false
        }
    }

    /// Starts the App Store purchase flow. Returns whether a verified purchase completed on-device.
    func purchasePro(appAccountToken: UUID) async throws -> PurchaseProResult {
        isPurchasing = true
        defer { isPurchasing = false }
        let product = try await loadProduct()
        let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            guard isActiveProTransaction(transaction) else {
                await transaction.finish()
                throw SubscriptionPurchaseError.nonProTransaction
            }
            guard transaction.appAccountToken == appAccountToken else {
                await transaction.finish()
                SpotLogger.log(
                    SubscriptionManagerLogs.entitlementLinkedToDifferentAccount,
                    details: ["productID": transaction.productID]
                )
                throw SubscriptionPurchaseError.subscriptionLinkedToDifferentAccount
            }
            let expirationDate = transaction.expirationDate
            await transaction.finish()
            return .purchased(expirationDate: expirationDate)
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            SpotLogger.log(SubscriptionManagerLogs.unhandledPurchaseResult, details: ["hint": "Future StoreKit may add cases; update SubscriptionManager.purchasePro"])
            throw SubscriptionPurchaseError.unknownPurchaseOutcome
        }
    }

    func restorePurchases() async throws {
        isRestoring = true
        defer { isRestoring = false }
        try await AppStore.sync()
        SpotLogger.log(SubscriptionManagerLogs.restoreSyncCompleted)
    }

    /// Start listening for StoreKit transaction updates for the app lifetime.
    /// This avoids missing successful purchases that complete outside the immediate purchase flow.
    ///
    /// Uses a `Task` (not `detached`) so the handler inherits `@MainActor` and may safely capture
    /// `AuthViewModel` or other UI-bound state without `@Sendable` restrictions.
    func startTransactionUpdatesListener(
        onEntitlementChanged: ((UUID?, Date?) async -> Void)? = nil
    ) {
        guard transactionUpdatesTask == nil else { return }
        transactionUpdatesTask = Task(priority: .background) {
            for await update in Transaction.updates {
                do {
                    let transaction = try Self.checkVerifiedStatic(update)
                    defer { Task { await transaction.finish() } }

                    guard Self.isActiveProTransactionStatic(transaction) else { continue }
                    await onEntitlementChanged?(transaction.appAccountToken, transaction.expirationDate)
                } catch {
                    continue
                }
            }
        }
    }

    func refreshEntitlement(for appAccountToken: UUID) async -> EntitlementRefreshResult {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               isActiveProTransaction(transaction) {
                if transaction.appAccountToken != appAccountToken {
                    SpotLogger.log(
                        SubscriptionManagerLogs.entitlementLinkedToDifferentAccount,
                        details: ["productID": transaction.productID]
                    )
                    return .linkedToDifferentAccount
                }
                SpotLogger.log(
                    SubscriptionManagerLogs.entitlementRefreshFoundPro,
                    details: ["productID": transaction.productID]
                )
                return .active(expirationDate: transaction.expirationDate)
            }
        }
        SpotLogger.log(SubscriptionManagerLogs.entitlementRefreshNoPro)
        return .inactive
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "Unverified transaction", code: 0)
        case .verified(let safe):
            return safe
        }
    }

    private static func checkVerifiedStatic<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "Unverified transaction", code: 0)
        case .verified(let safe):
            return safe
        }
    }

    private func isActiveProTransaction(_ transaction: Transaction) -> Bool {
        Self.isActiveProTransactionStatic(transaction)
    }

    private static func isActiveProTransactionStatic(_ transaction: Transaction) -> Bool {
        guard ProEntitlementChecker(proProductIDs: SpotProProducts.all).grantsPro(forProductID: transaction.productID) else {
            return false
        }
        if transaction.revocationDate != nil || transaction.isUpgraded {
            return false
        }
        if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
            return false
        }
        return true
    }

    func manageSubscriptions() async throws {
        // Find an active UIWindowScene and present Apple's manage subscriptions sheet
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            throw NSError(domain: "NoActiveScene", code: 0, userInfo: [NSLocalizedDescriptionKey: "No active scene to present subscriptions"])
        }
        try await AppStore.showManageSubscriptions(in: scene)
    }
}
