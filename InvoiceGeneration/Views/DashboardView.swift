import Charts
import Foundation
import SwiftUI
import SwiftData

/// Dashboard with invoice status and revenue charts
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Issuer.name)]) private var issuers: [Issuer]
    @State private var selectedIssuerID: UUID?
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            dashboardSummaryCards(viewModel: viewModel)
                            statusSection(viewModel: viewModel)
                            revenueSection(viewModel: viewModel)
                        }
                        .padding()
                    }
                    .background(Color.appBackground.ignoresSafeArea())
                } else {
                    ProgressView("Loading dashboard…")
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                issuerFilterMenu
                refreshButton
            }
        }
        .onAppear {
            loadViewModelIfNeeded()
            applyIssuerFilter()
        }
        .onChange(of: selectedIssuerID) { _, _ in
            applyIssuerFilter()
        }
        .onChange(of: issuers.count) { _, _ in
            applyIssuerFilter()
        }
    }

    private func dashboardSummaryCards(viewModel: DashboardViewModel) -> some View {
        let totalInvoices = viewModel.statusSummaries.reduce(0) { $0 + $1.count }
        let paidCount = viewModel.statusSummaries.first(where: { $0.status == .paid })?.count ?? 0
        let overdueCount = viewModel.statusSummaries.first(where: { $0.status == .overdue })?.count ?? 0
        let totalRevenue = Decimal(viewModel.monthlyRevenue.reduce(0.0) { $0 + $1.total })

        return SummaryCardRow(cards: [
            SummaryCardData(title: String(localized: "Total facturas"), value: "\(totalInvoices)", tint: .blue),
            SummaryCardData(title: String(localized: "Cobradas"), value: "\(paidCount)", tint: .green),
            SummaryCardData(title: String(localized: "Vencidas"), value: "\(overdueCount)", tint: .red),
            SummaryCardData(title: String(localized: "Ingresos"), value: totalRevenue.formattedAsCurrency, tint: .blue),
        ])
    }

    private func statusSection(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estados de facturas")
                .font(.title2)
                .fontWeight(.semibold)

            if viewModel.statusSummaries.isEmpty {
                Text("Aún no hay facturas para mostrar.")
                    .foregroundStyle(.secondary)
            } else {
                let statusDimLabel = statusDimensionLabel
                let countLabel = statusCountLabel

                Chart(viewModel.statusSummaries) { summary in
                    SectorMark(
                        angle: .value(countLabel, summary.count),
                        innerRadius: .ratio(0.6)
                    )
                    .foregroundStyle(by: .value(statusDimLabel, summary.status.localizedTitle))
                    .annotation(position: .overlay) {
                        VStack {
                            Text(summary.status.localizedTitle)
                                .font(.caption)
                            Text("\(summary.count)")
                                .font(.headline)
                        }
                        .padding(6)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .chartLegend(.visible)
                .chartForegroundStyleScale(statusColorScale)
                .frame(height: 260)
            }
        }
        .padding(16)
        .cardStyle(cornerRadius: 16)
    }

    private func revenueSection(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingresos cobrados por mes")
                .font(.title2)
                .fontWeight(.semibold)

            if viewModel.monthlyRevenue.isEmpty {
                Text("No hay facturas pagadas todavía.")
                    .foregroundStyle(.secondary)
            } else {
                let monthAxisLabelText = monthAxisLabel
                let revenueAxisTitleText = revenueAxisTitle

                Chart(viewModel.monthlyRevenue) { revenue in
                    BarMark(
                        x: .value(monthAxisLabelText, revenue.month, unit: .month),
                        y: .value(revenueAxisTitleText, revenue.total)
                    )
                    .foregroundStyle(.blue.gradient)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        if let dateValue = value.as(Date.self) {
                            AxisGridLine()
                            AxisValueLabel(self.monthLabel(for: dateValue))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 260)
            }
        }
        .padding(16)
        .cardStyle(cornerRadius: 16)
    }

    @ToolbarContentBuilder
    private var refreshButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(action: {
                applyIssuerFilter()
                viewModel?.fetchInvoices()
            }) {
                Label("Refrescar", systemImage: "arrow.clockwise")
            }
        }
    }

    @ToolbarContentBuilder
    private var issuerFilterMenu: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Menu {
                Button(String(localized: "Todos los emisores")) {
                    selectedIssuerID = nil
                }

                ForEach(issuers) { issuer in
                    Button(issuer.name) {
                        selectedIssuerID = issuer.id
                    }
                }
            } label: {
                Label(issuerFilterLabel, systemImage: "building.2")
            }
        }
    }

    private var issuerFilterLabel: String {
        guard let selectedIssuerID,
              let issuer = issuers.first(where: { $0.id == selectedIssuerID })
        else {
            return String(localized: "Todos los emisores")
        }

        return issuer.name
    }

    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    private func loadViewModelIfNeeded() {
        if viewModel == nil {
            viewModel = DashboardViewModel(modelContext: modelContext)
        }
    }

    private func applyIssuerFilter() {
        guard let viewModel else { return }
        if let selectedIssuerID, let issuer = issuers.first(where: { $0.id == selectedIssuerID }) {
            viewModel.filterByIssuer(issuer)
        } else {
            viewModel.filterByIssuer(nil)
        }
    }

    private var statusCountLabel: String {
        NSLocalizedString("Cantidad", comment: "Chart label for invoice count")
    }

    private var statusDimensionLabel: String {
        NSLocalizedString("Estado", comment: "Chart label for invoice status")
    }

    private var monthAxisLabel: String {
        NSLocalizedString("Mes", comment: "Chart label for months")
    }

    private var revenueAxisTitle: String {
        NSLocalizedString("Ingresos", comment: "Chart label for revenue")
    }

    private var statusColorScale: KeyValuePairs<String, Color> {
        [
            InvoiceStatus.draft.localizedTitle: InvoiceStatus.draft.color,
            InvoiceStatus.sent.localizedTitle: InvoiceStatus.sent.color,
            InvoiceStatus.paid.localizedTitle: InvoiceStatus.paid.color,
            InvoiceStatus.overdue.localizedTitle: InvoiceStatus.overdue.color,
            InvoiceStatus.cancelled.localizedTitle: InvoiceStatus.cancelled.color
        ]
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self, Issuer.self])
}
