import Foundation
import StoreKit
import Combine

/// Handles StoreKit purchases, entitlements, and gating for Pro features.
@MainActor
final class SubscriptionService: ObservableObject {
    enum Status: Equatable {
        case unknown
        case free
        case active(expirationDate: Date?)
        case expired
    }

    struct Plan: Identifiable, Equatable {
        let id: String
        var title: String
        var subtitle: String
        var price: String
        var highlight: String?
        var hasIntroOffer: Bool

        static var defaultPlans: [Plan] {
            [
                Plan(
                    id: "pro_yearly",
                    title: String(localized: "Annual", comment: "Annual plan label"),
                    subtitle: String(localized: "Best value", comment: "Annual plan helper text"),
                    price: "$19.99",
                    highlight: String(localized: "Save over monthly", comment: "Annual savings badge"),
                    hasIntroOffer: true
                ),
                Plan(
                    id: "pro_monthly",
                    title: String(localized: "Monthly", comment: "Monthly plan label"),
                    subtitle: String(localized: "Flexible billing", comment: "Monthly helper text"),
                    price: "$2.99",
                    highlight: nil,
                    hasIntroOffer: false
                )
            ]
        }
    }

    static let shared = SubscriptionService()

    @Published private(set) var status: Status
    @Published private(set) var plans: [Plan]
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var lastError: String?
    @Published var syncPreferred: Bool {
        didSet { defaults.set(syncPreferred, forKey: syncPreferenceKey) }
    }

    var isPro: Bool {
        if case .active = status { return true }
        return false
    }

    var syncEnabled: Bool {
        isPro && syncPreferred
    }

    let freeClientLimit = 2

    private let productIDs = ["pro_monthly", "pro_yearly"]
    private var productsByID: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private let syncPreferenceKey = "subscription.syncPreferred"

    private enum SubscriptionError: LocalizedError {
        case verificationFailed

        var errorDescription: String? {
            String(localized: "Purchase verification failed. Please try again.", comment: "Verification failed error")
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.status = .free
        self.plans = Plan.defaultPlans
        self.syncPreferred = defaults.bool(forKey: syncPreferenceKey)

        refreshEntitlements()
        updatesTask = listenForTransactions()
        Task { await loadProducts() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func canAddClient(currentCount: Int) -> Bool {
        isPro || currentCount < freeClientLimit
    }

    func refreshEntitlements() {
        guard #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) else {
            setStatus(.free)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            for await result in Transaction.currentEntitlements {
                do {
                    let transaction = try checkVerified(result)
                    if productIDs.contains(transaction.productID) {
                        await transaction.finish()
                        await MainActor.run {
                            self.setStatus(.active(expirationDate: transaction.expirationDate))
                        }
                        return
                    }
                } catch {
                    await MainActor.run { self.lastError = error.localizedDescription }
                }
            }

            await MainActor.run {
                self.setStatus(.free)
            }
        }
    }

    func purchase(planID: String) async {
        guard #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) else {
            lastError = String(localized: "Purchases are not supported on this OS version.", comment: "StoreKit unavailable message")
            return
        }

        guard let product = productsByID[planID] else {
            lastError = String(localized: "Unable to load product information. Please try again.", comment: "Missing product error")
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                setStatus(.active(expirationDate: transaction.expirationDate))
            case .userCancelled:
                break
            case .pending:
                lastError = String(localized: "Purchase pending approval.", comment: "Pending purchase message")
            default:
                lastError = String(localized: "Purchase could not be completed. Please try again.", comment: "Generic purchase failure message")
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        guard #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) else {
            lastError = String(localized: "Purchases are not supported on this OS version.", comment: "StoreKit unavailable message")
            return
        }

        do {
            for await result in Transaction.currentEntitlements {
                let transaction = try checkVerified(result)
                if productIDs.contains(transaction.productID) {
                    await transaction.finish()
                    setStatus(.active(expirationDate: transaction.expirationDate))
                    return
                }
            }

            lastError = String(localized: "No previous purchases found.", comment: "Restore purchases not found message")
        } catch {
            lastError = error.localizedDescription
        }
    }

    func preferredPlanID() -> String? {
        plans.first?.id
    }

#if DEBUG
    /// Testing helper to bypass StoreKit during UI tests.
    func debugSetStatus(_ status: Status) {
        setStatus(status)
    }
#endif

    private func loadProducts() async {
        guard #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) else { return }
        isLoadingProducts = true

        do {
            let products = try await Product.products(for: productIDs)
            var updatedPlans = plans

            for product in products {
                productsByID[product.id] = product

                if let index = updatedPlans.firstIndex(where: { $0.id == product.id }) {
                    updatedPlans[index].price = product.displayPrice
                    updatedPlans[index].hasIntroOffer = product.subscription?.introductoryOffer != nil
                } else {
                    updatedPlans.append(
                        Plan(
                            id: product.id,
                            title: product.displayName,
                            subtitle: product.description,
                            price: product.displayPrice,
                            highlight: product.subscription?.introductoryOffer != nil
                            ? String(localized: "Includes intro offer", comment: "Intro offer helper text")
                            : nil,
                            hasIntroOffer: product.subscription?.introductoryOffer != nil
                        )
                    )
                }
            }

            plans = updatedPlans
            isLoadingProducts = false
        } catch {
            lastError = error.localizedDescription
            isLoadingProducts = false
        }
    }

    private func listenForTransactions() -> Task<Void, Never>? {
        guard #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) else { return nil }

        return Task.detached { [weak self] in
            guard let self else { return }

            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    if self.productIDs.contains(transaction.productID) {
                        await transaction.finish()
                        await MainActor.run {
                            self.setStatus(.active(expirationDate: transaction.expirationDate))
                        }
                    }
                } catch {
                    await MainActor.run { self.lastError = error.localizedDescription }
                }
            }
        }
    }

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    private func setStatus(_ newStatus: Status) {
        status = newStatus

        if !isPro {
            syncPreferred = false
        }
    }
}
