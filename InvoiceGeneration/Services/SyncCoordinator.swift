import Foundation
import OSLog

// MARK: - SyncCoordinator

/// Centralises all CloudKit write-back calls so ViewModels don't repeat the
/// "check syncEnabled → spawn Task → call service → log on error" idiom
/// individually. Injected into ViewModels at init time (default: `.shared`),
/// which lets tests supply a no-op stub without touching the singletons.
final class SyncCoordinator {

    // MARK: - Shared instance

    static let shared = SyncCoordinator()

    // MARK: - Dependencies

    private let subscriptionService: SubscriptionService
    private let cloudKitService: CloudKitService
    private let logger = Logger(subsystem: "InvoiceGeneration", category: "SyncCoordinator")

    // MARK: - Init

    /// Designated initialiser — uses real singletons by default; tests can
    /// override either dependency via this initialiser.
    init(
        subscriptionService: SubscriptionService = .shared,
        cloudKitService: CloudKitService = .shared
    ) {
        self.subscriptionService = subscriptionService
        self.cloudKitService = cloudKitService
    }

    // MARK: - Invoice sync

    /// Sync a set of invoices to CloudKit if the current subscription allows it.
    func syncInvoices(_ invoices: [Invoice]) {
        guard subscriptionService.syncEnabled else { return }
        Task {
            do {
                try await cloudKitService.syncInvoices(invoices)
            } catch {
                logger.error("CloudKit invoice sync failed: \(error.localizedDescription)")
            }
        }
    }

    /// Remove a single invoice from CloudKit if sync is enabled.
    func deleteInvoice(with id: UUID) {
        guard subscriptionService.syncEnabled else { return }
        Task {
            do {
                try await cloudKitService.deleteInvoice(with: id)
            } catch {
                logger.error("CloudKit invoice delete failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Client sync

    /// Sync a set of clients to CloudKit if the current subscription allows it.
    func syncClients(_ clients: [Client]) {
        guard subscriptionService.syncEnabled else { return }
        Task {
            do {
                try await cloudKitService.syncClients(clients)
            } catch {
                logger.error("CloudKit client sync failed: \(error.localizedDescription)")
            }
        }
    }

    /// Remove a single client from CloudKit if sync is enabled.
    func deleteClient(with id: UUID) {
        guard subscriptionService.syncEnabled else { return }
        Task {
            do {
                try await cloudKitService.deleteClient(with: id)
            } catch {
                logger.error("CloudKit client delete failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Issuer sync

    /// Sync a set of issuers to CloudKit if the current subscription allows it.
    func syncIssuers(_ issuers: [Issuer]) {
        guard subscriptionService.syncEnabled else { return }
        Task {
            do {
                try await cloudKitService.syncIssuers(issuers)
            } catch {
                logger.error("CloudKit issuer sync failed: \(error.localizedDescription)")
            }
        }
    }

    /// Remove a single issuer from CloudKit if sync is enabled.
    func deleteIssuer(with id: UUID) {
        guard subscriptionService.syncEnabled else { return }
        Task {
            do {
                try await cloudKitService.deleteIssuer(with: id)
            } catch {
                logger.error("CloudKit issuer delete failed: \(error.localizedDescription)")
            }
        }
    }
}
