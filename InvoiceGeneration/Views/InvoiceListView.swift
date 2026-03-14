import SwiftData
import SwiftUI

struct InvoiceListView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(IssuerSelectionStore.appStorageKey) private var selectedIssuerStorage = IssuerSelectionStore.allIssuersToken

    @State private var viewModel: InvoiceViewModel?
    @State private var searchText = ""
    @State private var selectedStatus: InvoiceStatus?
    @State private var selectedClientID: UUID?
    @State private var selectedIssuerID: UUID?
    @State private var showingFilters = false
    @State private var composerSeed: InvoiceComposerSeed?
    @State private var selectedInvoice: Invoice?
    @State private var shareURL: URL?
    @State private var showingShareSheet = false

    @Query(sort: [SortDescriptor(\Client.name)]) private var clients: [Client]
    @Query(sort: [SortDescriptor(\Issuer.name)]) private var issuers: [Issuer]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                content
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Facturas")
            .searchable(text: $searchText, prompt: "Buscar por cliente, numero o emisor")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        composerSeed = .quick
                    } label: {
                        Label("Nueva factura", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(item: $selectedInvoice) { invoice in
                if let viewModel {
                    InvoiceDetailView(invoice: invoice, viewModel: viewModel)
                }
            }
            .sheet(item: $composerSeed, onDismiss: refreshInvoices) { seed in
                if let viewModel {
                    AddInvoiceView(viewModel: viewModel, seed: seed) { created in
                        selectedInvoice = created
                        refreshInvoices()
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                InvoiceFiltersSheet(
                    selectedStatus: $selectedStatus,
                    selectedClientID: $selectedClientID,
                    selectedIssuerID: $selectedIssuerID,
                    clients: clients,
                    issuers: issuers
                )
            }
            .sheet(isPresented: $showingShareSheet) {
                if let shareURL {
                    ShareSheet(items: [shareURL])
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = InvoiceViewModel(modelContext: modelContext)
            }

            selectedIssuerID = IssuerSelectionStore.issuerID(from: selectedIssuerStorage)
            applyFilters()
        }
        .onChange(of: searchText) { _, _ in applyFilters() }
        .onChange(of: selectedStatus) { _, _ in applyFilters() }
        .onChange(of: selectedClientID) { _, _ in applyFilters() }
        .onChange(of: selectedIssuerID) { _, _ in
            selectedIssuerStorage = IssuerSelectionStore.storageValue(from: selectedIssuerID)
            applyFilters()
        }
        .onChange(of: selectedIssuerStorage) { _, _ in
            let storageID = IssuerSelectionStore.issuerID(from: selectedIssuerStorage)
            if selectedIssuerID != storageID {
                selectedIssuerID = storageID
            }
            applyFilters()
        }
        .onChange(of: issuers.count) { _, _ in applyFilters() }
        .onChange(of: clients.count) { _, _ in applyFilters() }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            if viewModel.isLoading {
                Spacer()
                ProgressView("Cargando facturas…")
                Spacer()
            } else if viewModel.invoices.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(groupedInvoices(from: viewModel.invoices), id: \.key) { group in
                            Section {
                                VStack(spacing: 12) {
                                    ForEach(group.invoices) { invoice in
                                        Button {
                                            selectedInvoice = invoice
                                        } label: {
                                            InvoiceCard(invoice: invoice)
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            invoiceContextMenu(invoice: invoice, viewModel: viewModel)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            } header: {
                                MonthSectionHeader(
                                    title: group.key,
                                    total: group.total,
                                    count: group.invoices.count
                                )
                            }
                        }
                    }
                }
            }
        } else {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    // MARK: - Grouping

    private struct InvoiceGroup {
        let key: String
        let date: Date
        let invoices: [Invoice]
        var total: Decimal { invoices.reduce(0) { $0 + $1.totalAmount } }
    }

    private func groupedInvoices(from invoices: [Invoice]) -> [InvoiceGroup] {
        let dict = Dictionary(grouping: invoices) { $0.issueDate.startOfMonth }
        return dict
            .map { (date, invoices) in
                InvoiceGroup(
                    key: date.monthYearFormat,
                    date: date,
                    invoices: invoices.sorted { $0.issueDate > $1.issueDate }
                )
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func invoiceContextMenu(invoice: Invoice, viewModel: InvoiceViewModel) -> some View {
        Button {
            composerSeed = .duplicate(invoice)
        } label: {
            Label("Duplicar", systemImage: "plus.square.on.square")
        }
        Button {
            viewModel.markSent(invoice)
        } label: {
            Label("Marcar enviada", systemImage: "paperplane")
        }
        Button {
            viewModel.markPaid(invoice)
        } label: {
            Label("Marcar cobrada", systemImage: "checkmark.circle")
        }
        Button {
            share(invoice)
        } label: {
            Label("Compartir PDF", systemImage: "square.and.arrow.up")
        }
        Divider()
        Button(role: .destructive) {
            viewModel.deleteInvoice(invoice)
        } label: {
            Label("Eliminar", systemImage: "trash")
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(title: "Filtros", systemImage: "line.3.horizontal.decrease.circle") {
                    showingFilters = true
                }

                if let selectedStatus {
                    FilterChip(title: selectedStatus.localizedTitle) {
                        self.selectedStatus = nil
                    }
                }

                if let selectedClientID,
                   let client = clients.first(where: { $0.id == selectedClientID }) {
                    FilterChip(title: client.name) {
                        self.selectedClientID = nil
                    }
                }

                if let selectedIssuerID,
                   let issuer = issuers.first(where: { $0.id == selectedIssuerID }) {
                    FilterChip(title: issuer.name) {
                        self.selectedIssuerID = nil
                    }
                }

                if hasActiveFilters {
                    FilterChip(title: "Limpiar") {
                        clearFilters()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color.primaryBackground)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text(hasActiveFilters || !searchText.isEmpty ? "No hay resultados" : "No hay facturas")
                .font(.title2)
                .fontWeight(.semibold)

            Text(
                hasActiveFilters || !searchText.isEmpty
                ? "Prueba a limpiar filtros o cambiar la busqueda."
                : "Crea tu primera factura rapida para empezar."
            )
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button {
                composerSeed = .quick
            } label: {
                Label("Nueva factura", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    private var hasActiveFilters: Bool {
        selectedStatus != nil || selectedClientID != nil || selectedIssuerID != nil
    }

    private func applyFilters() {
        viewModel?.searchInvoices(query: searchText)
        viewModel?.filterByStatus(selectedStatus)
        viewModel?.filterByClient(clients.first(where: { $0.id == selectedClientID }))
        viewModel?.filterByIssuer(issuers.first(where: { $0.id == selectedIssuerID }))
    }

    private func clearFilters() {
        selectedStatus = nil
        selectedClientID = nil
        selectedIssuerID = nil
        applyFilters()
    }

    private func refreshInvoices() {
        viewModel?.fetchInvoices()
    }

    private func share(_ invoice: Invoice) {
        guard let url = ensurePDFURL(for: invoice) else { return }
        shareURL = url
        showingShareSheet = true
    }

    private func ensurePDFURL(for invoice: Invoice) -> URL? {
        let fileName = "Factura_\(invoice.invoiceNumber)"

        if let url = PDFStorageManager.targetURL(for: fileName),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        guard let pdfDocument = PDFGeneratorService.generateInvoicePDF(invoice: invoice) else { return nil }
        return PDFGeneratorService.savePDF(pdfDocument, fileName: fileName)
    }
}

// MARK: - Month Section Header

private struct MonthSectionHeader: View {
    let title: String
    let total: Decimal
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(count) facturas · \(total.formattedAsCurrency)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.appBackground)
    }
}

// MARK: - Invoice Card

private struct InvoiceCard: View {
    let invoice: Invoice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top: client + status badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(invoice.clientName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(invoice.invoiceNumber)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
            }

            // Amount
            Text(invoice.totalAmount.formattedAsCurrency)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            // Dates + PDF badge
            HStack(alignment: .center) {
                Label(
                    "\(invoice.issueDate.shortFormat)  →  \(invoice.dueDate.shortFormat)",
                    systemImage: "calendar"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                pdfBadge
            }
        }
        .padding(16)
        .cardStyle(cornerRadius: 16)
    }

    private var statusBadge: some View {
        Text(invoice.status.localizedTitle)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.12), in: Capsule())
            .foregroundStyle(statusColor)
    }

    private var pdfBadge: some View {
        Label(
            invoice.hasGeneratedPDF ? "PDF" : "Sin PDF",
            systemImage: invoice.hasGeneratedPDF ? "doc.richtext.fill" : "doc.badge.gearshape"
        )
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.cardBackground, in: Capsule())
        .foregroundStyle(invoice.hasGeneratedPDF ? .teal : .secondary)
    }

    private var statusColor: Color {
        switch invoice.status {
        case .draft: return .gray
        case .sent: return .blue
        case .paid: return .green
        case .overdue: return .red
        case .cancelled: return .orange
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    init(title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cardBackground, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filters Sheet

private struct InvoiceFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedStatus: InvoiceStatus?
    @Binding var selectedClientID: UUID?
    @Binding var selectedIssuerID: UUID?

    let clients: [Client]
    let issuers: [Issuer]

    var body: some View {
        NavigationStack {
            Form {
                Section("Estado") {
                    Picker("Estado", selection: $selectedStatus) {
                        Text("Todos").tag(InvoiceStatus?.none)
                        ForEach(InvoiceStatus.allCases, id: \.self) { status in
                            Text(status.localizedTitle).tag(Optional(status))
                        }
                    }
                }

                Section("Cliente") {
                    Picker("Cliente", selection: $selectedClientID) {
                        Text("Todos").tag(UUID?.none)
                        ForEach(clients) { client in
                            Text(client.name).tag(Optional(client.id))
                        }
                    }
                }

                Section("Emisor") {
                    Picker("Emisor", selection: $selectedIssuerID) {
                        Text("Todos").tag(UUID?.none)
                        ForEach(issuers) { issuer in
                            Text(issuer.name).tag(Optional(issuer.id))
                        }
                    }
                }
            }
            .navigationTitle("Filtros")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    InvoiceListView()
        .modelContainer(for: [Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self, Issuer.self, InvoiceTemplate.self, InvoiceTemplateItem.self])
}
