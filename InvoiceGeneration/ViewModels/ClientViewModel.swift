import Foundation
import Observation
import OSLog
import SwiftData

/// ViewModel for managing clients
@Observable
final class ClientViewModel {
    private var modelContext: ModelContext
    private let sync: SyncCoordinator

    var clients: [Client] = []
    var isLoading = false
    var errorMessage: String?
    var searchQuery = ""

    init(modelContext: ModelContext, syncCoordinator: SyncCoordinator = .shared) {
        self.modelContext = modelContext
        self.sync = syncCoordinator
        fetchClients()
    }

    func fetchClients() {
        isLoading = true
        errorMessage = nil

        let currentQuery = searchQuery

        do {
            let descriptor = FetchDescriptor<Client>(
                predicate: currentQuery.isEmpty ? nil : #Predicate { client in
                    client.name.localizedStandardContains(currentQuery) ||
                    client.email.localizedStandardContains(currentQuery) ||
                    client.identificationNumber.localizedStandardContains(currentQuery)
                },
                sortBy: [SortDescriptor(\.name)]
            )
            clients = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = UserFacingError.message(for: .load, error: error)
        }

        isLoading = false
    }

    @discardableResult
    func createClient(
        name: String,
        email: String = "",
        address: String = "",
        identificationNumber: String = "",
        accentColorHex: String = Client.defaultAccentHex,
        defaultDueDays: Int = 0,
        defaultIVAPercentage: Decimal? = nil,
        defaultIRPFPercentage: Decimal? = nil,
        defaultNotes: String = "",
        preferredTemplateID: UUID? = nil,
        countryCode: String = "ES",
        locationType: ClientLocationType = .national
    ) -> Client? {
        let client = Client(
            name: name,
            email: email,
            address: address,
            identificationNumber: identificationNumber,
            accentColorHex: accentColorHex,
            defaultDueDays: defaultDueDays,
            defaultIVAPercentage: defaultIVAPercentage,
            defaultIRPFPercentage: defaultIRPFPercentage,
            defaultNotes: defaultNotes,
            preferredTemplateID: preferredTemplateID,
            countryCode: countryCode,
            locationType: locationType
        )
        modelContext.insert(client)

        do {
            try modelContext.save()
            fetchClients()
        } catch {
            PersistenceController.logger.error("Failed to save client: \(error.localizedDescription)")
            errorMessage = UserFacingError.message(for: .save, error: error)
            return nil
        }

        sync.syncClients([client])
        return client
    }

    @discardableResult
    func updateClient(
        _ client: Client,
        name: String,
        email: String,
        address: String,
        identificationNumber: String,
        accentColorHex: String,
        defaultDueDays: Int,
        defaultIVAPercentage: Decimal?,
        defaultIRPFPercentage: Decimal?,
        defaultNotes: String,
        preferredTemplateID: UUID?,
        countryCode: String = "ES",
        locationType: ClientLocationType = .national
    ) -> Bool {
        client.name = name
        client.email = email
        client.address = address
        client.identificationNumber = identificationNumber
        client.accentColorHex = accentColorHex
        client.defaultDueDays = max(defaultDueDays, 0)
        client.defaultIVAPercentage = defaultIVAPercentage
        client.defaultIRPFPercentage = defaultIRPFPercentage
        client.defaultNotes = defaultNotes
        client.preferredTemplateID = preferredTemplateID
        client.countryCode = countryCode
        client.locationType = locationType
        client.updateTimestamp()

        let saved = saveContext()
        if saved {
            fetchClients()
            sync.syncClients([client])
        }
        return saved
    }

    func client(with id: UUID?) -> Client? {
        guard let id else { return nil }
        return clients.first(where: { $0.id == id })
    }

    func deleteClient(_ client: Client) {
        let clientID = client.id
        modelContext.delete(client)
        _ = saveContext()
        fetchClients()

        sync.deleteClient(with: clientID)
    }

    func searchClients(query: String) {
        searchQuery = query
        fetchClients()
    }

    /// Sum of paid invoice totals for a given client.
    func totalRevenue(for client: Client) -> Decimal {
        guard let invoices = client.invoices else { return 0 }
        return invoices
            .filter { $0.status == .paid }
            .reduce(Decimal(0)) { $0 + $1.totalAmount }
    }

    // MARK: - Private Methods

    private func saveContext() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            PersistenceController.logger.error("SwiftData save failed: \(error.localizedDescription)")
            errorMessage = UserFacingError.message(for: .save, error: error)
            return false
        }
    }
}
