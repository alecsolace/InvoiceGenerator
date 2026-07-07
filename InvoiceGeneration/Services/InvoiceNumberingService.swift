import Foundation

/// Recommends invoice numbers as plain natural numbers, scoped to an
/// issuer–client pair. The next number is always derived from the invoices
/// that already exist for that pair, so there is no counter to keep in sync.
enum InvoiceNumberingService {

    /// Recommended number for the next invoice of the given issuer–client pair.
    /// Returns the highest existing number for the pair plus one ("1" when the
    /// pair has no numeric invoices yet).
    static func nextInvoiceNumber(issuer: Issuer, client: Client?) -> String {
        String(nextSequence(issuer: issuer, client: client))
    }

    /// Next natural number in the issuer–client pair's series.
    static func nextSequence(issuer: Issuer, client: Client?) -> Int {
        (lastSequence(issuer: issuer, client: client) ?? 0) + 1
    }

    /// Highest invoice number already used for the issuer–client pair,
    /// or nil when the pair has no numeric invoices yet.
    static func lastSequence(issuer: Issuer, client: Client?) -> Int? {
        invoices(for: issuer, client: client)
            .compactMap { sequence(from: $0.invoiceNumber) }
            .max()
    }

    /// Parses an invoice number as a natural number. Returns nil for legacy
    /// or free-form numbers, which are ignored when recommending the next one.
    static func sequence(from invoiceNumber: String) -> Int? {
        let trimmed = invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else { return nil }
        return value
    }

    // MARK: - Private

    private static func invoices(for issuer: Issuer, client: Client?) -> [Invoice] {
        (issuer.invoices ?? []).filter { invoice in
            guard let client else { return invoice.client == nil }
            return invoice.client?.id == client.id
        }
    }
}
