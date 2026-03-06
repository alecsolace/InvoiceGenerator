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
    @discardableResult
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
    ) -> Invoice? {
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
        guard saveContext() else { return nil }
        fetchInvoices()
        return invoice
    }

    @discardableResult
    func createInvoice(fromTemplate template: InvoiceTemplate, month: Date = Date()) -> Invoice? {
        guard let issuer = template.issuer else {
            errorMessage = "La plantilla no tiene emisor asociado."
            return nil
        }

        let issueDate = preferredIssueDate(for: month)
        let dueDays = max(template.dueDays, 0)

        let items = template.items
            .sorted { $0.sortOrder < $1.sortOrder }
            .map {
                InvoiceLineItemInput(
                    description: $0.itemDescription,
                    quantity: $0.quantity,
                    unitPrice: $0.unitPrice
                )
            }

        return createInvoice(
            invoiceNumber: InvoiceNumberingService.nextInvoiceNumber(for: issuer),
            issuer: issuer,
            clientName: template.client?.name ?? template.clientName,
            clientEmail: template.client?.email ?? template.clientEmail,
            clientIdentificationNumber: template.client?.identificationNumber ?? template.clientIdentificationNumber,
            clientAddress: template.client?.address ?? template.clientAddress,
            client: template.client,
            issueDate: issueDate,
            dueDate: issueDate.addingDays(dueDays > 0 ? dueDays : InvoiceFlowPreferences.defaultDueDays),
            notes: template.notes,
            ivaPercentage: template.ivaPercentage,
            irpfPercentage: template.irpfPercentage,
            items: items
        )
    }

    @discardableResult
    func duplicateInvoiceForNextMonth(_ invoice: Invoice) -> Invoice? {
        guard let issuer = resolveIssuer(for: invoice) else {
            errorMessage = "No se pudo resolver el emisor para duplicar la factura."
            return nil
        }

        let issueDate = invoice.issueDate.addingMonths(1)
        let dueDays = max(Calendar.current.dateComponents([.day], from: invoice.issueDate, to: invoice.dueDate).day ?? 0, 0)
        let items = invoice.items.map {
            InvoiceLineItemInput(
                description: $0.itemDescription,
                quantity: $0.quantity,
                unitPrice: $0.unitPrice
            )
        }

        return createInvoice(
            invoiceNumber: InvoiceNumberingService.nextInvoiceNumber(for: issuer),
            issuer: issuer,
            clientName: invoice.clientName,
            clientEmail: invoice.clientEmail,
            clientIdentificationNumber: invoice.clientIdentificationNumber,
            clientAddress: invoice.clientAddress,
            client: invoice.client,
            issueDate: issueDate,
            dueDate: issueDate.addingDays(dueDays),
            notes: invoice.notes,
            ivaPercentage: invoice.ivaPercentage,
            irpfPercentage: invoice.irpfPercentage,
            items: items
        )
    }

    /// Update an existing invoice
    func updateInvoice(_ invoice: Invoice) {
        invoice.updateTimestamp()
        invoice.calculateTotal()
        _ = saveContext()
        fetchInvoices()
    }

    /// Delete an invoice
    func deleteInvoice(_ invoice: Invoice) {
        modelContext.delete(invoice)
        _ = saveContext()
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
        _ = saveContext()
        fetchInvoices()
    }

    /// Remove item from invoice
    func removeItem(_ item: InvoiceItem, from invoice: Invoice) {
        if let index = invoice.items.firstIndex(where: { $0.id == item.id }) {
            invoice.items.remove(at: index)
            modelContext.delete(item)
            invoice.calculateTotal()
            invoice.updateTimestamp()
            _ = saveContext()
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
        _ = saveContext()
        fetchInvoices()
    }

    /// Update invoice status
    func updateStatus(_ invoice: Invoice, status: InvoiceStatus) {
        invoice.status = status
        invoice.updateTimestamp()
        _ = saveContext()
        fetchInvoices()
    }

    func markSent(_ invoice: Invoice) {
        updateStatus(invoice, status: .sent)
    }

    func markPaid(_ invoice: Invoice) {
        updateStatus(invoice, status: .paid)
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

    private func preferredIssueDate(for month: Date) -> Date {
        let now = Date()
        let calendar = Calendar.current

        if calendar.isDate(month, equalTo: now, toGranularity: .month) {
            return now
        }

        return month.startOfMonth
    }

    private func resolveIssuer(for invoice: Invoice) -> Issuer? {
        if let issuer = invoice.issuer {
            return issuer
        }

        guard !invoice.issuerCode.isEmpty else { return nil }

        do {
            let descriptor = FetchDescriptor<Issuer>(
                sortBy: [SortDescriptor(\.name)]
            )
            let issuers = try modelContext.fetch(descriptor)
            return issuers.first {
                $0.code.caseInsensitiveCompare(invoice.issuerCode) == .orderedSame
            }
        } catch {
            errorMessage = "No se pudo localizar el emisor: \(error.localizedDescription)"
            return nil
        }
    }
}

/// Lightweight container so callers can seed invoices with items
struct InvoiceLineItemInput {
    let description: String
    let quantity: Int
    let unitPrice: Decimal
}
