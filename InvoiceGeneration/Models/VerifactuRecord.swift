import Foundation
import SwiftData

/// A VeriFACTU registry record (registro de facturación) that represents a single entry
/// in the tamper-evident hash chain maintained per issuer.
///
/// Each record captures the invoice data required by RD 1007/2023 and includes
/// a SHA-256 hash chained to the previous record for the same issuer.
@Model
final class VerifactuRecord {
    var id: UUID = UUID()

    // MARK: - Invoice Identity

    /// NIF of the issuer (emisor)
    var issuerTaxId: String = ""

    /// Invoice number including series prefix
    var invoiceNumber: String = ""

    /// Invoice issue date (fecha de expedición)
    var issueDate: Date = Date()

    /// Invoice type code (F1, F2, R1, etc.)
    var invoiceType: InvoiceType = InvoiceType.f1

    /// Tax regime key (clave de régimen fiscal)
    var taxRegimeKey: TaxRegimeKey = TaxRegimeKey.general

    // MARK: - Amounts

    /// Total invoice amount (importe total)
    var totalAmount: Decimal = 0

    /// Total tax amount — sum of all cuotas repercutidas
    var totalTax: Decimal = 0

    // MARK: - Hash Chain

    /// SHA-256 hash of this record's canonical representation
    var recordHash: String = ""

    /// SHA-256 hash of the previous record in this issuer's chain.
    /// Empty string for the first record in the chain.
    var previousHash: String = ""

    /// Position in the issuer's VeriFACTU chain (1-based)
    var sequenceNumber: Int = 0

    /// Exact timestamp when this record was generated (fecha-hora generación registro)
    var recordTimestamp: Date = Date()

    // MARK: - QR and Submission

    /// Encoded data for the QR code verification URL
    var qrCodeUrl: String = ""

    /// Current submission status with AEAT
    var submissionStatus: VerifactuRecordStatus = VerifactuRecordStatus.pending

    /// Date when the record was submitted to AEAT (nil if not yet submitted)
    var submissionDate: Date?

    /// AEAT response CSV or reference code (nil if not yet received)
    var submissionResponse: String?

    // MARK: - Cancellation

    /// If true, this record represents an annulment (anulación) rather than a registration (alta)
    var isCancellation: Bool = false

    // MARK: - Relationships

    @Relationship(inverse: \Invoice.verifactuRecord)
    var invoice: Invoice?

    @Relationship(inverse: \Issuer.verifactuRecords)
    var issuer: Issuer?

    // MARK: - Timestamps

    var createdAt: Date = Date()

    // MARK: - Init

    init(
        id: UUID = UUID(),
        issuerTaxId: String,
        invoiceNumber: String,
        issueDate: Date,
        invoiceType: InvoiceType,
        taxRegimeKey: TaxRegimeKey,
        totalAmount: Decimal,
        totalTax: Decimal,
        recordHash: String = "",
        previousHash: String = "",
        sequenceNumber: Int,
        recordTimestamp: Date = Date(),
        qrCodeUrl: String = "",
        isCancellation: Bool = false
    ) {
        self.id = id
        self.issuerTaxId = issuerTaxId
        self.invoiceNumber = invoiceNumber
        self.issueDate = issueDate
        self.invoiceType = invoiceType
        self.taxRegimeKey = taxRegimeKey
        self.totalAmount = totalAmount
        self.totalTax = totalTax
        self.recordHash = recordHash
        self.previousHash = previousHash
        self.sequenceNumber = sequenceNumber
        self.recordTimestamp = recordTimestamp
        self.qrCodeUrl = qrCodeUrl
        self.isCancellation = isCancellation
        self.submissionStatus = .pending
        self.submissionDate = nil
        self.submissionResponse = nil
        self.createdAt = Date()
    }
}
