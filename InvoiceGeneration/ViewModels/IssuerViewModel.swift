import Foundation
import Observation
import OSLog
import SwiftData

@Observable
final class IssuerViewModel {
    private let modelContext: ModelContext

    var issuers: [Issuer] = []
    var isLoading = false
    var errorMessage: String?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchIssuers()
    }

    func fetchIssuers() {
        isLoading = true
        errorMessage = nil

        do {
            let descriptor = FetchDescriptor<Issuer>(sortBy: [SortDescriptor(\.name)])
            issuers = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to fetch issuers: \(error.localizedDescription)"
        }

        isLoading = false
    }

    @discardableResult
    func createIssuer(
        name: String,
        code: String,
        ownerName: String = "",
        email: String = "",
        phone: String = "",
        address: String = "",
        taxId: String = "",
        logoData: Data? = nil
    ) -> Issuer? {
        let normalizedCode = InvoiceNumberingService.sanitizeCode(code)

        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Issuer name is required."
            return nil
        }

        guard !isCodeTaken(normalizedCode) else {
            errorMessage = "Issuer code already exists."
            return nil
        }

        let issuer = Issuer(
            name: name,
            code: normalizedCode,
            ownerName: ownerName,
            email: email,
            phone: phone,
            address: address,
            taxId: taxId,
            logoData: logoData
        )

        modelContext.insert(issuer)

        if saveContext() {
            fetchIssuers()
            return issuer
        }

        return nil
    }

    @discardableResult
    func updateIssuer(
        _ issuer: Issuer,
        name: String,
        code: String,
        ownerName: String,
        email: String,
        phone: String,
        address: String,
        taxId: String,
        logoData: Data?
    ) -> Bool {
        let normalizedCode = InvoiceNumberingService.sanitizeCode(code)

        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Issuer name is required."
            return false
        }

        guard !isCodeTaken(normalizedCode, excluding: issuer.id) else {
            errorMessage = "Issuer code already exists."
            return false
        }

        issuer.name = name
        issuer.code = normalizedCode
        issuer.ownerName = ownerName
        issuer.email = email
        issuer.phone = phone
        issuer.address = address
        issuer.taxId = taxId
        issuer.logoData = logoData
        issuer.updateTimestamp()

        let success = saveContext()
        if success {
            fetchIssuers()
        }

        return success
    }

    @discardableResult
    func deleteIssuer(_ issuer: Issuer) -> Bool {
        if !(issuer.invoices ?? []).isEmpty {
            errorMessage = "You cannot delete an issuer with associated invoices."
            return false
        }

        modelContext.delete(issuer)
        let success = saveContext()
        if success {
            fetchIssuers()
        }
        return success
    }

    func issuer(with id: UUID?) -> Issuer? {
        guard let id else { return nil }
        return issuers.first(where: { $0.id == id })
    }

    // MARK: - Private

    private func isCodeTaken(_ code: String, excluding issuerID: UUID? = nil) -> Bool {
        issuers.contains { issuer in
            if let issuerID, issuer.id == issuerID {
                return false
            }
            return issuer.code.caseInsensitiveCompare(code) == .orderedSame
        }
    }

    private func saveContext() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            errorMessage = "Failed to save issuer: \(error.localizedDescription)"
            PersistenceController.logger.error("Failed to save issuer: \(error.localizedDescription)")
            return false
        }
    }
}
