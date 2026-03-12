import Foundation
import SwiftData
import OSLog

/// Centralized SwiftData container so all scenes share the same store.
enum PersistenceController {
    static let logger = Logger(subsystem: "InvoiceGeneration", category: "Persistence")

    // swiftlint:disable:next force_try
    static let preview: ModelContainer = try! makeContainer(inMemory: true)

    // MARK: - Public

    /// Creates the shared ModelContainer. Throws if even the in-memory fallback cannot be created.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let shouldUseInMemory = inMemory || ProcessInfo.processInfo.arguments.contains("UITEST_USE_IN_MEMORY_STORE")

        if shouldUseInMemory {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            return try ModelContainer(
                for: Invoice.self,
                InvoiceItem.self,
                CompanyProfile.self,
                Client.self,
                Issuer.self,
                InvoiceTemplate.self,
                InvoiceTemplateItem.self,
                configurations: configuration
            )
        }

        // Primary disk-backed container
        do {
            let configuration = try diskConfiguration()
            return try ModelContainer(
                for: Invoice.self,
                InvoiceItem.self,
                CompanyProfile.self,
                Client.self,
                Issuer.self,
                InvoiceTemplate.self,
                InvoiceTemplateItem.self,
                configurations: configuration
            )
        } catch {
            logger.error("Disk-backed SwiftData container failed: \(error.localizedDescription). Attempting to reset store.")
            // Try deleting the existing store and recreating once.
            if let url = try? storeURL(), FileManager.default.fileExists(atPath: url.path) {
                do {
                    try FileManager.default.removeItem(at: url)
                    logger.notice("Removed corrupted SwiftData store at \(url.path)")
                } catch {
                    logger.error("Failed to remove corrupted SwiftData store: \(error.localizedDescription)")
                }
            }

            do {
                let configuration = try diskConfiguration()
                return try ModelContainer(
                    for: Invoice.self,
                    InvoiceItem.self,
                    CompanyProfile.self,
                    Client.self,
                    Issuer.self,
                    InvoiceTemplate.self,
                    InvoiceTemplateItem.self,
                    configurations: configuration
                )
            } catch {
                logger.critical("Disk-backed SwiftData container failed after reset (\(error.localizedDescription)); falling back to in-memory store.")
                return try makeContainer(inMemory: true)
            }
        }
    }

    // MARK: - Private

    private static func diskConfiguration() throws -> ModelConfiguration {
        let url = try storeURL()
        return ModelConfiguration(url: url)
    }

    private static func storeURL() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = appSupport.appendingPathComponent("InvoiceGeneration", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("InvoiceGeneration.sqlite")
    }
}
