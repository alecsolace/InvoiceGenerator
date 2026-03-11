import Foundation

enum SharedImageImportStore {
    static let appGroupIdentifier = "group.com.alecsolace.InvoiceGeneration"

    private static let imageFileName = "pending-invoice-import-image.bin"
    private static let metadataFileName = "pending-invoice-import-metadata.json"

    static var hasPendingImport: Bool {
        guard let containerURL = containerURL else { return false }
        return FileManager.default.fileExists(atPath: containerURL.appendingPathComponent(imageFileName).path)
    }

    static func savePendingImageData(_ data: Data, source: PendingImportSource) throws {
        guard let containerURL = containerURL else {
            throw SharedImageImportStoreError.unavailableContainer
        }

        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true, attributes: nil)
        try data.write(to: containerURL.appendingPathComponent(imageFileName), options: .atomic)

        let metadata = PendingImportMetadata(createdAt: Date(), source: source)
        let encodedMetadata = try JSONEncoder().encode(metadata)
        try encodedMetadata.write(to: containerURL.appendingPathComponent(metadataFileName), options: .atomic)
    }

    static func consumePendingImageData() -> Data? {
        guard let containerURL = containerURL else { return nil }

        let imageURL = containerURL.appendingPathComponent(imageFileName)
        guard let data = try? Data(contentsOf: imageURL) else { return nil }

        try? FileManager.default.removeItem(at: imageURL)
        try? FileManager.default.removeItem(at: containerURL.appendingPathComponent(metadataFileName))
        return data
    }

    static func peekMetadata() -> PendingImportMetadata? {
        guard let containerURL = containerURL else { return nil }
        let metadataURL = containerURL.appendingPathComponent(metadataFileName)
        guard let data = try? Data(contentsOf: metadataURL) else { return nil }
        return try? JSONDecoder().decode(PendingImportMetadata.self, from: data)
    }

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("PendingInvoiceImport", isDirectory: true)
    }
}

enum SharedImageImportStoreError: LocalizedError {
    case unavailableContainer

    var errorDescription: String? {
        switch self {
        case .unavailableContainer:
            return "No se pudo acceder al contenedor compartido de importacion."
        }
    }
}

enum PendingImportSource: String, Codable {
    case photoLibrary
    case shareExtension
}

struct PendingImportMetadata: Codable {
    let createdAt: Date
    let source: PendingImportSource
}
