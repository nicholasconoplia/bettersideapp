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

    static var allIDs: [String] {
        GlowUpProduct.allCases.map(\.rawValue)
    }
}

enum SubscriptionError: Error, LocalizedError {
    case productUnavailable
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "The BetterSide subscription is currently unavailable."
        case .failedVerification:
            return "We could not verify the purchase. Please try again."
        }
    }
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

    func refreshEntitlementState() async {
        for product in GlowUpProduct.allCases {
            if let entitlement = await Transaction.currentEntitlement(for: product.rawValue) {
                switch entitlement {
                case .verified(let transaction) where transaction.revocationDate == nil:
                    isSubscribed = true
                    return
                default:
                    continue
                }
            }
        }
        isSubscribed = false
    }

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

    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        try await AppStore.sync()
        await refreshEntitlementState()
    }
}
