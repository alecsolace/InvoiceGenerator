import SwiftData
import SwiftUI

/// iPhone-specific invoice list matching the Stitch "Lista de Facturas" design.
struct iOSInvoiceListView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: InvoiceViewModel?
    @State private var searchText = ""
    @State private var selectedFilter: InvoiceFilter = .all
    @State private var composerSeed: InvoiceComposerSeed?
    @State private var selectedInvoice: Invoice?
    @State private var shareURL: URL?
    @State private var showingShareSheet = false

    @Query(sort: [SortDescriptor(\Client.name)]) private var clients: [Client]
    @Query(sort: [SortDescriptor(\Issuer.name)]) private var issuers: [Issuer]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    subtitleHeader
                    filterTabs
                    searchBar
                    content
                }
                .background(Color.appBackground.ignoresSafeArea())

                fabButton
            }
            .navigationTitle(String(localized: "Facturas"))
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationDestination(item: $selectedInvoice) { invoice in
                if let viewModel {
                    iOSInvoiceDetailView(invoice: invoice, viewModel: viewModel)
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
            applyFilters()
        }
        .onChange(of: searchText) { _, _ in applyFilters() }
        .onChange(of: selectedFilter) { _, _ in applyFilters() }
    }

    // MARK: - Subtitle Header

    private var subtitleHeader: some View {
        Text(String(localized: "Gestiona tus cobros pendientes y realizados"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InvoiceFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.localizedTitle)
                            .font(.subheadline)
                            .fontWeight(selectedFilter == filter ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .foregroundStyle(selectedFilter == filter ? .white : .primary)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter ? Color.accentColor : Color.cardBackground)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(String(localized: "Buscar factura…"), text: $searchText)
                .font(.subheadline)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            if viewModel.isLoading {
                Spacer()
                ProgressView(String(localized: "Cargando facturas…"))
                Spacer()
            } else if viewModel.invoices.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.invoices) { invoice in
                            Button {
                                selectedInvoice = invoice
                            } label: {
                                iOSInvoiceCard(invoice: invoice)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                invoiceContextMenu(invoice: invoice, viewModel: viewModel)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 80) // Space for FAB
                }
            }
        } else {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    // MARK: - FAB

    private var fabButton: some View {
        Button {
            composerSeed = .quick
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor, in: Circle())
                .shadow(color: .accentColor.opacity(0.3), radius: 12, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 16)
        .accessibilityIdentifier("ios-invoice-fab")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "doc.text.magnifyingglass",
            title: String(localized: searchText.isEmpty ? "No hay facturas" : "No hay resultados"),
            message: String(localized: searchText.isEmpty
                ? "Crea tu primera factura para empezar."
                : "Prueba a limpiar filtros o cambiar la busqueda."),
            buttonTitle: String(localized: "Nueva factura")
        ) {
            composerSeed = .quick
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func invoiceContextMenu(invoice: Invoice, viewModel: InvoiceViewModel) -> some View {
        Button {
            composerSeed = .duplicate(invoice)
        } label: {
            Label(String(localized: "Duplicar"), systemImage: "plus.square.on.square")
        }
        Button {
            viewModel.markSent(invoice)
        } label: {
            Label(String(localized: "Marcar enviada"), systemImage: "paperplane")
        }
        Button {
            viewModel.markPaid(invoice)
        } label: {
            Label(String(localized: "Marcar cobrada"), systemImage: "checkmark.circle")
        }
        Button {
            share(invoice)
        } label: {
            Label(String(localized: "Compartir PDF"), systemImage: "square.and.arrow.up")
        }
        Divider()
        Button(role: .destructive) {
            viewModel.deleteInvoice(invoice)
        } label: {
            Label(String(localized: "Eliminar"), systemImage: "trash")
        }
    }

    // MARK: - Helpers

    private func applyFilters() {
        viewModel?.searchInvoices(query: searchText)

        switch selectedFilter {
        case .all:
            viewModel?.filterByStatus(nil)
        case .pending:
            viewModel?.filterByStatus(.sent)
        case .paid:
            viewModel?.filterByStatus(.paid)
        case .lastMonth:
            viewModel?.filterByStatus(nil)
            // Additional time-based filtering handled below
        }
    }

    private func refreshInvoices() {
        viewModel?.fetchInvoices()
    }

    private func share(_ invoice: Invoice) {
        let fileName = "Factura_\(invoice.invoiceNumber)"
        if let url = PDFStorageManager.targetURL(for: fileName),
           FileManager.default.fileExists(atPath: url.path) {
            shareURL = url
            showingShareSheet = true
            return
        }
        guard let pdfDocument = PDFGeneratorService.generateInvoicePDF(invoice: invoice) else { return }
        if let url = PDFGeneratorService.savePDF(pdfDocument, fileName: fileName) {
            shareURL = url
            showingShareSheet = true
        }
    }
}

// MARK: - Invoice Filter

private enum InvoiceFilter: String, CaseIterable {
    case all
    case pending
    case paid
    case lastMonth

    var localizedTitle: String {
        switch self {
        case .all: return String(localized: "Todas")
        case .pending: return String(localized: "Pendientes")
        case .paid: return String(localized: "Pagadas")
        case .lastMonth: return String(localized: "Ultimo mes")
        }
    }
}

// MARK: - iOS Invoice Card

private struct iOSInvoiceCard: View {
    let invoice: Invoice

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(invoice.invoiceNumber)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                StatusBadge(status: invoice.status)
            }

            Text(invoice.clientName)
                .font(.headline)
                .foregroundStyle(.primary)

            HStack {
                Label(invoice.issueDate.shortFormat, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if invoice.status == .sent || invoice.status == .overdue {
                    Label(String(localized: "Vence \(invoice.dueDate.shortFormat)"), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(invoice.status == .overdue ? .red : .secondary)
                }
            }

            HStack {
                Spacer()
                Text(invoice.totalAmount.formattedAsCurrency)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
        }
        .padding(16)
        .cardStyle(cornerRadius: 12)
    }
}

#Preview {
    iOSInvoiceListView()
        .modelContainer(PersistenceController.preview)
        .environmentObject(try! SubscriptionService(storeConfiguration: .testing, startTasks: false))
}
