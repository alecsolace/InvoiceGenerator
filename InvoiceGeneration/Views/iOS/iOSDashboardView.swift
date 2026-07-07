import SwiftData
import SwiftUI

/// iPhone-specific dashboard view — launch pad layout.
/// Scoped to the active issuer; shows quick-resume card, FAB, needs-attention, and recent clients.
struct iOSDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Issuer.name) private var issuers: [Issuer]

    @State private var viewModel: HomeViewModel?
    @State private var invoiceViewModel: InvoiceViewModel?
    @State private var composerSeed: InvoiceComposerSeed?
    @State private var selectedInvoice: Invoice?
    @State private var showingIssuerPicker = false

    private var activeIssuer: Issuer? { issuers.first }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel, let invoiceViewModel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            quickResumeCard(viewModel: viewModel)
                            newInvoiceButton
                            needsAttentionSection(viewModel: viewModel)
                            recentClientsSection(viewModel: viewModel)
                            taxAlertsSection
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
                ToolbarItem(placement: .primaryAction) {
                    issuerChip
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
        .sheet(isPresented: $showingIssuerPicker) {
            issuerPickerSheet
        }
    }

    // MARK: - Issuer Chip

    private var issuerChip: some View {
        Button {
            if issuers.count > 1 { showingIssuerPicker = true }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                Text(activeIssuer?.name ?? String(localized: "Sin emisor"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                if issuers.count > 1 {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.accentColor.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var issuerPickerSheet: some View {
        NavigationStack {
            List(issuers) { issuer in
                Button {
                    showingIssuerPicker = false
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 10, height: 10)
                        Text(issuer.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if issuer.id == activeIssuer?.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "Emisor activo"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cerrar")) { showingIssuerPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Quick Resume Card

    private func quickResumeCard(viewModel: HomeViewModel) -> some View {
        Group {
            if let topClient = viewModel.frequentClients.first {
                HStack(spacing: 14) {
                    ClientAvatarView(
                        name: topClient.client.name,
                        accentColor: topClient.client.accentColor,
                        size: 48
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "dashboard.last_client"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(topClient.client.name)
                            .font(.headline)
                            .fontWeight(.bold)
                        if let date = topClient.lastInvoiceDate {
                            Text(date.relativeFormat)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    Button {
                        composerSeed = .client(topClient.client)
                    } label: {
                        Text(String(localized: "dashboard.invoice_action"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .prominentCardStyle(cornerRadius: 16)
            }
        }
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

    // MARK: - Needs Attention

    private func needsAttentionSection(viewModel: HomeViewModel) -> some View {
        let attention = attentionItems(viewModel: viewModel)
        return Group {
            if !attention.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(localized: "dashboard.needs_attention"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        Text(String(localized: "Ver todas"))
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(attention.prefix(3).enumerated()), id: \.element.id) { index, invoice in
                            Button {
                                selectedInvoice = invoice
                            } label: {
                                attentionRow(invoice: invoice)
                            }
                            .buttonStyle(.plain)

                            if index < min(attention.prefix(3).count, 3) - 1 {
                                Divider().padding(.leading, 36)
                            }
                        }
                    }
                    .cardStyle(cornerRadius: 12)
                }
            }
        }
    }

    private func attentionItems(viewModel: HomeViewModel) -> [Invoice] {
        let overdue = viewModel.pendingInvoices.filter { $0.status == .overdue }
        let pending = viewModel.pendingInvoices.filter { $0.status == .sent }
        return (overdue + pending)
    }

    private func attentionRow(invoice: Invoice) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(invoice.status == .overdue ? Color.red : Color.orange)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(invoice.clientName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(invoice.invoiceNumber)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospaced()
                if invoice.status == .overdue {
                    Text(String(localized: "invoice.status.overdue_since \(invoice.dueDate.relativeFormat)"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            Text(invoice.totalAmount.formattedAsCurrency)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Recent Clients

    private func recentClientsSection(viewModel: HomeViewModel) -> some View {
        Group {
            if !viewModel.frequentClients.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "Clientes activos"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(viewModel.frequentClients) { summary in
                                Button {
                                    composerSeed = .client(summary.client)
                                } label: {
                                    VStack(spacing: 6) {
                                        ClientAvatarView(
                                            name: summary.client.name,
                                            accentColor: summary.client.accentColor,
                                            size: 52
                                        )
                                        Text(summary.client.name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .frame(maxWidth: 60)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Tax Alerts

    private var taxAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !TaxAlertHelper.currentAlerts().isEmpty {
                Text(String(localized: "Alertas fiscales"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)

                ForEach(TaxAlertHelper.currentAlerts()) { alert in
                    TaxAlertCard(alert: alert)
                }
            }
        }
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
