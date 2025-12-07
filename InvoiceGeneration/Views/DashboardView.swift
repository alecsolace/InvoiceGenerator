import Charts
import SwiftUI
import SwiftData

/// Dashboard with invoice status and revenue charts
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            statusSection(viewModel: viewModel)
                            revenueSection(viewModel: viewModel)
                        }
                        .padding()
                    }
                } else {
                    ProgressView("Loading dashboard…")
                }
            }
            .navigationTitle("Dashboard")
            .toolbar { refreshButton }
        }
        .onAppear { loadViewModelIfNeeded() }
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
                Chart(viewModel.statusSummaries) { summary in
                    SectorMark(
                        angle: .value("Cantidad", summary.count),
                        innerRadius: .ratio(0.6)
                    )
                    .foregroundStyle(by: .value("Estado", summary.status.rawValue))
                    .annotation(position: .overlay) {
                        VStack {
                            Text(summary.status.rawValue)
                                .font(.caption)
                            Text("\(summary.count)")
                                .font(.headline)
                        }
                        .padding(6)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .chartLegend(.visible)
                .chartForegroundStyleScale(statusColorScale)
                .frame(height: 260)
            }
        }
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
                Chart(viewModel.monthlyRevenue) { revenue in
                    BarMark(
                        x: .value("Mes", revenue.month, unit: .month),
                        y: .value("Ingresos", revenue.total)
                    )
                    .foregroundStyle(.blue.gradient)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        if let dateValue = value.as(Date.self) {
                            AxisGridLine()
                            AxisValueLabel(monthLabel(for: dateValue))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 260)
            }
        }
    }

    @ToolbarContentBuilder
    private var refreshButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(action: { viewModel?.fetchInvoices() }) {
                Label("Refrescar", systemImage: "arrow.clockwise")
            }
        }
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
        } else {
            viewModel?.fetchInvoices()
        }
    }

    private var statusColorScale: [String: Color] {
        [
            InvoiceStatus.draft.rawValue: .gray,
            InvoiceStatus.sent.rawValue: .blue,
            InvoiceStatus.paid.rawValue: .green,
            InvoiceStatus.overdue.rawValue: .red,
            InvoiceStatus.cancelled.rawValue: .orange
        ]
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self])
}
