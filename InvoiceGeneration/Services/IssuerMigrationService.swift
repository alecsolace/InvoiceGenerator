import Foundation
import OSLog
import SwiftData

enum IssuerMigrationService {

    /// Legacy hardcoded fallback name written before this issuer's name was localized.
    /// Kept only so `runIfNeeded` can find and rename issuers created under the old value.
    private static let legacyDefaultIssuerName = "Default Issuer"

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
                let issuerName = (name?.isEmpty == false) ? name! : defaultIssuerName

                let defaultIssuer = Issuer(
                    name: issuerName,
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

            // Backfill: rename any issuer still carrying the old hardcoded English
            // fallback name, and refresh the issuer-name snapshot on its invoices.
            for issuer in issuers where issuer.name == legacyDefaultIssuerName {
                issuer.name = defaultIssuerName
                issuer.updateTimestamp()
                changed = true
            }

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
                } else if invoice.issuerName == legacyDefaultIssuerName, let issuer = invoice.issuer {
                    invoice.captureIssuerSnapshot(from: issuer)
                    changed = true
                }
            }

            if changed {
                try modelContext.save()
            }
        } catch {
            PersistenceController.logger.error("Issuer migration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private static var defaultIssuerName: String {
        String(localized: "Emisor predeterminado", comment: "Fallback name for the issuer created by the first-run migration when no company profile name is available")
    }
}
