import Foundation
import StoreKit
import Combine

/// Handles StoreKit purchases, entitlements, and sync eligibility.
@MainActor
final class SubscriptionService: ObservableObject {
    enum EntitlementStatus: Equatable {
        case free
        case active
        case expired
    }

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case pending
        case failed
        case restoring
    }

    enum SyncStatus: Equatable {
        case lockedByPaywall
        case disabledByUser
        case pausedNoICloud
        case ready
    }

    struct Plan: Identifiable, Equatable {
        let id: String
        var title: String
        var subtitle: String
        var price: String
        var highlight: String?
        var hasIntroOffer: Bool

        static func placeholderPlans(using configuration: StoreConfiguration) -> [Plan] {
            [
                Plan(
                    id: configuration.yearlyProductID,
                    title: String(localized: "Annual", comment: "Annual plan label"),
                    subtitle: String(localized: "Best value", comment: "Annual plan helper text"),
                    price: "$19.99",
                    highlight: String(localized: "Save over monthly", comment: "Annual savings badge"),
                    hasIntroOffer: true
                ),
                Plan(
                    id: configuration.monthlyProductID,
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

    @Published private(set) var entitlementStatus: EntitlementStatus
    @Published private(set) var purchaseState: PurchaseState
    @Published private(set) var availablePlans: [Plan]
    @Published private(set) var lastError: String?
    @Published private(set) var iCloudAvailability: ICloudAvailability
    @Published var syncPreferred: Bool {
        didSet { defaults.set(syncPreferred, forKey: syncPreferenceKey) }
    }

    var isPro: Bool {
        entitlementStatus == .active
    }

    var syncStatus: SyncStatus {
        guard entitlementStatus == .active else { return .lockedByPaywall }
        guard syncPreferred else { return .disabledByUser }
        guard iCloudAvailability == .available else { return .pausedNoICloud }
        return .ready
    }

    var syncEnabled: Bool {
        syncStatus == .ready
    }

    var isPurchaseInFlight: Bool {
        purchaseState == .purchasing || purchaseState == .restoring
    }

    let freeClientLimit = 2

    private let configuration: StoreConfiguration
    private var productsByID: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private let syncPreferenceKey = "subscription.syncPreferred"
    private let hasSeenActiveEntitlementKey = "subscription.hasSeenActiveEntitlement"
    private let iCloudAvailabilityProvider: @Sendable () async -> ICloudAvailability

    private enum SubscriptionError: LocalizedError {
        case verificationFailed

        var errorDescription: String? {
            String(localized: "Purchase verification failed. Please try again.", comment: "Verification failed error")
        }
    }

    init(
        defaults: UserDefaults = .standard,
        storeConfiguration: StoreConfiguration? = nil,
        iCloudAvailabilityProvider: @escaping @Sendable () async -> ICloudAvailability = {
            await CloudKitService.shared.fetchAccountAvailability()
        },
        startTasks: Bool = true
    ) {
        self.defaults = defaults
        self.configuration = storeConfiguration ?? StoreConfiguration.live()
        self.iCloudAvailabilityProvider = iCloudAvailabilityProvider
        self.entitlementStatus = .free
        self.purchaseState = .idle
        self.availablePlans = Plan.placeholderPlans(using: self.configuration)
        self.lastError = nil
        self.iCloudAvailability = .temporarilyUnavailable
        self.syncPreferred = defaults.bool(forKey: syncPreferenceKey)

        if startTasks {
            updatesTask = listenForTransactions()
            Task {
                await refreshEntitlements()
                await refreshICloudAvailability()
                await loadProducts()
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func canAddClient(currentCount: Int) -> Bool {
        entitlementStatus == .active || currentCount < freeClientLimit
    }

    func refreshEntitlements() async {
        guard #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) else {
            entitlementStatus = .free
            return
        }

        var resolvedStatus: EntitlementStatus = defaults.bool(forKey: hasSeenActiveEntitlementKey) ? .expired : .free

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if configuration.productIDs.contains(transaction.productID) {
                    defaults.set(true, forKey: hasSeenActiveEntitlementKey)
                    resolvedStatus = .active
                    break
                }
            } catch {
                lastError = error.localizedDescription
            }
        }

        entitlementStatus = resolvedStatus
    }

    func refreshICloudAvailability() async {
        iCloudAvailability = await iCloudAvailabilityProvider()
    }

    func purchase(planID: String) async {
        guard #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) else {
            purchaseState = .failed
            lastError = String(localized: "Purchases are not supported on this OS version.", comment: "StoreKit unavailable message")
            return
        }

        guard let product = productsByID[planID] else {
            purchaseState = .failed
            lastError = String(localized: "Unable to load product information. Please try again.", comment: "Missing product error")
            return
        }

        lastError = nil
        purchaseState = .purchasing

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                defaults.set(true, forKey: hasSeenActiveEntitlementKey)
                await refreshEntitlements()
                await refreshICloudAvailability()
                purchaseState = .idle
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .pending
                lastError = String(localized: "Purchase pending approval.", comment: "Pending purchase message")
            default:
                purchaseState = .failed
                lastError = String(localized: "Purchase could not be completed. Please try again.", comment: "Generic purchase failure message")
            }
        } catch {
            purchaseState = .failed
            lastError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        guard #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) else {
            purchaseState = .failed
            lastError = String(localized: "Purchases are not supported on this OS version.", comment: "StoreKit unavailable message")
            return
        }

        lastError = nil
        purchaseState = .restoring

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            await refreshICloudAvailability()

            if entitlementStatus == .free {
                lastError = String(localized: "No previous purchases found.", comment: "Restore purchases not found message")
            }

            purchaseState = .idle
        } catch {
            purchaseState = .failed
            lastError = error.localizedDescription
        }
    }

    func preferredPlanID() -> String? {
        availablePlans.first?.id
    }

#if DEBUG
    /// Testing helper to bypass StoreKit during tests.
    func debugSetEntitlementStatus(_ status: EntitlementStatus) {
        entitlementStatus = status
        if status == .active {
            defaults.set(true, forKey: hasSeenActiveEntitlementKey)
        }
    }

    /// Testing helper for iCloud availability dependent UI.
    func debugSetICloudAvailability(_ status: ICloudAvailability) {
        iCloudAvailability = status
    }
#endif

    private func loadProducts() async {
        guard #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) else { return }

        do {
            _ = try configuration.validated()
        } catch {
            purchaseState = .failed
            lastError = error.localizedDescription
            return
        }

        do {
            let products = try await Product.products(for: configuration.productIDs)
            var updatedPlans = availablePlans

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

            availablePlans = updatedPlans
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func listenForTransactions() -> Task<Void, Never>? {
        guard #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) else { return nil }

        return Task.detached { [weak self] in
            guard let self else { return }

            for await result in Transaction.updates {
                await self.handleTransactionUpdate(result)
            }
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)
            guard configuration.productIDs.contains(transaction.productID) else { return }

            defaults.set(true, forKey: hasSeenActiveEntitlementKey)
            await transaction.finish()
            await refreshEntitlements()
            await refreshICloudAvailability()
            purchaseState = .idle
        } catch {
            purchaseState = .failed
            lastError = error.localizedDescription
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
}
