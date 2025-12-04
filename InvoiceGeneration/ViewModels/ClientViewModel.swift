import Foundation
import SwiftData
import Observation

/// ViewModel for managing stored clients
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

    func createClient(name: String, email: String, address: String, phone: String) -> Client {
        let client = Client(name: name, email: email, address: address, phone: phone)
        modelContext.insert(client)
        saveContext()
        fetchClients()
        return client
    }

    func updateClient(_ client: Client, name: String, email: String, address: String, phone: String) {
        client.name = name
        client.email = email
        client.address = address
        client.phone = phone
        client.updateTimestamp()
        saveContext()
        fetchClients()
    }

    func deleteClient(_ client: Client) {
        modelContext.delete(client)
        saveContext()
        fetchClients()
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}
