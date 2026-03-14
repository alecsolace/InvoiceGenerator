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
            invoice.items?.append(invoiceItem)
            modelContext.insert(invoiceItem)
        }

        if let client {
            InvoiceNumberingService.registerUsedInvoiceNumber(invoiceNumber, for: client, issuer: issuer)
        } else {
            InvoiceNumberingService.registerUsedInvoiceNumber(invoiceNumber, for: issuer)
        }
        invoice.calculateTotal()
        guard saveContext() else { return nil }
        fetchInvoices()

        if SubscriptionService.shared.syncEnabled {
            Task {
                do { try await CloudKitService.shared.syncInvoices([invoice]) }
                catch { PersistenceController.logger.error("CloudKit invoice sync failed: \(error.localizedDescription)") }
            }
        }

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

        let items = (template.items ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .map {
                InvoiceLineItemInput(
                    description: $0.itemDescription,
                    quantity: $0.quantity,
                    unitPrice: $0.unitPrice
                )
            }

        let invoiceNum = template.client.map {
            InvoiceNumberingService.nextInvoiceNumber(for: $0, issuer: issuer)
        } ?? InvoiceNumberingService.nextInvoiceNumber(for: issuer)

        return createInvoice(
            invoiceNumber: invoiceNum,
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
        let items = (invoice.items ?? []).map {
            InvoiceLineItemInput(
                description: $0.itemDescription,
                quantity: $0.quantity,
                unitPrice: $0.unitPrice
            )
        }

        let invoiceNum = invoice.client.map {
            InvoiceNumberingService.nextInvoiceNumber(for: $0, issuer: issuer)
        } ?? InvoiceNumberingService.nextInvoiceNumber(for: issuer)

        return createInvoice(
            invoiceNumber: invoiceNum,
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

        if SubscriptionService.shared.syncEnabled {
            Task {
                do { try await CloudKitService.shared.syncInvoices([invoice]) }
                catch { PersistenceController.logger.error("CloudKit invoice sync failed: \(error.localizedDescription)") }
            }
        }
    }

    func updateInvoice(
        _ invoice: Invoice,
        invoiceNumber: String,
        issuer: Issuer?,
        clientName: String,
        clientEmail: String,
        clientIdentificationNumber: String,
        clientAddress: String,
        client: Client?,
        issueDate: Date,
        dueDate: Date,
        notes: String,
        ivaPercentage: Decimal,
        irpfPercentage: Decimal,
        items: [InvoiceLineItemInput]
    ) {
        invoice.invoiceNumber = invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        invoice.clientName = clientName
        invoice.clientEmail = clientEmail
        invoice.clientIdentificationNumber = clientIdentificationNumber
        invoice.clientAddress = clientAddress
        invoice.client = client
        invoice.issuer = issuer
        invoice.issueDate = issueDate
        invoice.dueDate = dueDate
        invoice.notes = notes
        invoice.ivaPercentage = ivaPercentage
        invoice.irpfPercentage = irpfPercentage

        if let issuer {
            invoice.captureIssuerSnapshot(from: issuer)
            if let client {
                InvoiceNumberingService.registerUsedInvoiceNumber(invoice.invoiceNumber, for: client, issuer: issuer)
            } else {
                InvoiceNumberingService.registerUsedInvoiceNumber(invoice.invoiceNumber, for: issuer)
            }
        } else {
            invoice.issuerName = ""
            invoice.issuerCode = ""
            invoice.issuerOwnerName = ""
            invoice.issuerEmail = ""
            invoice.issuerPhone = ""
            invoice.issuerAddress = ""
            invoice.issuerTaxId = ""
        }

        replaceItems(for: invoice, with: items)
        updateInvoice(invoice)
    }

    /// Delete an invoice
    func deleteInvoice(_ invoice: Invoice) {
        let invoiceID = invoice.id
        modelContext.delete(invoice)
        _ = saveContext()
        fetchInvoices()

        if SubscriptionService.shared.syncEnabled {
            Task {
                do { try await CloudKitService.shared.deleteInvoice(with: invoiceID) }
                catch { PersistenceController.logger.error("CloudKit invoice delete failed: \(error.localizedDescription)") }
            }
        }
    }

    /// Add item to invoice
    func addItem(to invoice: Invoice, description: String, quantity: Int, unitPrice: Decimal) {
        let item = InvoiceItem(
            description: description,
            quantity: quantity,
            unitPrice: unitPrice
        )
        item.invoice = invoice
        invoice.items?.append(item)
        invoice.calculateTotal()
        invoice.updateTimestamp()

        modelContext.insert(item)
        _ = saveContext()
        fetchInvoices()
    }

    /// Remove item from invoice
    func removeItem(_ item: InvoiceItem, from invoice: Invoice) {
        if let index = invoice.items?.firstIndex(where: { $0.id == item.id }) {
            invoice.items?.remove(at: index)
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

        if SubscriptionService.shared.syncEnabled {
            Task {
                do { try await CloudKitService.shared.syncInvoices([invoice]) }
                catch { PersistenceController.logger.error("CloudKit invoice sync failed: \(error.localizedDescription)") }
            }
        }
    }

    func markSent(_ invoice: Invoice) {
        updateStatus(invoice, status: .sent)
    }

    func markPaid(_ invoice: Invoice) {
        updateStatus(invoice, status: .paid)
    }

    @discardableResult
    func syncLinkedData(into invoice: Invoice) -> InvoiceSyncResult {
        var result = InvoiceSyncResult()

        if let client = invoice.client {
            invoice.clientName = client.name
            invoice.clientEmail = client.email
            invoice.clientIdentificationNumber = client.identificationNumber
            invoice.clientAddress = client.address
            result.didSyncClient = true
        } else {
            result.missingSources.append("cliente")
        }

        if let issuer = invoice.issuer ?? resolveIssuer(for: invoice) {
            invoice.issuer = issuer
            invoice.captureIssuerSnapshot(from: issuer)
            result.didSyncIssuer = true
        } else {
            result.missingSources.append("emisor")
        }

        updateInvoice(invoice)
        return result
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

    private func replaceItems(for invoice: Invoice, with items: [InvoiceLineItemInput]) {
        for existingItem in invoice.items ?? [] {
            modelContext.delete(existingItem)
        }
        invoice.items?.removeAll()

        for item in items {
            let invoiceItem = InvoiceItem(
                description: item.description,
                quantity: item.quantity,
                unitPrice: item.unitPrice
            )
            invoiceItem.invoice = invoice
            invoice.items?.append(invoiceItem)
            modelContext.insert(invoiceItem)
        }
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

struct InvoiceSyncResult {
    var didSyncClient = false
    var didSyncIssuer = false
    var missingSources: [String] = []

    var message: String {
        if missingSources.isEmpty {
            return "Datos sincronizados con el cliente y emisor actuales."
        }

        return "Sincronizacion parcial. Falta enlace de \(missingSources.joined(separator: " y "))."
    }
}
