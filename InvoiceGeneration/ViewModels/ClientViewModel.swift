import Foundation
import SwiftData
import Observation

/// ViewModel for managing saved clients
@Observable
final class ClientViewModel {
    private var modelContext: ModelContext

    var clients: [Client] = []
    var isLoading = false
    var errorMessage: String?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchClients()
    }

    func fetchClients() {
        isLoading = true
        errorMessage = nil

        do {
            let descriptor = FetchDescriptor<Client>(
                sortBy: [SortDescriptor(\.name)]
            )
            clients = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to fetch clients: \(error.localizedDescription)"
        }

        isLoading = false
    }

    @discardableResult
    func createClient(name: String, email: String = "", address: String = "") -> Client? {
        let client = Client(name: name, email: email, address: address)
        modelContext.insert(client)
        saveContext()
        fetchClients()
        return client
    }

    func updateClient(_ client: Client, name: String, email: String, address: String) {
        client.name = name
        client.email = email
        client.address = address
        client.updateTimestamp()

        saveContext()
        fetchClients()
    }

    func deleteClient(_ client: Client) {
        modelContext.delete(client)
        saveContext()
        fetchClients()
    }

    func searchClients(query: String) {
        guard !query.isEmpty else {
            fetchClients()
            return
        }

        do {
            let predicate = #Predicate<Client> { client in
                client.name.localizedStandardContains(query) ||
                client.email.localizedStandardContains(query)
            }
            let descriptor = FetchDescriptor<Client>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.name)]
            )
            clients = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
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
