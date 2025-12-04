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
            errorMessage = String(
                localized: "invoice_fetch_error",
                defaultValue: "Failed to fetch invoices: %@",
                comment: "Error shown when invoices cannot be fetched",
                arguments: error.localizedDescription
            )
        }
        
        isLoading = false
    }
    
    /// Create a new invoice
    func createInvoice(
        invoiceNumber: String,
        clientName: String,
        clientEmail: String = "",
        clientAddress: String = ""
    ) {
        let invoice = Invoice(
            invoiceNumber: invoiceNumber,
            clientName: clientName,
            clientEmail: clientEmail,
            clientAddress: clientAddress
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
        guard !query.isEmpty else {
            fetchInvoices()
            return
        }
        
        do {
            let predicate = #Predicate<Invoice> { invoice in
                invoice.clientName.localizedStandardContains(query) ||
                invoice.invoiceNumber.localizedStandardContains(query)
            }
            let descriptor = FetchDescriptor<Invoice>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
            )
            invoices = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = String(
                localized: "invoice_search_error",
                defaultValue: "Search failed: %@",
                comment: "Error shown when invoice search fails",
                arguments: error.localizedDescription
            )
        }
    }
    
    /// Filter invoices by status
    func filterByStatus(_ status: InvoiceStatus?) {
        guard let status = status else {
            fetchInvoices()
            return
        }
        
        do {
            let predicate = #Predicate<Invoice> { invoice in
                invoice.status == status
            }
            let descriptor = FetchDescriptor<Invoice>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
            )
            invoices = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = String(
                localized: "invoice_filter_error",
                defaultValue: "Filter failed: %@",
                comment: "Error shown when filtering invoices fails",
                arguments: error.localizedDescription
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = String(
                localized: "invoice_save_error",
                defaultValue: "Failed to save: %@",
                comment: "Error shown when saving an invoice fails",
                arguments: error.localizedDescription
            )
        }
    }
}
