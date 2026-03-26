import Foundation
import SwiftData
import OSLog

/// Manages the submission of VeriFACTU registry records to AEAT's web service.
///
/// Currently supports:
/// - Local XML generation and export for manual submission
/// - Status tracking for submitted records
///
/// Future: Direct HTTPS submission to AEAT requires a digital certificate
/// (certificado electrónico) which is not yet supported on iOS.
enum VerifactuSubmissionService {

    private static let logger = Logger(subsystem: "InvoiceGeneration", category: "VerifactuSubmission")

    // MARK: - AEAT Endpoints

    /// Production AEAT SuministroLR endpoint
    private static let productionEndpoint = "https://www2.agenciatributaria.gob.es/wlpl/TIKE-CONT/ws/SuministroLRFacturasEmitidas"

    /// Pre-production (testing) AEAT endpoint
    private static let preProductionEndpoint = "https://prewww2.aeat.es/wlpl/TIKE-CONT/ws/SuministroLRFacturasEmitidas"

    /// Set to `true` to target the pre-production environment
    static var usePreProduction = true

    // MARK: - Export XML for Manual Submission

    /// Generates and exports the Alta XML for a single record.
    ///
    /// - Parameters:
    ///   - record: The VeriFACTU record
    ///   - invoice: The associated invoice
    ///   - issuer: The issuer
    /// - Returns: URL of the exported XML file, or nil on failure
    static func exportAltaXML(
        record: VerifactuRecord,
        invoice: Invoice,
        issuer: Issuer
    ) -> URL? {
        let xml = VerifactuXMLService.generateAltaXML(
            record: record,
            invoice: invoice,
            issuer: issuer
        )
        let fileName = "Alta_\(record.invoiceNumber)_\(record.sequenceNumber)"
        return VerifactuXMLService.exportToFile(xml: xml, fileName: fileName)
    }

    /// Generates and exports the Anulación XML for a cancellation record.
    static func exportAnulacionXML(
        record: VerifactuRecord,
        issuer: Issuer
    ) -> URL? {
        let xml = VerifactuXMLService.generateAnulacionXML(
            record: record,
            issuer: issuer
        )
        let fileName = "Anulacion_\(record.invoiceNumber)_\(record.sequenceNumber)"
        return VerifactuXMLService.exportToFile(xml: xml, fileName: fileName)
    }

    /// Exports all pending records for an issuer as a batch XML.
    static func exportPendingRecords(
        for issuer: Issuer,
        context: ModelContext
    ) -> URL? {
        let records = (issuer.verifactuRecords ?? [])
            .filter { $0.submissionStatus == .pending && !$0.isCancellation }
            .sorted { $0.sequenceNumber < $1.sequenceNumber }

        guard !records.isEmpty else { return nil }

        let entries: [(record: VerifactuRecord, invoice: Invoice)] = records.compactMap { record in
            guard let invoice = record.invoice else { return nil }
            return (record, invoice)
        }

        guard !entries.isEmpty else { return nil }

        let xml = VerifactuXMLService.generateBatchAltaXML(records: entries, issuer: issuer)
        let fileName = "Batch_\(issuer.taxId)_\(dateString(Date()))"
        return VerifactuXMLService.exportToFile(xml: xml, fileName: fileName)
    }

    // MARK: - Status Management

    /// Marks a record as submitted (for use after manual submission via web portal).
    static func markAsSubmitted(_ record: VerifactuRecord) {
        record.submissionStatus = .submitted
        record.submissionDate = Date()
        logger.info("Record \(record.invoiceNumber) #\(record.sequenceNumber) marked as submitted")
    }

    /// Marks a record as accepted by AEAT.
    static func markAsAccepted(_ record: VerifactuRecord, response: String? = nil) {
        record.submissionStatus = .accepted
        record.submissionResponse = response
        logger.info("Record \(record.invoiceNumber) #\(record.sequenceNumber) accepted by AEAT")
    }

    /// Marks a record as rejected by AEAT.
    static func markAsRejected(_ record: VerifactuRecord, response: String? = nil) {
        record.submissionStatus = .rejected
        record.submissionResponse = response
        logger.warning("Record \(record.invoiceNumber) #\(record.sequenceNumber) rejected by AEAT")
    }

    // MARK: - Statistics

    /// Returns submission statistics for an issuer.
    static func statistics(for issuer: Issuer) -> SubmissionStatistics {
        let records = issuer.verifactuRecords ?? []
        return SubmissionStatistics(
            total: records.count,
            pending: records.filter { $0.submissionStatus == .pending }.count,
            submitted: records.filter { $0.submissionStatus == .submitted }.count,
            accepted: records.filter { $0.submissionStatus == .accepted }.count,
            rejected: records.filter { $0.submissionStatus == .rejected }.count
        )
    }

    // MARK: - Private

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

struct SubmissionStatistics {
    let total: Int
    let pending: Int
    let submitted: Int
    let accepted: Int
    let rejected: Int

    var hasUnsubmitted: Bool { pending > 0 }
}
