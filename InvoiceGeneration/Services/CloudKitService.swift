import Foundation
import CloudKit
import OSLog

enum ICloudAvailability: Equatable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
}

enum CloudKitServiceError: LocalizedError {
    case syncNotReady(SubscriptionService.SyncStatus)

    var errorDescription: String? {
        switch self {
        case .syncNotReady(.lockedByPaywall):
            return String(localized: "iCloud sync requires an active Pro subscription.", comment: "Error shown when sync is blocked without Pro")
        case .syncNotReady(.disabledByUser):
            return String(localized: "iCloud sync is currently turned off in Settings.", comment: "Error shown when sync is disabled by the user")
        case .syncNotReady(.pausedNoICloud):
            return String(localized: "iCloud is unavailable. Sync will resume automatically when your account is ready.", comment: "Error shown when sync is paused for iCloud availability")
        case .syncNotReady(.ready):
            return nil
        }
    }
}

/// Service for managing CloudKit synchronization readiness and account state.
final class CloudKitService {
    static let shared = CloudKitService()

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let logger = Logger(subsystem: "InvoiceGeneration", category: "CloudKit")

    // MARK: - Record Type Constants

    private let invoiceRecordType = "Invoice"
    private let clientRecordType = "Client"
    private let issuerRecordType = "Issuer"

    private init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
    }

    // MARK: - Account

    func fetchAccountAvailability() async -> ICloudAvailability {
        do {
            switch try await container.accountStatus() {
            case .available:
                return .available
            case .noAccount:
                return .noAccount
            case .restricted:
                return .restricted
            case .couldNotDetermine:
                return .temporarilyUnavailable
            case .temporarilyUnavailable:
                return .temporarilyUnavailable
            @unknown default:
                return .temporarilyUnavailable
            }
        } catch {
            return .temporarilyUnavailable
        }
    }

    // MARK: - Invoices

    /// Sync invoices to CloudKit when the app is commercially and technically eligible.
    func syncInvoices(_ invoices: [Invoice]) async throws {
        try guardSyncReady()
        let records = invoices.map { invoiceToRecord($0) }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for record in records {
                group.addTask {
                    try await self.saveRecord(record)
                }
            }

            try await group.waitForAll()
        }
    }

    /// Fetch invoices from CloudKit
    func fetchInvoices() async throws -> [CKRecord] {
        try guardSyncReady()
        let query = CKQuery(recordType: invoiceRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "issueDate", ascending: false)]

        let (matchResults, _) = try await privateDatabase.records(matching: query)

        var records: [CKRecord] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                logger.error("Error fetching record: \(error.localizedDescription)")
            }
        }

        return records
    }

    /// Delete record from CloudKit
    func deleteInvoice(with id: UUID) async throws {
        try guardSyncReady()
        let recordID = CKRecord.ID(recordName: id.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    // MARK: - Clients

    func syncClients(_ clients: [Client]) async throws {
        try guardSyncReady()
        let records = clients.map { clientToRecord($0) }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for record in records {
                group.addTask {
                    try await self.saveRecord(record)
                }
            }
            try await group.waitForAll()
        }
    }

    func fetchClients() async throws -> [CKRecord] {
        try guardSyncReady()
        let query = CKQuery(recordType: clientRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]

        let (matchResults, _) = try await privateDatabase.records(matching: query)

        var records: [CKRecord] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                logger.error("Error fetching client record: \(error.localizedDescription)")
            }
        }

        return records
    }

    func deleteClient(with id: UUID) async throws {
        try guardSyncReady()
        let recordID = CKRecord.ID(recordName: id.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    // MARK: - Issuers

    func syncIssuers(_ issuers: [Issuer]) async throws {
        try guardSyncReady()
        let records = issuers.map { issuerToRecord($0) }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for record in records {
                group.addTask {
                    try await self.saveRecord(record)
                }
            }
            try await group.waitForAll()
        }
    }

    func fetchIssuers() async throws -> [CKRecord] {
        try guardSyncReady()
        let query = CKQuery(recordType: issuerRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]

        let (matchResults, _) = try await privateDatabase.records(matching: query)

        var records: [CKRecord] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                logger.error("Error fetching issuer record: \(error.localizedDescription)")
            }
        }

        return records
    }

    func deleteIssuer(with id: UUID) async throws {
        try guardSyncReady()
        let recordID = CKRecord.ID(recordName: id.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    // MARK: - Subscription

    /// Subscribe to changes in CloudKit
    func setupSubscription() async throws {
        try guardSyncReady()
        let subscription = CKQuerySubscription(
            recordType: invoiceRecordType,
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        try await privateDatabase.save(subscription)
    }

    // MARK: - Private Helpers

    private func saveRecord(_ record: CKRecord) async throws {
        try await privateDatabase.save(record)
    }

    private func guardSyncReady() throws {
        let syncStatus = SubscriptionService.shared.syncStatus
        if syncStatus != .ready {
            throw CloudKitServiceError.syncNotReady(syncStatus)
        }
    }

    // MARK: - Record Mapping

    private func invoiceToRecord(_ invoice: Invoice) -> CKRecord {
        let recordID = CKRecord.ID(recordName: invoice.id.uuidString)
        let record = CKRecord(recordType: invoiceRecordType, recordID: recordID)

        record["invoiceNumber"] = invoice.invoiceNumber as CKRecordValue
        record["issuerName"] = invoice.issuerName as CKRecordValue
        record["issuerCode"] = invoice.issuerCode as CKRecordValue
        record["issuerOwnerName"] = invoice.issuerOwnerName as CKRecordValue
        record["issuerEmail"] = invoice.issuerEmail as CKRecordValue
        record["issuerPhone"] = invoice.issuerPhone as CKRecordValue
        record["issuerAddress"] = invoice.issuerAddress as CKRecordValue
        record["issuerTaxId"] = invoice.issuerTaxId as CKRecordValue
        record["issuerID"] = (invoice.issuer?.id.uuidString ?? "") as CKRecordValue
        record["clientName"] = invoice.clientName as CKRecordValue
        record["clientEmail"] = invoice.clientEmail as CKRecordValue
        record["clientIdentificationNumber"] = invoice.clientIdentificationNumber as CKRecordValue
        record["clientAddress"] = invoice.clientAddress as CKRecordValue
        record["issueDate"] = invoice.issueDate as CKRecordValue
        record["dueDate"] = invoice.dueDate as CKRecordValue
        record["status"] = invoice.status.rawValue as CKRecordValue
        record["notes"] = invoice.notes as CKRecordValue
        record["ivaPercentage"] = invoice.ivaPercentage as NSDecimalNumber as CKRecordValue
        record["irpfPercentage"] = invoice.irpfPercentage as NSDecimalNumber as CKRecordValue
        record["totalAmount"] = invoice.totalAmount as NSDecimalNumber as CKRecordValue
        record["createdAt"] = invoice.createdAt as CKRecordValue
        record["updatedAt"] = invoice.updatedAt as CKRecordValue

        return record
    }

    private func clientToRecord(_ client: Client) -> CKRecord {
        let recordID = CKRecord.ID(recordName: client.id.uuidString)
        let record = CKRecord(recordType: clientRecordType, recordID: recordID)

        record["name"] = client.name as CKRecordValue
        record["email"] = client.email as CKRecordValue
        record["address"] = client.address as CKRecordValue
        record["identificationNumber"] = client.identificationNumber as CKRecordValue
        record["accentColorHex"] = client.accentColorHex as CKRecordValue
        record["defaultDueDays"] = client.defaultDueDays as CKRecordValue
        record["defaultNotes"] = client.defaultNotes as CKRecordValue
        record["createdAt"] = client.createdAt as CKRecordValue
        record["updatedAt"] = client.updatedAt as CKRecordValue

        if let iva = client.defaultIVAPercentage {
            record["defaultIVAPercentage"] = iva as NSDecimalNumber as CKRecordValue
        }
        if let irpf = client.defaultIRPFPercentage {
            record["defaultIRPFPercentage"] = irpf as NSDecimalNumber as CKRecordValue
        }
        if let templateID = client.preferredTemplateID {
            record["preferredTemplateID"] = templateID.uuidString as CKRecordValue
        }

        return record
    }

    private func issuerToRecord(_ issuer: Issuer) -> CKRecord {
        let recordID = CKRecord.ID(recordName: issuer.id.uuidString)
        let record = CKRecord(recordType: issuerRecordType, recordID: recordID)

        record["name"] = issuer.name as CKRecordValue
        record["code"] = issuer.code as CKRecordValue
        record["ownerName"] = issuer.ownerName as CKRecordValue
        record["email"] = issuer.email as CKRecordValue
        record["phone"] = issuer.phone as CKRecordValue
        record["address"] = issuer.address as CKRecordValue
        record["taxId"] = issuer.taxId as CKRecordValue
        record["nextInvoiceSequence"] = issuer.nextInvoiceSequence as CKRecordValue
        record["createdAt"] = issuer.createdAt as CKRecordValue
        record["updatedAt"] = issuer.updatedAt as CKRecordValue

        if let logo = issuer.logoData {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("dat")
            do {
                try logo.write(to: tempURL)
                record["logoData"] = CKAsset(fileURL: tempURL)
            } catch {
                logger.error("Failed to write logoData to temp file: \(error.localizedDescription)")
            }
        }

        return record
    }
}
