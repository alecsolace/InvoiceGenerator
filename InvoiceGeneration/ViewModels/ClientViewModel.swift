import Foundation
import Observation
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
                    client.email.localizedStandardContains(currentQuery)
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
        accentColorHex: String = Client.defaultAccentHex
    ) -> Client? {
        let client = Client(name: name, email: email, address: address, accentColorHex: accentColorHex)
        modelContext.insert(client)

        do {
            try modelContext.save()
            fetchClients()
            return client
        } catch {
            errorMessage = "Failed to save client: \(error.localizedDescription)"
            return nil
        }
    }

    func deleteClient(_ client: Client) {
        modelContext.delete(client)
        saveContext()
        fetchClients()
    }

    func searchClients(query: String) {
        searchQuery = query
        fetchClients()
    }

    // MARK: - Private Methods

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}
