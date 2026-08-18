import Foundation
import OSLog
import SwiftData

/// One-shot, idempotent normalization of legacy zero-padded invoice numbers
/// ("0010" -> "10"), scoped per issuer-client pair. Numbers derived by
/// `InvoiceNumberingService` were never affected (`Int("0011")` already
/// parses as 11), so this only fixes display consistency.
///
/// Invoices with a VeriFACTU record have that record's `invoiceNumber`
/// updated too, and the owning issuer's hash chain is rebuilt afterwards,
/// since `recordHash` is derived in part from `invoiceNumber` and feeds the
/// next record's `previousHash`. A record already filed with AEAT
/// (`submissionStatus != .pending`) is rewritten the same way, but its old
/// hash is the only surviving evidence of what was actually filed, so that
/// case is logged loudly rather than silently. A passing
/// `VerifactuHashService.verifyChain` after this migration proves only that
/// the local chain is internally consistent again - not that it still
/// matches what AEAT holds for any record filed before the rename.
enum InvoiceNumberMigrationService {

    // MARK: - Entry Point

    @MainActor
    static func runIfNeeded(modelContext: ModelContext) {
        do {
            let invoices = try modelContext.fetch(FetchDescriptor<Invoice>())
            guard !invoices.isEmpty else { return }

            // Detect issuers whose VeriFACTU chain can't be safely rebuilt
            // *before* touching any record, so we never rewrite a record's
            // invoiceNumber and then bail out of recomputing its hash - that
            // would leave a record whose stored recordHash no longer matches
            // its own invoiceNumber, breaking verifyChain immediately.
            let issuers = try modelContext.fetch(FetchDescriptor<Issuer>())
            let unrechainableIssuerIDs = issuersWithDuplicateSequenceNumbers(issuers)

            let (renames, rectifiedNumbersChanged) = renameInvoices(
                invoices,
                unrechainableIssuerIDs: unrechainableIssuerIDs
            )
            guard !renames.isEmpty || rectifiedNumbersChanged else { return }

            if !renames.isEmpty {
                var affectedIssuers: Set<UUID> = []
                for invoice in invoices {
                    guard let rename = renames[invoice.id], let record = invoice.verifactuRecord else { continue }
                    record.invoiceNumber = rename.new
                    if let issuerID = record.issuer?.id {
                        affectedIssuers.insert(issuerID)
                    }
                }

                // Cancellation records never link back to an invoice, so they
                // can only be found by matching their stale number within the
                // issuer's chain. Only attempt this where the rename is
                // unambiguous.
                for issuer in issuers where !unrechainableIssuerIDs.contains(issuer.id) {
                    guard let issuerRenames = perIssuerOldToNew(for: issuer, renames: renames) else { continue }
                    var touchedThisIssuer = false
                    for record in issuer.verifactuRecords ?? [] where record.invoice == nil {
                        if let newNumber = issuerRenames[record.invoiceNumber] {
                            record.invoiceNumber = newNumber
                            touchedThisIssuer = true
                        }
                    }
                    if touchedThisIssuer {
                        affectedIssuers.insert(issuer.id)
                    }
                }

                for issuer in issuers where affectedIssuers.contains(issuer.id) {
                    rechain(issuer)
                }
            }

            try modelContext.save()
        } catch {
            PersistenceController.logger.error("Invoice number migration failed: \(error.localizedDescription)")
        }
    }

    /// Issuers whose VeriFACTU records contain duplicate sequence numbers.
    /// `verifyChain` sorts by that field alone, so a tie makes chain order
    /// ambiguous; renumbering and rechaining such an issuer could produce a
    /// chain that fails its own verification. Logged once, up front.
    private static func issuersWithDuplicateSequenceNumbers(_ issuers: [Issuer]) -> Set<UUID> {
        var result: Set<UUID> = []
        for issuer in issuers {
            let sequenceNumbers = (issuer.verifactuRecords ?? []).map(\.sequenceNumber)
            guard Set(sequenceNumbers).count != sequenceNumbers.count else { continue }
            PersistenceController.logger.error(
                "Invoice number migration will not rename invoices whose VeriFACTU record belongs to issuer \(issuer.id): duplicate VeriFACTU sequence numbers make the chain order ambiguous"
            )
            result.insert(issuer.id)
        }
        return result
    }

    // MARK: - Invoice Renumbering

    private struct Rename {
        let old: String
        let new: String
    }

    private struct PairKey: Hashable {
        let issuerID: UUID?
        let clientID: UUID?
    }

    /// Applied renames keyed by invoice id, plus whether any
    /// `rectifiedInvoiceNumber` reference was normalized. Invoices whose
    /// normalized number would collide with another invoice already using it
    /// within the same issuer-client pair are left untouched and logged, as
    /// are invoices whose VeriFACTU record belongs to an issuer we can't
    /// safely rechain - keeping `invoice.invoiceNumber` in sync with its
    /// record's `invoiceNumber` in that case.
    private static func renameInvoices(
        _ invoices: [Invoice],
        unrechainableIssuerIDs: Set<UUID>
    ) -> (renames: [UUID: Rename], rectifiedNumbersChanged: Bool) {
        var byPair: [PairKey: [Invoice]] = [:]
        for invoice in invoices {
            byPair[pairKey(for: invoice), default: []].append(invoice)
        }

        var renames: [UUID: Rename] = [:]

        for (_, pairInvoices) in byPair {
            var taken: Set<String> = []
            var candidates: [(invoice: Invoice, new: String)] = []

            for invoice in pairInvoices {
                let recordIssuerID = invoice.verifactuRecord?.issuer?.id
                let blockedByChain = recordIssuerID.map(unrechainableIssuerIDs.contains) ?? false
                if !blockedByChain, let normalized = InvoiceNumberingService.normalized(invoice.invoiceNumber) {
                    candidates.append((invoice, normalized))
                } else {
                    taken.insert(invoice.invoiceNumber)
                }
            }

            candidates.sort { lhs, rhs in
                if lhs.invoice.issueDate != rhs.invoice.issueDate {
                    return lhs.invoice.issueDate < rhs.invoice.issueDate
                }
                if lhs.invoice.createdAt != rhs.invoice.createdAt {
                    return lhs.invoice.createdAt < rhs.invoice.createdAt
                }
                return lhs.invoice.id.uuidString < rhs.invoice.id.uuidString
            }

            for candidate in candidates {
                guard !taken.contains(candidate.new) else {
                    PersistenceController.logger.warning(
                        "Invoice number migration skipped invoice \(candidate.invoice.id): normalizing '\(candidate.invoice.invoiceNumber)' to '\(candidate.new)' would collide with an existing number for this issuer/client pair"
                    )
                    continue
                }
                let old = candidate.invoice.invoiceNumber
                candidate.invoice.invoiceNumber = candidate.new
                candidate.invoice.updateTimestamp()
                taken.insert(candidate.new)
                renames[candidate.invoice.id] = Rename(old: old, new: candidate.new)
            }
        }

        // Rectified-invoice references are free-text pointers to another
        // invoice's number, not an identity - normalize them too, with no
        // collision check, so an R1-R5 correction doesn't end up pointing at
        // a number that no longer exists.
        var rectifiedNumbersChanged = false
        for invoice in invoices {
            guard !invoice.rectifiedInvoiceNumber.isEmpty,
                  let normalized = InvoiceNumberingService.normalized(invoice.rectifiedInvoiceNumber)
            else { continue }
            invoice.rectifiedInvoiceNumber = normalized
            rectifiedNumbersChanged = true
        }

        return (renames, rectifiedNumbersChanged)
    }

    private static func pairKey(for invoice: Invoice) -> PairKey {
        PairKey(issuerID: invoice.issuer?.id, clientID: invoice.client?.id)
    }

    // MARK: - VeriFACTU Re-chaining

    /// Maps this issuer's stale record numbers to their new value, using only
    /// renames that apply to this issuer. Returns nil when the same stale
    /// number maps to two different outcomes (e.g. one invoice was renamed,
    /// another with the same old number was skipped as a collision) - in
    /// that ambiguous case the issuer's cancellation records are left alone.
    private static func perIssuerOldToNew(for issuer: Issuer, renames: [UUID: Rename]) -> [String: String]? {
        let issuerInvoiceIDs = Set((issuer.invoices ?? []).map(\.id))
        var map: [String: String] = [:]
        for (invoiceID, rename) in renames {
            guard issuerInvoiceIDs.contains(invoiceID) else { continue }
            if let existing = map[rename.old], existing != rename.new {
                return nil
            }
            map[rename.old] = rename.new
        }
        return map
    }

    /// Rebuilds the issuer's VeriFACTU hash chain after one or more of its
    /// records had their `invoiceNumber` rewritten. Callers are expected to
    /// have already excluded issuers with duplicate sequence numbers via
    /// `issuersWithDuplicateSequenceNumbers` *before* any record was
    /// mutated - the check below is only a defense-in-depth backstop so this
    /// method can never leave a record's `recordHash` out of sync with its
    /// own `invoiceNumber`.
    private static func rechain(_ issuer: Issuer) {
        let records = (issuer.verifactuRecords ?? []).sorted { $0.sequenceNumber < $1.sequenceNumber }
        guard !records.isEmpty else { return }

        let sequenceNumbers = records.map(\.sequenceNumber)
        guard Set(sequenceNumbers).count == sequenceNumbers.count else {
            PersistenceController.logger.fault(
                "Invoice number migration reached rechain(_:) for issuer \(issuer.id) with duplicate VeriFACTU sequence numbers - this issuer should have been excluded upstream. Not touching its records."
            )
            return
        }

        var previousHash = VerifactuHashService.chainSentinel

        for record in records {
            let oldRecordHash = record.recordHash

            let newHash = VerifactuHashService.generateHash(
                issuerTaxId: record.issuerTaxId,
                invoiceNumber: record.invoiceNumber,
                issueDate: record.issueDate,
                invoiceType: record.invoiceType,
                totalTax: record.totalTax,
                totalAmount: record.totalAmount,
                previousHash: previousHash,
                recordTimestamp: record.recordTimestamp
            )

            if record.submissionStatus != .pending && newHash != oldRecordHash {
                logFiledRecordRewrite(record, issuer: issuer, oldHash: oldRecordHash, newHash: newHash)
            }

            record.previousHash = previousHash
            record.recordHash = newHash

            if !record.qrCodeUrl.isEmpty {
                record.qrCodeUrl = VerifactuQRService.verificationUrl(
                    issuerTaxId: record.issuerTaxId,
                    invoiceNumber: record.invoiceNumber,
                    issueDate: record.issueDate,
                    totalAmount: record.totalAmount
                )
            }

            previousHash = newHash
        }

        issuer.lastVerifactuHash = previousHash
        issuer.updateTimestamp()
    }

    // MARK: - Logging

    private static func logFiledRecordRewrite(
        _ record: VerifactuRecord,
        issuer: Issuer,
        oldHash: String,
        newHash: String
    ) {
        PersistenceController.logger.warning(
            """
            VeriFACTU re-chain rewrote a record already filed with AEAT - \
            issuer=\(issuer.id) record=\(record.id) seq=\(record.sequenceNumber) \
            status=\(record.submissionStatus.rawValue) number='\(record.invoiceNumber)' \
            hash \(oldHash) -> \(newHash) aeatResponse=\(record.submissionResponse ?? "none"). \
            Local chain no longer matches what AEAT holds for this record.
            """
        )
    }
}
