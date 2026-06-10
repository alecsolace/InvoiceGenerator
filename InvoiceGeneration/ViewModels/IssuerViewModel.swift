import Foundation
import Observation
import OSLog
import SwiftData

@Observable
final class IssuerViewModel {
    private let modelContext: ModelContext
    private let sync: SyncCoordinator

    var issuers: [Issuer] = []
    var isLoading = false
    var errorMessage: String?

    init(modelContext: ModelContext, syncCoordinator: SyncCoordinator = .shared) {
        self.modelContext = modelContext
        self.sync = syncCoordinator
        fetchIssuers()
    }

    func fetchIssuers() {
        isLoading = true
        errorMessage = nil

        do {
            var descriptor = FetchDescriptor<Issuer>(sortBy: [SortDescriptor(\.name)])
            descriptor.predicate = #Predicate<Issuer> { !$0.isDeleted }
            issuers = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = UserFacingError.message(for: .load, error: error)
        }

        isLoading = false
    }

    @discardableResult
    func createIssuer(
        name: String,
        ownerName: String = "",
        email: String = "",
        phone: String = "",
        address: String = "",
        taxId: String = "",
        logoData: Data? = nil,
        defaultNotes: String = "",
        verifactuEnabled: Bool = false
    ) -> Issuer? {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Issuer name is required."
            return nil
        }

        let issuer = Issuer(
            name: name,
            ownerName: ownerName,
            email: email,
            phone: phone,
            address: address,
            taxId: taxId,
            logoData: logoData,
            defaultNotes: defaultNotes,
            verifactuEnabled: verifactuEnabled
        )

        modelContext.insert(issuer)

        guard saveContext() else { return nil }
        fetchIssuers()
        sync.syncIssuers([issuer])
        return issuer
    }

    @discardableResult
    func updateIssuer(
        _ issuer: Issuer,
        name: String,
        ownerName: String,
        email: String,
        phone: String,
        address: String,
        taxId: String,
        logoData: Data?,
        defaultNotes: String = "",
        verifactuEnabled: Bool = false
    ) -> Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Issuer name is required."
            return false
        }

        issuer.name = name
        issuer.ownerName = ownerName
        issuer.email = email
        issuer.phone = phone
        issuer.address = address
        issuer.taxId = taxId
        issuer.logoData = logoData
        issuer.defaultNotes = defaultNotes
        issuer.verifactuEnabled = verifactuEnabled
        issuer.updateTimestamp()

        let success = saveContext()
        if success {
            fetchIssuers()
            sync.syncIssuers([issuer])
        }

        return success
    }

    @discardableResult
    func deleteIssuer(_ issuer: Issuer) -> Bool {
        issuer.isDeleted = true
        issuer.updateTimestamp()

        let success = saveContext()
        if success {
            fetchIssuers()
            sync.syncIssuers([issuer])
        }
        return success
    }

    func issuer(with id: UUID?) -> Issuer? {
        guard let id else { return nil }
        return issuers.first(where: { $0.id == id })
    }

    // MARK: - Private

    private func saveContext() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            errorMessage = UserFacingError.message(for: .save, error: error)
            PersistenceController.logger.error("Failed to save issuer: \(error.localizedDescription)")
            return false
        }
    }
}
