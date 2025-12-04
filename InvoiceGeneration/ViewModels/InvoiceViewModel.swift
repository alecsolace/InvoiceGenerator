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
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchInvoices()
    }
    
    /// Fetch all invoices from SwiftData
    func fetchInvoices() {
        isLoading = true
        errorMessage = nil
        
        do {
            let descriptor = FetchDescriptor<Invoice>(
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
        client: Client? = nil,
        issueDate: Date = Date(),
        dueDate: Date = Date().addingTimeInterval(30 * 24 * 60 * 60)
    ) {
        let invoice = Invoice(
            invoiceNumber: invoiceNumber,
            clientName: clientName,
            clientEmail: clientEmail,
            clientAddress: clientAddress,
            client: client,
            issueDate: issueDate,
            dueDate: dueDate
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
    
    /// Apply search and filter parameters to invoices
    func applyFilters(
        query: String,
        status: InvoiceStatus?,
        client: Client?
    ) {
        let predicate = #Predicate<Invoice> { invoice in
            let matchesStatus = status == nil || invoice.status == status!
            let matchesClient = client == nil || invoice.client?.id == client!.id
            let matchesQuery = query.isEmpty || invoice.clientName.localizedStandardContains(query) || invoice.invoiceNumber.localizedStandardContains(query)
            return matchesStatus && matchesClient && matchesQuery
        }

        do {
            let descriptor = FetchDescriptor<Invoice>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
            )
            invoices = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Filter failed: \(error.localizedDescription)"
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
