import Foundation
import OSLog
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
    var issuerFilterID: UUID?
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
        let currentIssuerID = issuerFilterID
        let currentQuery = searchQuery

        do {
            let descriptor = FetchDescriptor<Invoice>(
                sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
            )
            var fetchedInvoices = try modelContext.fetch(descriptor)

            if let currentStatus {
                fetchedInvoices = fetchedInvoices.filter { $0.status == currentStatus }
            }

            if let currentClientID {
                fetchedInvoices = fetchedInvoices.filter { $0.client?.id == currentClientID }
            }

            if let currentIssuerID {
                fetchedInvoices = fetchedInvoices.filter { $0.issuer?.id == currentIssuerID }
            }

            if !currentQuery.isEmpty {
                fetchedInvoices = fetchedInvoices.filter { invoice in
                    invoice.clientName.localizedStandardContains(currentQuery) ||
                    invoice.clientIdentificationNumber.localizedStandardContains(currentQuery) ||
                    invoice.invoiceNumber.localizedStandardContains(currentQuery) ||
                    invoice.issuerName.localizedStandardContains(currentQuery) ||
                    invoice.issuerCode.localizedStandardContains(currentQuery)
                }
            }

            invoices = fetchedInvoices
        } catch {
            errorMessage = "Failed to fetch invoices: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Create a new invoice
    func createInvoice(
        invoiceNumber: String,
        issuer: Issuer,
        clientName: String,
        clientEmail: String = "",
        clientIdentificationNumber: String = "",
        clientAddress: String = "",
        client: Client? = nil,
        issueDate: Date = Date(),
        dueDate: Date = Date().addingTimeInterval(30 * 24 * 60 * 60),
        notes: String = "",
        ivaPercentage: Decimal = 0,
        irpfPercentage: Decimal = 0,
        items: [InvoiceLineItemInput] = []
    ) {
        let invoice = Invoice(
            invoiceNumber: invoiceNumber,
            clientName: clientName,
            clientEmail: clientEmail,
            clientIdentificationNumber: clientIdentificationNumber,
            clientAddress: clientAddress,
            client: client,
            issuer: issuer,
            issueDate: issueDate,
            dueDate: dueDate,
            notes: notes,
            ivaPercentage: ivaPercentage,
            irpfPercentage: irpfPercentage
        )

        invoice.captureIssuerSnapshot(from: issuer)
        modelContext.insert(invoice)

        for item in items {
            let invoiceItem = InvoiceItem(
                description: item.description,
                quantity: item.quantity,
                unitPrice: item.unitPrice
            )
            invoiceItem.invoice = invoice
            invoice.items.append(invoiceItem)
            modelContext.insert(invoiceItem)
        }

        InvoiceNumberingService.registerUsedInvoiceNumber(invoiceNumber, for: issuer)
        invoice.calculateTotal()
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
        fetchInvoices()
    }

    /// Remove item from invoice
    func removeItem(_ item: InvoiceItem, from invoice: Invoice) {
        if let index = invoice.items.firstIndex(where: { $0.id == item.id }) {
            invoice.items.remove(at: index)
            modelContext.delete(item)
            invoice.calculateTotal()
            invoice.updateTimestamp()
            saveContext()
            fetchInvoices()
        }
    }

    /// Update an existing invoice item with new values
    func updateItem(
        _ item: InvoiceItem,
        from invoice: Invoice,
        description: String,
        quantity: Int,
        unitPrice: Decimal
    ) {
        item.itemDescription = description
        item.quantity = quantity
        item.unitPrice = unitPrice
        item.updateTotal()
        invoice.calculateTotal()
        invoice.updateTimestamp()
        saveContext()
        fetchInvoices()
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

    /// Filter invoices by issuer
    func filterByIssuer(_ issuer: Issuer?) {
        issuerFilterID = issuer?.id
        fetchInvoices()
    }

    // MARK: - Private Methods

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            PersistenceController.logger.error("SwiftData save failed: \(error.localizedDescription)")
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}

/// Lightweight container so callers can seed invoices with items
struct InvoiceLineItemInput {
    let description: String
    let quantity: Int
    let unitPrice: Decimal
}
