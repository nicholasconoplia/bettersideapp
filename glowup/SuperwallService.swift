//
//  SuperwallService.swift
//  glowup
//
//  Lightweight wrapper around Superwall to keep our codebase decoupled.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if canImport(SuperwallKit)
import SuperwallKit
#endif

final class SuperwallService: ObservableObject {
    static let shared = SuperwallService()

    private init() {}

    private(set) var isAvailable = false
    private var configurationFlag = AtomicFlag()
    private weak var attachedSubscriptionManager: SubscriptionManager?

    func attachSubscriptionManager(_ manager: SubscriptionManager) {
        attachedSubscriptionManager = manager
    }

    func configureIfPossible() {
        guard !configurationFlag.isSet else { return }
        isAvailable = false
        guard let apiKey = Secrets.superwallApiKey, !apiKey.isEmpty else {
            print("[SuperwallService] No SUPERWALL_API_KEY found. Skipping configuration.")
            configurationFlag.set()
            return
        }

        #if canImport(SuperwallKit)
        // Configure only once
        let options = SuperwallOptions()
        options.logging.level = .debug
        Superwall.configure(apiKey: apiKey, options: options)
        print("[SuperwallService] Superwall configured (logging: debug)")
        isAvailable = true
        #else
        print("[SuperwallService] SuperwallKit is not available in this build.")
        #endif
        configurationFlag.set()
    }

    func registerEvent(_ name: String) {
        #if canImport(SuperwallKit)
        // If a paywall is already on screen, defer until it dismisses.
        if Superwall.shared.isPaywallPresented {
            print("[SuperwallService] Deferring placement due to active paywall: \(name)")
            #if canImport(UIKit)
            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                if let token { NotificationCenter.default.removeObserver(token) }
                Superwall.shared.register(placement: name)
                print("[SuperwallService] (Deferred) Event '\(name)' registered after dismissal")
                Task { await self.refreshEntitlementsAfterPresentation() }
            }
            #endif
            return
        }
        Superwall.shared.register(placement: name)
        print("[SuperwallService] Event '\(name)' registered (isPaywallPresented=\(Superwall.shared.isPaywallPresented))")
        Task { await refreshEntitlementsAfterPresentation() }
        #endif
    }

    /// Attempts to present the default Superwall paywall mapped from the dashboard.
    /// Returns true if a paywall was presented, false otherwise (e.g., not found or SDK missing).
    func presentDefaultPaywall() async -> Bool {
        #if canImport(SuperwallKit)
        // Newer SDKs renamed 'event' to 'placement' and handle presentation internally.
        Superwall.shared.register(placement: "subscription_paywall")
        print("[SuperwallService] Requested paywall for placement 'subscription_paywall' (isPaywallPresented=\(Superwall.shared.isPaywallPresented))")
        Task { await refreshEntitlementsAfterPresentation() }
        return true
        #else
        return false
        #endif
    }

    // MARK: - Sequenced Presentation Helpers

    /// Presents a placement and awaits dismissal by observing when the app becomes active again.
    /// Falls back after a timeout so the UI never hangs if there's no rule match.
    @discardableResult
    func presentAndAwaitDismissal(_ placement: String, timeoutSeconds: UInt64 = 2) async -> Bool {
        var didAttemptPresentation = false
        #if canImport(SuperwallKit)
        print("[SuperwallService] Presenting placement: \(placement) (isPaywallPresented=\(Superwall.shared.isPaywallPresented))")
        Superwall.shared.register(placement: placement)
        didAttemptPresentation = true
        #else
        print("[SuperwallService] SuperwallKit unavailable; skipping placement: \(placement)")
        #endif

        #if canImport(UIKit)
        var completedBy = "timeout"
        await withTaskGroup(of: (String).self) { group in
            group.addTask {
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    var token: NSObjectProtocol?
                    token = NotificationCenter.default.addObserver(
                        forName: UIApplication.didBecomeActiveNotification,
                        object: nil,
                        queue: .main
                    ) { _ in
                        if let token { NotificationCenter.default.removeObserver(token) }
                        cont.resume()
                    }
                }
                return "didBecomeActive"
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                return "timeout"
            }
            if let which = await group.next() {
                completedBy = which
            }
            group.cancelAll()
        }
        print("[SuperwallService] Await finished for placement: \(placement) via=\(completedBy) (isPaywallPresented=\(Superwall.shared.isPaywallPresented))")
        // Allow UI to settle briefly
        try? await Task.sleep(nanoseconds: 200_000_000)
        #endif

        return didAttemptPresentation
    }

    /// Presents a sequence of placements one after another, awaiting dismissal between each.
    func presentSequence(_ placements: [String], timeoutSeconds: UInt64 = 10) async {
        for key in placements {
            _ = await presentAndAwaitDismissal(key, timeoutSeconds: timeoutSeconds)
        }
    }

    @MainActor
    private func refreshEntitlementsAfterPresentation() async {
        #if canImport(UIKit)
        // Wait until app is active again after potential purchase flow.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                if let token { NotificationCenter.default.removeObserver(token) }
                cont.resume()
            }
        }
        #endif
        // Small grace to let SDK settle, then refresh entitlements.
        try? await Task.sleep(nanoseconds: 200_000_000)
        await attachedSubscriptionManager?.refreshEntitlementState()
    }

    @MainActor
    func waitForConfiguration(timeout: TimeInterval = 3) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !configurationFlag.isSet, Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}

private final class AtomicFlag {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool {
        lock.lock()
        let current = value
        lock.unlock()
        return current
    }

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }
}
