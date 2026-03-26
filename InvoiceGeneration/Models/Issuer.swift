import Foundation
import SwiftData

/// Issuer profile used as the sender entity for invoices.
@Model
final class Issuer {
    var id: UUID = UUID()
    var name: String = ""
    /// Unique invoice prefix (for example: FAM, ANA).
    var code: String = ""
    var ownerName: String = ""
    var email: String = ""
    var phone: String = ""
    var address: String = ""
    var taxId: String = ""
    var logoData: Data?
    /// Default notes/observations to pre-fill when creating invoices from this issuer.
    var defaultNotes: String = ""
    /// Next sequence to be used when generating invoice numbers.
    var nextInvoiceSequence: Int = 1

    // MARK: - VeriFACTU Compliance

    /// Whether VeriFACTU compliance is enabled for this issuer.
    /// When enabled, invoices generate hash-chained records and QR codes.
    var verifactuEnabled: Bool = false

    /// SHA-256 hash of the last VeriFACTU record in this issuer's chain.
    /// Empty string means no records yet (first record uses sentinel value).
    var lastVerifactuHash: String = ""

    /// Next sequence number for this issuer's VeriFACTU chain (1-based).
    var verifactuSequence: Int = 1

    @Relationship(deleteRule: .nullify)
    var invoices: [Invoice]?

    @Relationship(deleteRule: .nullify)
    var templates: [InvoiceTemplate]?

    /// VeriFACTU registry records belonging to this issuer's hash chain.
    @Relationship(deleteRule: .cascade)
    var verifactuRecords: [VerifactuRecord]?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

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
        defaultNotes: String = "",
        nextInvoiceSequence: Int = 1,
        verifactuEnabled: Bool = false
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
        self.defaultNotes = defaultNotes
        self.nextInvoiceSequence = max(nextInvoiceSequence, 1)
        self.verifactuEnabled = verifactuEnabled
        self.lastVerifactuHash = ""
        self.verifactuSequence = 1
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func updateTimestamp() {
        updatedAt = Date()
    }
}
