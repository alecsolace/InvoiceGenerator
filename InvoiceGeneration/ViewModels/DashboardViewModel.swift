import Foundation
import Observation
import SwiftData

/// ViewModel for dashboard analytics
@Observable
final class DashboardViewModel {
    private let modelContext: ModelContext

    var invoices: [Invoice] = []
    var errorMessage: String?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchInvoices()
    }

    /// Refresh invoices for analytics calculations
    func fetchInvoices() {
        do {
            let descriptor = FetchDescriptor<Invoice>(
                sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
            )
            invoices = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load invoices: \(error.localizedDescription)"
        }
    }

    /// Count invoices by status for donut chart
    var statusSummaries: [InvoiceStatusSummary] {
        let counts = invoices.reduce(into: [:]) { partialResult, invoice in
            partialResult[invoice.status, default: 0] += 1
        }

        return InvoiceStatus.allCases.compactMap { status in
            guard let count = counts[status] else { return nil }
            return InvoiceStatusSummary(status: status, count: count)
        }
    }

    /// Monthly revenue based on paid invoices
    var monthlyRevenue: [MonthlyRevenue] {
        let paidInvoices = invoices.filter { $0.status == .paid }
        let calendar = Calendar.current

        let revenueByMonth = paidInvoices.reduce(into: [:]) { partialResult, invoice in
            let components = calendar.dateComponents([.year, .month], from: invoice.issueDate)
            guard let monthDate = calendar.date(from: components) else { return }

            let total = NSDecimalNumber(decimal: invoice.totalAmount).doubleValue
            partialResult[monthDate, default: 0] += total
        }

        return revenueByMonth
            .map { MonthlyRevenue(month: $0.key, total: $0.value) }
            .sorted { $0.month < $1.month }
    }
}

/// Aggregated invoice status data
struct InvoiceStatusSummary: Identifiable {
    let status: InvoiceStatus
    let count: Int

    var id: InvoiceStatus { status }
}

/// Aggregated monthly revenue from paid invoices
struct MonthlyRevenue: Identifiable {
    let month: Date
    let total: Double

    var id: Date { month }
}
