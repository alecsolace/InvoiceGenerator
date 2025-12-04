import Foundation
import SwiftData

/// Client model for reusing invoice recipients
@Model
final class Client {
    var id: UUID
    var name: String
    var email: String
    var address: String

    @Relationship(deleteRule: .cascade, inverse: \Invoice.client)
    var invoices: [Invoice]?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        email: String = "",
        address: String = ""
    ) {
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

extension Client: Hashable {
    static func == (lhs: Client, rhs: Client) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
