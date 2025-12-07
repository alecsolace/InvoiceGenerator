import Foundation
import CloudKit
import SwiftData

enum CloudKitServiceError: LocalizedError {
    case subscriptionRequired

    var errorDescription: String? {
        switch self {
        case .subscriptionRequired:
            return String(localized: "iCloud sync requires an active Pro subscription.", comment: "Error shown when sync is blocked without Pro")
        }
    }
}

/// Service for managing CloudKit synchronization
final class CloudKitService {
    static let shared = CloudKitService()
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    private init() {
        // Initialize with default container
        // In a real app, you would configure this with your CloudKit container identifier
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
    }
    
    /// Check if iCloud is available
    func checkiCloudStatus() async throws -> Bool {
        let status = try await container.accountStatus()
        return status == .available
    }
    
    /// Sync invoices to CloudKit
    func syncInvoices(_ invoices: [Invoice]) async throws {
        try guardSubscriptionAccess()
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
        try guardSubscriptionAccess()
        let query = CKQuery(recordType: "Invoice", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "issueDate", ascending: false)]
        
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        var records: [CKRecord] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("Error fetching record: \(error)")
            }
        }
        
        return records
    }
    
    /// Save a single record to CloudKit
    private func saveRecord(_ record: CKRecord) async throws {
        try await privateDatabase.save(record)
    }
    
    /// Convert Invoice to CKRecord
    private func invoiceToRecord(_ invoice: Invoice) -> CKRecord {
        let recordID = CKRecord.ID(recordName: invoice.id.uuidString)
        let record = CKRecord(recordType: "Invoice", recordID: recordID)
        
        record["invoiceNumber"] = invoice.invoiceNumber as CKRecordValue
        record["clientName"] = invoice.clientName as CKRecordValue
        record["clientEmail"] = invoice.clientEmail as CKRecordValue
        record["clientAddress"] = invoice.clientAddress as CKRecordValue
        record["issueDate"] = invoice.issueDate as CKRecordValue
        record["dueDate"] = invoice.dueDate as CKRecordValue
        record["status"] = invoice.status.rawValue as CKRecordValue
        record["notes"] = invoice.notes as CKRecordValue
        record["totalAmount"] = invoice.totalAmount as NSDecimalNumber as CKRecordValue
        record["createdAt"] = invoice.createdAt as CKRecordValue
        record["updatedAt"] = invoice.updatedAt as CKRecordValue
        
        return record
    }
    
    /// Delete record from CloudKit
    func deleteInvoice(with id: UUID) async throws {
        try guardSubscriptionAccess()
        let recordID = CKRecord.ID(recordName: id.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)
    }
    
    /// Subscribe to changes in CloudKit
    func setupSubscription() async throws {
        try guardSubscriptionAccess()
        let subscription = CKQuerySubscription(
            recordType: "Invoice",
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        try await privateDatabase.save(subscription)
    }

    private func guardSubscriptionAccess() throws {
        if !SubscriptionService.shared.syncEnabled {
            throw CloudKitServiceError.subscriptionRequired
        }
    }
}
