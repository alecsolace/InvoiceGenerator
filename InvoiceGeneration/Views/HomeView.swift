import SwiftData
import SwiftUI

struct HomeView: View {
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
                            heroCard
                            statsSection(viewModel: viewModel)
                            templatesSection(viewModel: viewModel)
                            frequentClientsSection(viewModel: viewModel)
                            pendingSection(viewModel: viewModel)
                            draftsSection(viewModel: viewModel)
                            analyticsLink
                        }
                        .padding()
                    }
                    .background(Color.appBackground.ignoresSafeArea())
                    .navigationDestination(item: $selectedInvoice) { invoice in
                        InvoiceDetailView(invoice: invoice, viewModel: invoiceViewModel)
                    }
                    .sheet(item: $composerSeed, onDismiss: refreshData) { seed in
                        AddInvoiceView(viewModel: invoiceViewModel, seed: seed) { created in
                            selectedInvoice = created
                            refreshData()
                        }
                    }
                } else {
                    ProgressView("Cargando inicio…")
                }
            }
            .navigationTitle("Inicio")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        composerSeed = .quick
                    } label: {
                        Label("Nueva factura", systemImage: "plus")
                    }
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

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tint)

            VStack(spacing: 6) {
                Text("Tu facturación del mes")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Crea facturas, reutiliza plantillas y sigue los cobros pendientes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                composerSeed = .quick
            } label: {
                Label("Crear factura", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("home-quick-create")
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .prominentCardStyle(cornerRadius: 16)
    }

    // MARK: - Stats

    private func statsSection(viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resumen")
                .font(.headline)

            SummaryCardRow(cards: [
                SummaryCardData(title: "Emitido", value: viewModel.thisMonthIssued.formattedAsCurrency, tint: .blue),
                SummaryCardData(title: "Cobrado", value: viewModel.thisMonthPaid.formattedAsCurrency, tint: .green),
                SummaryCardData(title: "Pendiente", value: viewModel.pendingAmount.formattedAsCurrency, tint: .orange),
            ])
        }
    }

    // MARK: - Templates

    private func templatesSection(viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Plantillas")
                    .font(.headline)
                Spacer()
                Text(viewModel.templates.isEmpty ? "0" : "\(viewModel.templates.count)")
                    .foregroundStyle(.secondary)
            }

            if viewModel.templates.isEmpty {
                helperCard(text: "Guarda una factura como plantilla para emitir el siguiente mes en segundos.")
            } else {
                ForEach(viewModel.templates.prefix(4)) { template in
                    Button {
                        composerSeed = .template(template)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(template.client?.name ?? template.clientName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.tint)
                        }
                        .padding(16)
                        .cardStyle(cornerRadius: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Frequent Clients

    private func frequentClientsSection(viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clientes frecuentes")
                .font(.headline)

            if viewModel.frequentClients.isEmpty {
                helperCard(text: "Tus clientes con historial apareceran aqui para facturarlos sin buscar entre pantallas.")
            } else {
                ForEach(viewModel.frequentClients) { summary in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.client.name)
                                .font(.headline)
                            Text("\(summary.invoiceCount) facturas")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Facturar") {
                            composerSeed = .client(summary.client)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("home-client-\(summary.client.id.uuidString)")
                    }
                    .padding(16)
                    .cardStyle(cornerRadius: 16)
                }
            }
        }
    }

    // MARK: - Pending

    private func pendingSection(viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cobros pendientes")
                .font(.headline)

            if viewModel.pendingInvoices.isEmpty {
                helperCard(text: "No hay facturas enviadas o vencidas pendientes de cobro.")
            } else {
                ForEach(viewModel.pendingInvoices) { invoice in
                    Button {
                        selectedInvoice = invoice
                    } label: {
                        CompactInvoiceCard(invoice: invoice)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Drafts

    private func draftsSection(viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Borradores recientes")
                .font(.headline)

            if viewModel.recentDrafts.isEmpty {
                helperCard(text: "Los borradores recientes apareceran aqui para retomarlos sin navegar por toda la app.")
            } else {
                ForEach(viewModel.recentDrafts) { invoice in
                    Button {
                        selectedInvoice = invoice
                    } label: {
                        CompactInvoiceCard(invoice: invoice)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Analytics Link

    private var analyticsLink: some View {
        NavigationLink {
            DashboardView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Analitica")
                        .font(.headline)
                    Text("Revisa estados e ingresos cuando necesites contexto, no para cada factura.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chart.pie")
                    .font(.title3)
                    .foregroundStyle(.tint)
            }
            .padding(16)
            .cardStyle(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Card

    private func helperCard(text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(cornerRadius: 16)
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

// MARK: - CompactInvoiceCard

private struct CompactInvoiceCard: View {
    let invoice: Invoice

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.invoiceNumber)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(invoice.clientName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Vence \(invoice.dueDate.mediumFormat)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(invoice.totalAmount.formattedAsCurrency)
                    .font(.headline)
                    .foregroundStyle(.primary)
                StatusBadge(status: invoice.status)
            }
        }
        .padding(16)
        .cardStyle(cornerRadius: 14)
    }
}

#Preview {
    HomeView()
        .modelContainer(PersistenceController.preview)
        .environmentObject(try! SubscriptionService(storeConfiguration: .testing, startTasks: false))
}
