import Foundation
import SwiftData

/// Client entity stored for invoice selection and reuse
@Model
final class Client {
    var id: UUID
    var name: String
    var email: String
    var address: String
    var phone: String

    @Relationship(deleteRule: .nullify, inverse: \Invoice.client)
    var invoices: [Invoice]?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        email: String = "",
        address: String = "",
        phone: String = ""
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.address = address
        self.phone = phone
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func updateTimestamp() {
        updatedAt = Date()
    }
}
