import Foundation
import SwiftData
import Observation

/// ViewModel for managing invoices using MVVM pattern
@Observable
final class InvoiceViewModel {
    private var modelContext: ModelContext
    private var lastSearchQuery = ""
    private var lastStatusFilter: InvoiceStatus?
    private var lastClientFilter: Client?
    
    var invoices: [Invoice] = []
    var selectedInvoice: Invoice?
    var isLoading = false
    var errorMessage: String?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchInvoices()
    }
    
    /// Fetch all invoices from SwiftData
    func fetchInvoices() {
        applyFilters(
            searchQuery: lastSearchQuery,
            status: lastStatusFilter,
            client: lastClientFilter
        )
    }
    
    /// Create a new invoice
    func createInvoice(
        invoiceNumber: String,
        client: Client?,
        clientName: String,
        clientEmail: String = "",
        clientAddress: String = ""
    ) {
        let resolvedName = client?.name ?? clientName
        let resolvedEmail = client?.email ?? clientEmail
        let resolvedAddress = client?.address ?? clientAddress

        let invoice = Invoice(
            invoiceNumber: invoiceNumber,
            clientName: resolvedName,
            clientEmail: resolvedEmail,
            clientAddress: resolvedAddress,
            client: client
        )
        
        modelContext.insert(invoice)
        saveContext()
        fetchInvoices()
    }
    
    /// Update an existing invoice
    func updateInvoice(_ invoice: Invoice) {
        invoice.updateTimestamp()
        invoice.calculateTotal()
        saveContext()
        fetchInvoices()
    }
    
    /// Delete an invoice
    func deleteInvoice(_ invoice: Invoice) {
        modelContext.delete(invoice)
        saveContext()
        fetchInvoices()
    }
    
    /// Add item to invoice
    func addItem(to invoice: Invoice, description: String, quantity: Int, unitPrice: Decimal) {
        let item = InvoiceItem(
            description: description,
            quantity: quantity,
            unitPrice: unitPrice
        )
        item.invoice = invoice
        invoice.items.append(item)
        invoice.calculateTotal()
        invoice.updateTimestamp()
        
        modelContext.insert(item)
        saveContext()
    }
    
    /// Remove item from invoice
    func removeItem(_ item: InvoiceItem, from invoice: Invoice) {
        if let index = invoice.items.firstIndex(where: { $0.id == item.id }) {
            invoice.items.remove(at: index)
            modelContext.delete(item)
            invoice.calculateTotal()
            invoice.updateTimestamp()
            saveContext()
        }
    }
    
    /// Update invoice status
    func updateStatus(_ invoice: Invoice, status: InvoiceStatus) {
        invoice.status = status
        invoice.updateTimestamp()
        saveContext()
        fetchInvoices()
    }
    
    /// Search and filter invoices by multiple criteria
    func applyFilters(
        searchQuery: String = "",
        status: InvoiceStatus? = nil,
        client: Client? = nil
    ) {
        isLoading = true
        errorMessage = nil

        let query = searchQuery
        let statusFilter = status
        let clientID = client?.id
        let clientName = client?.name ?? ""

        lastSearchQuery = searchQuery
        lastStatusFilter = status
        lastClientFilter = client

        do {
            let predicate = #Predicate<Invoice> { invoice in
                let matchesStatus: Bool
                if let statusFilter {
                    matchesStatus = invoice.status == statusFilter
                } else {
                    matchesStatus = true
                }

                let matchesClient: Bool
                if let clientID {
                    if let invoiceClient = invoice.client {
                        matchesClient = invoiceClient.id == clientID
                    } else {
                        matchesClient = invoice.clientName.localizedStandardContains(clientName)
                    }
                } else {
                    matchesClient = true
                }

                let matchesQuery = query.isEmpty ||
                    invoice.clientName.localizedStandardContains(query) ||
                    invoice.invoiceNumber.localizedStandardContains(query)

                return matchesStatus && matchesClient && matchesQuery
            }

            let descriptor = FetchDescriptor<Invoice>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
            )
            invoices = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Filter failed: \(error.localizedDescription)"
        }

        isLoading = false
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
