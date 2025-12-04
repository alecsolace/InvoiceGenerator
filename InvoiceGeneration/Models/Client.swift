import Foundation
import SwiftData

/// Client model persisted with SwiftData
@Model
final class Client {
    var id: UUID
    var name: String
    var email: String
    var address: String

    @Relationship(deleteRule: .nullify)
    var invoices: [Invoice]?

    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, email: String = "", address: String = "") {
        self.id = id
        self.name = name
        self.email = email
        self.address = address
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func updateTimestamp() {
        updatedAt = Date()
    }
}
