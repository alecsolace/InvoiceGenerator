import SwiftData
import SwiftUI

/// iPhone-specific dashboard view matching the Stitch "Panel de Control - Móvil" design.
struct iOSDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel: HomeViewModel?
    @State private var invoiceViewModel: InvoiceViewModel?
    @State private var composerSeed: InvoiceComposerSeed?
    @State private var selectedInvoice: Invoice?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel, let invoiceViewModel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            ytdBillingCard(viewModel: viewModel)
                            newInvoiceButton
                            taxAlertsSection
                            activeClientsSection(viewModel: viewModel)
                            pendingInvoicesSection(viewModel: viewModel)
                        }
                        .padding(16)
                    }
                    .background(Color.appBackground.ignoresSafeArea())
                    .navigationDestination(item: $selectedInvoice) { invoice in
                        iOSInvoiceDetailView(invoice: invoice, viewModel: invoiceViewModel)
                    }
                    .sheet(item: $composerSeed, onDismiss: refreshData) { seed in
                        AddInvoiceView(viewModel: invoiceViewModel, seed: seed) { created in
                            selectedInvoice = created
                            refreshData()
                        }
                    }
                } else {
                    ProgressView(String(localized: "Cargando inicio…"))
                }
            }
            .navigationTitle(String(localized: "Inicio"))
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            loadViewModelsIfNeeded()
            refreshData()
            openComposerForPendingSharedImportIfNeeded()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            openComposerForPendingSharedImportIfNeeded()
        }
    }

    // MARK: - YTD Billing Card

    private func ytdBillingCard(viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Facturacion YTD"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Text(viewModel.yearToDateBilling.formattedAsCurrency)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            if viewModel.yearOverYearGrowth != 0 {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.yearOverYearGrowth >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.bold))
                    Text(String(format: "%+.1f%% vs ano anterior", NSDecimalNumber(decimal: viewModel.yearOverYearGrowth).doubleValue))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(viewModel.yearOverYearGrowth >= 0 ? .green : .red)
            }

            SummaryCardRow(cards: [
                SummaryCardData(title: String(localized: "Emitido"), value: viewModel.thisMonthIssued.formattedAsCurrency, tint: .blue),
                SummaryCardData(title: String(localized: "Cobrado"), value: viewModel.thisMonthPaid.formattedAsCurrency, tint: .green),
                SummaryCardData(title: String(localized: "Pendiente"), value: viewModel.pendingAmount.formattedAsCurrency, tint: .orange),
            ])
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .prominentCardStyle(cornerRadius: 16)
    }

    // MARK: - New Invoice Button

    private var newInvoiceButton: some View {
        Button {
            composerSeed = .quick
        } label: {
            Label(String(localized: "Nueva Factura"), systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityIdentifier("ios-dashboard-quick-create")
    }

    // MARK: - Tax Alerts

    private var taxAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Alertas fiscales"))
                .font(.headline)

            ForEach(TaxAlertHelper.currentAlerts()) { alert in
                TaxAlertCard(alert: alert)
            }
        }
    }

    // MARK: - Active Clients

    private func activeClientsSection(viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "Clientes activos"))
                    .font(.headline)
                Spacer()
                Text(String(localized: "Ver todos"))
                    .font(.subheadline)
                    .foregroundStyle(.tint)
            }

            if viewModel.frequentClients.isEmpty {
                helperCard(text: String(localized: "Tus clientes con historial apareceran aqui."))
            } else {
                ForEach(viewModel.frequentClients.prefix(3)) { summary in
                    HStack(spacing: 14) {
                        ClientAvatarView(
                            name: summary.client.name,
                            accentColor: summary.client.accentColor,
                            size: 44
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.client.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            if let lastDate = summary.lastInvoiceDate {
                                Text(String(localized: "Ultima factura: \(lastDate.relativeFormat)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button {
                            composerSeed = .client(summary.client)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .cardStyle(cornerRadius: 12)
                }
            }
        }
    }

    // MARK: - Pending Invoices

    private func pendingInvoicesSection(viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Cobros pendientes"))
                .font(.headline)

            if viewModel.pendingInvoices.isEmpty {
                helperCard(text: String(localized: "No hay facturas pendientes de cobro."))
            } else {
                ForEach(viewModel.pendingInvoices.prefix(4)) { invoice in
                    Button {
                        selectedInvoice = invoice
                    } label: {
                        iOSCompactInvoiceCard(invoice: invoice)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helper Card

    private func helperCard(text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(cornerRadius: 12)
    }

    // MARK: - Private Methods

    private func openComposerForPendingSharedImportIfNeeded() {
        guard SharedImageImportStore.hasPendingImport, composerSeed == nil else { return }
        composerSeed = .quick
    }

    private func loadViewModelsIfNeeded() {
        if viewModel == nil {
            viewModel = HomeViewModel(modelContext: modelContext)
        }
        if invoiceViewModel == nil {
            invoiceViewModel = InvoiceViewModel(modelContext: modelContext)
        }
    }

    private func refreshData() {
        viewModel?.refresh()
        invoiceViewModel?.fetchInvoices()
    }
}

// MARK: - Compact Invoice Card (iOS-specific)

private struct iOSCompactInvoiceCard: View {
    let invoice: Invoice

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(invoice.invoiceNumber)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    StatusBadge(status: invoice.status)
                }

                Text(invoice.clientName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Label(
                    String(localized: "Vence \(invoice.dueDate.mediumFormat)"),
                    systemImage: "calendar"
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(invoice.totalAmount.formattedAsCurrency)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .cardStyle(cornerRadius: 12)
    }
}

// MARK: - Date Relative Format Extension

extension Date {
    var relativeFormat: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    iOSDashboardView()
        .modelContainer(PersistenceController.preview)
        .environmentObject(try! SubscriptionService(storeConfiguration: .testing, startTasks: false))
}
