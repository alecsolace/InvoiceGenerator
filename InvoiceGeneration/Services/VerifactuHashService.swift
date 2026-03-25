import Foundation
import CryptoKit
import SwiftData

/// Generates SHA-256 hashes for VeriFACTU registry records and maintains
/// the tamper-evident hash chain per issuer.
///
/// Hash computation follows the AEAT specification:
/// `SHA-256(NIF + NumFactura + FechaExpedicion + TipoFactura + CuotaTotal + ImporteTotal + HuellaAnterior + FechaHoraRegistro)`
enum VerifactuHashService {

    // MARK: - Constants

    /// Sentinel value used as `previousHash` for the first record in an issuer's chain.
    static let chainSentinel = "0000000000000000000000000000000000000000000000000000000000000000"

    // MARK: - Hash Generation

    /// Generates the SHA-256 hash for a VeriFACTU record.
    ///
    /// - Parameters:
    ///   - issuerTaxId: NIF/CIF of the issuer
    ///   - invoiceNumber: Invoice number including series
    ///   - issueDate: Invoice issue date
    ///   - invoiceType: Classification (F1, F2, R1, etc.)
    ///   - totalTax: Sum of all cuotas repercutidas
    ///   - totalAmount: Total invoice amount
    ///   - previousHash: Hash of the previous record in the chain (or sentinel)
    ///   - recordTimestamp: Exact timestamp when the record was generated
    /// - Returns: Lowercase hex-encoded SHA-256 hash string
    static func generateHash(
        issuerTaxId: String,
        invoiceNumber: String,
        issueDate: Date,
        invoiceType: InvoiceType,
        totalTax: Decimal,
        totalAmount: Decimal,
        previousHash: String,
        recordTimestamp: Date
    ) -> String {
        let canonical = canonicalString(
            issuerTaxId: issuerTaxId,
            invoiceNumber: invoiceNumber,
            issueDate: issueDate,
            invoiceType: invoiceType,
            totalTax: totalTax,
            totalAmount: totalAmount,
            previousHash: previousHash,
            recordTimestamp: recordTimestamp
        )

        let data = Data(canonical.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Record Creation

    /// Creates a VeriFACTU record for an invoice and appends it to the issuer's hash chain.
    ///
    /// - Parameters:
    ///   - invoice: The invoice to register
    ///   - issuer: The issuer whose chain will be extended
    ///   - context: SwiftData model context for persistence
    /// - Returns: The created `VerifactuRecord`, already inserted into `context`
    @discardableResult
    static func createRecord(
        for invoice: Invoice,
        issuer: Issuer,
        context: ModelContext
    ) -> VerifactuRecord {
        let previousHash = issuer.lastVerifactuHash.isEmpty
            ? chainSentinel
            : issuer.lastVerifactuHash
        let sequenceNumber = issuer.verifactuSequence
        let recordTimestamp = Date()

        let hash = generateHash(
            issuerTaxId: issuer.taxId,
            invoiceNumber: invoice.invoiceNumber,
            issueDate: invoice.issueDate,
            invoiceType: invoice.invoiceType,
            totalTax: invoice.totalTaxAmount,
            totalAmount: invoice.totalAmount,
            previousHash: previousHash,
            recordTimestamp: recordTimestamp
        )

        let qrUrl = VerifactuQRService.verificationUrl(
            issuerTaxId: issuer.taxId,
            invoiceNumber: invoice.invoiceNumber,
            issueDate: invoice.issueDate,
            totalAmount: invoice.totalAmount
        )

        let record = VerifactuRecord(
            issuerTaxId: issuer.taxId,
            invoiceNumber: invoice.invoiceNumber,
            issueDate: invoice.issueDate,
            invoiceType: invoice.invoiceType,
            taxRegimeKey: invoice.taxRegimeKey,
            totalAmount: invoice.totalAmount,
            totalTax: invoice.totalTaxAmount,
            recordHash: hash,
            previousHash: previousHash,
            sequenceNumber: sequenceNumber,
            recordTimestamp: recordTimestamp,
            qrCodeUrl: qrUrl
        )

        record.invoice = invoice
        record.issuer = issuer
        context.insert(record)

        // Update issuer chain state
        issuer.lastVerifactuHash = hash
        issuer.verifactuSequence = sequenceNumber + 1
        issuer.updateTimestamp()

        // Link record to invoice
        invoice.verifactuRecord = record

        return record
    }

    /// Creates a cancellation (anulación) record for an invoice.
    @discardableResult
    static func createCancellationRecord(
        for invoice: Invoice,
        issuer: Issuer,
        context: ModelContext
    ) -> VerifactuRecord {
        let previousHash = issuer.lastVerifactuHash.isEmpty
            ? chainSentinel
            : issuer.lastVerifactuHash
        let sequenceNumber = issuer.verifactuSequence
        let recordTimestamp = Date()

        let hash = generateHash(
            issuerTaxId: issuer.taxId,
            invoiceNumber: invoice.invoiceNumber,
            issueDate: invoice.issueDate,
            invoiceType: invoice.invoiceType,
            totalTax: invoice.totalTaxAmount,
            totalAmount: invoice.totalAmount,
            previousHash: previousHash,
            recordTimestamp: recordTimestamp
        )

        let record = VerifactuRecord(
            issuerTaxId: issuer.taxId,
            invoiceNumber: invoice.invoiceNumber,
            issueDate: invoice.issueDate,
            invoiceType: invoice.invoiceType,
            taxRegimeKey: invoice.taxRegimeKey,
            totalAmount: invoice.totalAmount,
            totalTax: invoice.totalTaxAmount,
            recordHash: hash,
            previousHash: previousHash,
            sequenceNumber: sequenceNumber,
            recordTimestamp: recordTimestamp,
            isCancellation: true
        )

        record.issuer = issuer
        context.insert(record)

        issuer.lastVerifactuHash = hash
        issuer.verifactuSequence = sequenceNumber + 1
        issuer.updateTimestamp()

        return record
    }

    // MARK: - Chain Verification

    /// Verifies the integrity of an issuer's entire VeriFACTU hash chain.
    ///
    /// - Parameters:
    ///   - issuer: The issuer whose chain to verify
    ///   - context: SwiftData model context
    /// - Returns: A tuple of `(isValid, brokenAtSequence)`. If invalid, `brokenAtSequence`
    ///   indicates the first record where the chain breaks.
    static func verifyChain(
        for issuer: Issuer,
        context: ModelContext
    ) -> (isValid: Bool, brokenAtSequence: Int?) {
        let records = (issuer.verifactuRecords ?? [])
            .sorted { $0.sequenceNumber < $1.sequenceNumber }

        guard !records.isEmpty else {
            return (true, nil)
        }

        var expectedPreviousHash = chainSentinel

        for record in records {
            guard record.previousHash == expectedPreviousHash else {
                return (false, record.sequenceNumber)
            }

            let recomputedHash = generateHash(
                issuerTaxId: record.issuerTaxId,
                invoiceNumber: record.invoiceNumber,
                issueDate: record.issueDate,
                invoiceType: record.invoiceType,
                totalTax: record.totalTax,
                totalAmount: record.totalAmount,
                previousHash: record.previousHash,
                recordTimestamp: record.recordTimestamp
            )

            guard recomputedHash == record.recordHash else {
                return (false, record.sequenceNumber)
            }

            expectedPreviousHash = record.recordHash
        }

        return (true, nil)
    }

    // MARK: - Private

    /// Builds the canonical string representation for hashing per AEAT specification.
    /// Fields are separated by `&` and formatted in a deterministic manner.
    private static func canonicalString(
        issuerTaxId: String,
        invoiceNumber: String,
        issueDate: Date,
        invoiceType: InvoiceType,
        totalTax: Decimal,
        totalAmount: Decimal,
        previousHash: String,
        recordTimestamp: Date
    ) -> String {
        let dateString = Self.dateFormatter.string(from: issueDate)
        let timestampString = Self.timestampFormatter.string(from: recordTimestamp)
        let taxString = Self.decimalString(totalTax)
        let amountString = Self.decimalString(totalAmount)

        return [
            issuerTaxId,
            invoiceNumber,
            dateString,
            invoiceType.rawValue,
            taxString,
            amountString,
            previousHash,
            timestampString
        ].joined(separator: "&")
    }

    /// Formats a Decimal with exactly 2 decimal places for canonical representation.
    private static func decimalString(_ value: Decimal) -> String {
        let handler = NSDecimalNumberHandler(
            roundingMode: .bankers,
            scale: 2,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        let rounded = NSDecimalNumber(decimal: value).rounding(accordingToBehavior: handler)
        return String(format: "%.2f", rounded.doubleValue)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: "Europe/Madrid")
        return formatter
    }()

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy HH:mm:ss"
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: "Europe/Madrid")
        return formatter
    }()
}
