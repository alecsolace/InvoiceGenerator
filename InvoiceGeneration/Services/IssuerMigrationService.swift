import Foundation
import OSLog
import SwiftData

enum IssuerMigrationService {
    @MainActor
    static func runIfNeeded(modelContext: ModelContext) {
        do {
            var issuers = try modelContext.fetch(
                FetchDescriptor<Issuer>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
            )
            var changed = false

            if issuers.isEmpty {
                let companyProfile = try modelContext.fetch(FetchDescriptor<CompanyProfile>()).first
                let name = companyProfile?.companyName.trimmingCharacters(in: .whitespacesAndNewlines)
                let issuerName = (name?.isEmpty == false) ? name! : "Default Issuer"
                let rawCode = companyProfile?.companyName ?? issuerName
                let code = InvoiceNumberingService.defaultCodeCandidate(from: rawCode)

                let defaultIssuer = Issuer(
                    name: issuerName,
                    code: code,
                    ownerName: companyProfile?.ownerName ?? "",
                    email: companyProfile?.email ?? "",
                    phone: companyProfile?.phone ?? "",
                    address: companyProfile?.address ?? "",
                    taxId: companyProfile?.taxId ?? ""
                )
                modelContext.insert(defaultIssuer)
                issuers = [defaultIssuer]
                changed = true
            }

            guard let primaryIssuer = issuers.first else { return }

            let invoices = try modelContext.fetch(FetchDescriptor<Invoice>())

            for invoice in invoices {
                if invoice.issuer == nil {
                    invoice.issuer = primaryIssuer
                    changed = true
                }

                if invoice.issuerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if let issuer = invoice.issuer {
                        invoice.captureIssuerSnapshot(from: issuer)
                    } else {
                        invoice.captureIssuerSnapshot(from: primaryIssuer)
                    }
                    changed = true
                }

                if let issuer = invoice.issuer {
                    let before = issuer.nextInvoiceSequence
                    InvoiceNumberingService.registerUsedInvoiceNumber(invoice.invoiceNumber, for: issuer)
                    if issuer.nextInvoiceSequence != before {
                        changed = true
                    }
                }
            }

            if changed {
                try modelContext.save()
            }
        } catch {
            PersistenceController.logger.error("Issuer migration failed: \(error.localizedDescription)")
        }
    }
}
