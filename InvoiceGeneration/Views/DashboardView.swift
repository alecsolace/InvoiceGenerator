import Charts
import Foundation
import SwiftUI
import SwiftData

/// Dashboard with invoice status and revenue charts
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Issuer.name)]) private var issuers: [Issuer]
    @AppStorage(IssuerSelectionStore.appStorageKey) private var selectedIssuerStorage = IssuerSelectionStore.allIssuersToken

    @State private var viewModel: DashboardViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
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
        .onChange(of: selectedIssuerStorage) { _, _ in
            applyIssuerFilter()
        }
        .onChange(of: issuers.count) { _, _ in
            applyIssuerFilter()
        }
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
                Button("All Emitters") {
                    selectedIssuerStorage = IssuerSelectionStore.allIssuersToken
                }

                ForEach(issuers) { issuer in
                    Button(issuer.name) {
                        selectedIssuerStorage = issuer.id.uuidString
                    }
                }
            } label: {
                Label(issuerFilterLabel, systemImage: "building.2")
            }
        }
    }

    private var issuerFilterLabel: String {
        guard let selectedID = IssuerSelectionStore.issuerID(from: selectedIssuerStorage),
              let issuer = issuers.first(where: { $0.id == selectedID })
        else {
            return "All Emitters"
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
        let selectedID = IssuerSelectionStore.issuerID(from: selectedIssuerStorage)
        if let selectedID, let issuer = issuers.first(where: { $0.id == selectedID }) {
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
            InvoiceStatus.draft.localizedTitle: .gray,
            InvoiceStatus.sent.localizedTitle: .blue,
            InvoiceStatus.paid.localizedTitle: .green,
            InvoiceStatus.overdue.localizedTitle: .red,
            InvoiceStatus.cancelled.localizedTitle: .orange
        ]
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self, Issuer.self])
}
