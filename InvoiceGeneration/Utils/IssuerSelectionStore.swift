import Foundation

enum IssuerSelectionStore {
    static let appStorageKey = "selectedIssuerID"
    static let allIssuersToken = "ALL"

    static func issuerID(from storageValue: String) -> UUID? {
        guard storageValue != allIssuersToken else { return nil }
        return UUID(uuidString: storageValue)
    }

    static func storageValue(from issuerID: UUID?) -> String {
        issuerID?.uuidString ?? allIssuersToken
    }
}
