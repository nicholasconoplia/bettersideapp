//
//  SubscriptionManager.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import Foundation
import StoreKit

protocol SubscriptionManagerDelegate: AnyObject {
    func subscriptionManagerDidCompletePurchase(_ manager: SubscriptionManager)
}

enum GlowUpProduct: String, CaseIterable {
    case proMonthly = "com.glowup.pro.month"
    case proAnnual = "com.glowup.pro.annual"
    case proMonthlyExtended = "com.glowup.pro.monthlyextended"

    static var allIDs: [String] {
        GlowUpProduct.allCases.map(\.rawValue)
    }
}

enum SubscriptionError: Error, LocalizedError {
    case productUnavailable
    case failedVerification
    case restoreFailed(String)

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "The GlowUp subscription is currently unavailable."
        case .failedVerification:
            return "We could not verify the purchase. Please try again."
        case .restoreFailed(let message):
            return message
        }
    }
}

enum RestorePurchasesResult {
    case restored(count: Int)
    case nothingFound
}

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var products: [GlowUpProduct: Product] = [:]
    @Published private(set) var isSubscribed = false
    @Published private(set) var isLoading = false
    @Published private(set) var statusMessage: String?

    weak var delegate: SubscriptionManagerDelegate?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { await listenForTransactions() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func setDelegate(_ delegate: SubscriptionManagerDelegate) {
        self.delegate = delegate
    }

    // MARK: - Product Loading

    func refreshProductsIfNeeded() async {
        guard products.isEmpty else { return }
        await refreshProducts()
    }

    func refreshProducts() async {
        isLoading = true
        do {
            let storeProducts = try await Product.products(for: GlowUpProduct.allIDs)
            var map: [GlowUpProduct: Product] = [:]
            for product in storeProducts {
                if let mapped = GlowUpProduct(rawValue: product.id) {
                    map[mapped] = product
                }
            }
            products = map
            statusMessage = map.isEmpty ? "Subscriptions are currently unavailable." : nil
        } catch {
            statusMessage = "Unable to load products: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Entitlements

    func refreshEntitlementState() async {
        for product in GlowUpProduct.allCases {
            if let entitlement = await Transaction.currentEntitlement(for: product.rawValue),
               case .verified(let transaction) = entitlement,
               transaction.revocationDate == nil {
                isSubscribed = true
                print("✅ Active entitlement:", product.rawValue)
                return
            }
        }
        isSubscribed = false
        print("⚠️ No active entitlements found.")
    }

    // MARK: - Purchase

    func purchaseSubscription(for productID: GlowUpProduct) async throws {
        var product = products[productID]
        if product == nil {
            await refreshProducts()
            product = products[productID]
        }
        guard let product else { throw SubscriptionError.productUnavailable }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw SubscriptionError.failedVerification
            }
            await handleVerifiedTransaction(transaction)
            await refreshEntitlementState()
            await transaction.finish()
            delegate?.subscriptionManagerDidCompletePurchase(self)
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Transaction Updates

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update else { continue }
            await handleVerifiedTransaction(transaction)
            await transaction.finish()
        }
    }

    private func handleVerifiedTransaction(_ transaction: Transaction) async {
        guard transaction.revocationDate == nil else {
            isSubscribed = false
            return
        }
        isSubscribed = transaction.productType == .autoRenewable
    }

    // MARK: - Restore Purchases

    func restorePurchases() async throws -> RestorePurchasesResult {
        do {
            try await AppStore.sync()
        } catch {
            let message = "Restore failed: \(error.localizedDescription)"
            statusMessage = message
            throw SubscriptionError.restoreFailed(message)
        }

        // Wait briefly for StoreKit to update its local cache
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        var restoredProducts: [String] = []

        // Fetch all current entitlements
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                print("✅ Restored:", transaction.productID, "Env:", transaction.environment)
                restoredProducts.append(transaction.productID)
            }
        }

        await refreshEntitlementState()

        if restoredProducts.isEmpty {
            print("No purchases found for restore.")
            statusMessage = "No previous purchases were found on this Apple ID."
            return .nothingFound
        } else {
            print("Restored \(restoredProducts.count) product(s):", restoredProducts)
            statusMessage = "You're all set—your purchases have been restored."
            return .restored(count: restoredProducts.count)
        }
    }
}
