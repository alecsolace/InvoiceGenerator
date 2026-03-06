import Foundation
import SwiftData

/// Issuer profile used as the sender entity for invoices.
@Model
final class Issuer {
    var id: UUID
    var name: String
    /// Unique invoice prefix (for example: FAM, ANA).
    var code: String
    var ownerName: String
    var email: String
    var phone: String
    var address: String
    var taxId: String
    var logoData: Data?
    /// Next sequence to be used when generating invoice numbers.
    var nextInvoiceSequence: Int

    @Relationship(deleteRule: .nullify)
    var invoices: [Invoice]?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        code: String,
        ownerName: String = "",
        email: String = "",
        phone: String = "",
        address: String = "",
        taxId: String = "",
        logoData: Data? = nil,
        nextInvoiceSequence: Int = 1
    ) {
        self.id = id
        self.name = name
        self.code = code.uppercased()
        self.ownerName = ownerName
        self.email = email
        self.phone = phone
        self.address = address
        self.taxId = taxId
        self.logoData = logoData
        self.nextInvoiceSequence = max(nextInvoiceSequence, 1)
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func updateTimestamp() {
        updatedAt = Date()
    }
}
