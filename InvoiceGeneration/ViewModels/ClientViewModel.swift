import Foundation
import Observation
import OSLog
import SwiftData

/// ViewModel for managing clients
@Observable
final class ClientViewModel {
    private var modelContext: ModelContext

    var clients: [Client] = []
    var isLoading = false
    var errorMessage: String?
    var searchQuery = ""

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
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
            errorMessage = "Failed to fetch clients: \(error.localizedDescription)"
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
        preferredTemplateID: UUID? = nil
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
            preferredTemplateID: preferredTemplateID
        )
        modelContext.insert(client)

        do {
            try modelContext.save()
            fetchClients()
        } catch {
            PersistenceController.logger.error("Failed to save client: \(error.localizedDescription)")
            errorMessage = "Failed to save client: \(error.localizedDescription)"
            return nil
        }

        if SubscriptionService.shared.syncEnabled {
            Task {
                do { try await CloudKitService.shared.syncClients([client]) }
                catch { PersistenceController.logger.error("CloudKit client sync failed: \(error.localizedDescription)") }
            }
        }

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
        preferredTemplateID: UUID?
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
        client.updateTimestamp()

        let saved = saveContext()
        if saved {
            fetchClients()
            if SubscriptionService.shared.syncEnabled {
                Task {
                    do { try await CloudKitService.shared.syncClients([client]) }
                    catch { PersistenceController.logger.error("CloudKit client sync failed: \(error.localizedDescription)") }
                }
            }
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

        if SubscriptionService.shared.syncEnabled {
            Task {
                do { try await CloudKitService.shared.deleteClient(with: clientID) }
                catch { PersistenceController.logger.error("CloudKit client delete failed: \(error.localizedDescription)") }
            }
        }
    }

    func searchClients(query: String) {
        searchQuery = query
        fetchClients()
    }

    // MARK: - Private Methods

    private func saveContext() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            PersistenceController.logger.error("SwiftData save failed: \(error.localizedDescription)")
            errorMessage = "Failed to save: \(error.localizedDescription)"
            return false
        }
    }
}
