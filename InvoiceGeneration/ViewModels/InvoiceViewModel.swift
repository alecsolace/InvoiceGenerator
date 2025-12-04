import Foundation
import SwiftData
import Observation

/// ViewModel for managing invoices using MVVM pattern
@Observable
final class InvoiceViewModel {
    private var modelContext: ModelContext

    var invoices: [Invoice] = []
    var selectedInvoice: Invoice?
    var isLoading = false
    var errorMessage: String?
    var statusFilter: InvoiceStatus?
    var clientFilterID: UUID?
    var searchQuery = ""

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchInvoices()
    }

    /// Fetch all invoices from SwiftData
    func fetchInvoices() {
        isLoading = true
        errorMessage = nil

        let currentStatus = statusFilter
        let currentClientID = clientFilterID
        let currentQuery = searchQuery

        do {
            let descriptor = FetchDescriptor<Invoice>(
                predicate: #Predicate<Invoice> { invoice in
                    let matchesStatus = currentStatus == nil || invoice.status == currentStatus!
                    let matchesClient = currentClientID == nil || invoice.client?.id == currentClientID!

                    let matchesQuery: Bool
                    if !currentQuery.isEmpty {
                        matchesQuery = invoice.clientName.localizedStandardContains(currentQuery) ||
                            invoice.invoiceNumber.localizedStandardContains(currentQuery)
                    } else {
                        matchesQuery = true
                    }

                    return matchesStatus && matchesClient && matchesQuery
                },
                sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
            )
            invoices = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to fetch invoices: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Create a new invoice
    func createInvoice(
        invoiceNumber: String,
        clientName: String,
        clientEmail: String = "",
        clientAddress: String = "",
        client: Client? = nil
    ) {
        let invoice = Invoice(
            invoiceNumber: invoiceNumber,
            clientName: clientName,
            clientEmail: clientEmail,
            clientAddress: clientAddress,
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
    
    /// Search invoices by client name or invoice number
    func searchInvoices(query: String) {
        searchQuery = query
        fetchInvoices()
    }

    /// Filter invoices by status
    func filterByStatus(_ status: InvoiceStatus?) {
        statusFilter = status
        fetchInvoices()
    }

    /// Filter invoices by client
    func filterByClient(_ client: Client?) {
        clientFilterID = client?.id
        fetchInvoices()
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
