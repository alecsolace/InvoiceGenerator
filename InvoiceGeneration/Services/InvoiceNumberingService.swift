import Foundation

enum InvoiceNumberingService {
    static func nextInvoiceNumber(for issuer: Issuer) -> String {
        invoiceNumber(for: issuer, sequence: issuer.nextInvoiceSequence)
    }

    static func invoiceNumber(for issuer: Issuer, sequence: Int) -> String {
        let code = normalizedCode(from: issuer.code)
        return "\(code)-\(formattedSequence(max(sequence, 1)))"
    }

    static func registerUsedInvoiceNumber(_ invoiceNumber: String, for issuer: Issuer) {
        let code = normalizedCode(from: issuer.code)
        let current = max(issuer.nextInvoiceSequence, 1)

        guard let parsed = parse(invoiceNumber: invoiceNumber, expectedCode: code) else {
            return
        }

        if parsed >= current {
            issuer.nextInvoiceSequence = parsed + 1
            issuer.updateTimestamp()
        }
    }

    // MARK: - Client-scoped numbering

    static func nextInvoiceNumber(for client: Client, issuer: Issuer) -> String {
        invoiceNumber(for: client, issuer: issuer, sequence: client.nextInvoiceSequence)
    }

    static func invoiceNumber(for client: Client, issuer: Issuer, sequence: Int) -> String {
        let rawCode = client.invoiceCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? issuer.code
            : client.invoiceCode
        let code = normalizedCode(from: rawCode)
        return "\(code)-\(formattedSequence(max(sequence, 1)))"
    }

    static func registerUsedInvoiceNumber(_ invoiceNumber: String, for client: Client, issuer: Issuer) {
        let rawCode = client.invoiceCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? issuer.code
            : client.invoiceCode
        let code = normalizedCode(from: rawCode)
        let current = max(client.nextInvoiceSequence, 1)

        guard let parsed = parse(invoiceNumber: invoiceNumber, expectedCode: code) else {
            return
        }

        if parsed >= current {
            client.nextInvoiceSequence = parsed + 1
            client.updateTimestamp()
        }
    }

    static func sanitizeCode(_ raw: String) -> String {
        let normalized = normalizedCode(from: raw)
        return normalized.isEmpty ? "ISSUER" : normalized
    }

    static func defaultCodeCandidate(from name: String) -> String {
        let letters = name
            .uppercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map { String($0) }
            .joined()

        if letters.isEmpty {
            return "ISSUER"
        }

        if letters.count >= 3 {
            return String(letters.prefix(3))
        }

        return letters.padding(toLength: 3, withPad: "X", startingAt: 0)
    }

    static func sequence(from invoiceNumber: String, for issuer: Issuer) -> Int? {
        parse(invoiceNumber: invoiceNumber, expectedCode: normalizedCode(from: issuer.code))
    }

    private static func normalizedCode(from raw: String) -> String {
        let value = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        let filtered = value.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(filtered))
    }

    private static func parse(invoiceNumber: String, expectedCode: String) -> Int? {
        let uppercased = invoiceNumber.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "\(expectedCode)-"

        guard uppercased.hasPrefix(prefix) else {
            return nil
        }

        let suffix = String(uppercased.dropFirst(prefix.count))
        guard let sequence = Int(suffix), sequence > 0 else {
            return nil
        }

        return sequence
    }

    private static func formattedSequence(_ value: Int) -> String {
        String(format: "%04d", value)
    }
}
