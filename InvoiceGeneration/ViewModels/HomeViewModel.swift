import Foundation
import Observation
import SwiftData

@Observable
final class HomeViewModel {
    private let modelContext: ModelContext

    var templates: [InvoiceTemplate] = []
    var recentDrafts: [Invoice] = []
    var pendingInvoices: [Invoice] = []
    var frequentClients: [FrequentClientSummary] = []
    var thisMonthIssued: Decimal = 0
    var thisMonthPaid: Decimal = 0
    var pendingAmount: Decimal = 0
    var errorMessage: String?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refresh()
    }

    func refresh() {
        errorMessage = nil

        do {
            templates = try modelContext.fetch(
                FetchDescriptor<InvoiceTemplate>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
            )

            let invoices = try modelContext.fetch(
                FetchDescriptor<Invoice>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
            )
            let clients = try modelContext.fetch(
                FetchDescriptor<Client>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
            )

            recentDrafts = invoices
                .filter { $0.status == .draft }
                .prefix(5)
                .map { $0 }

            pendingInvoices = invoices
                .filter { $0.status == .sent || $0.status == .overdue }
                .sorted { $0.dueDate < $1.dueDate }
                .prefix(6)
                .map { $0 }

            frequentClients = frequentClientSummaries(clients: clients, invoices: invoices)

            let currentMonth = Date().startOfMonth
            let nextMonth = currentMonth.addingMonths(1)
            thisMonthIssued = invoices
                .filter { $0.issueDate >= currentMonth && $0.issueDate < nextMonth }
                .reduce(0) { $0 + $1.totalAmount }
            thisMonthPaid = invoices
                .filter { $0.status == .paid && $0.updatedAt >= currentMonth && $0.updatedAt < nextMonth }
                .reduce(0) { $0 + $1.totalAmount }
            pendingAmount = pendingInvoices.reduce(0) { $0 + $1.totalAmount }
        } catch {
            errorMessage = "No se pudo cargar Inicio: \(error.localizedDescription)"
        }
    }

    private func frequentClientSummaries(clients: [Client], invoices: [Invoice]) -> [FrequentClientSummary] {
        let grouped = Dictionary(grouping: invoices) { $0.client?.id }

        return clients.compactMap { client in
            guard let entries = grouped[client.id], !entries.isEmpty else { return nil }

            let sortedEntries = entries.sorted { $0.issueDate > $1.issueDate }
            return FrequentClientSummary(
                client: client,
                invoiceCount: entries.count,
                lastInvoiceDate: sortedEntries.first?.issueDate,
                preferredTemplateID: client.preferredTemplateID
            )
        }
        .sorted {
            if $0.invoiceCount == $1.invoiceCount {
                return ($0.lastInvoiceDate ?? .distantPast) > ($1.lastInvoiceDate ?? .distantPast)
            }
            return $0.invoiceCount > $1.invoiceCount
        }
        .prefix(6)
        .map { $0 }
    }
}

struct FrequentClientSummary: Identifiable {
    let client: Client
    let invoiceCount: Int
    let lastInvoiceDate: Date?
    let preferredTemplateID: UUID?

    var id: UUID { client.id }
}
