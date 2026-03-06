import SwiftUI
import SwiftData

/// View displaying list of invoices
struct InvoiceListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: InvoiceViewModel?

    @AppStorage(IssuerSelectionStore.appStorageKey) private var selectedIssuerStorage = IssuerSelectionStore.allIssuersToken

    @State private var searchText = ""
    @State private var selectedStatus: InvoiceStatus?
    @State private var selectedClientID: UUID?
    @State private var selectedIssuerID: UUID?
    @State private var showingAddInvoice = false

    @Query(sort: [SortDescriptor(\Client.name)]) private var clients: [Client]
    @Query(sort: [SortDescriptor(\Issuer.name)]) private var issuers: [Issuer]

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    if viewModel.isLoading {
                        ProgressView("Loading invoices...")
                    } else if viewModel.invoices.isEmpty {
                        emptyStateView
                    } else {
                        invoiceList(viewModel: viewModel)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Invoices")
            .searchable(text: $searchText, prompt: "Search invoices")
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingAddInvoice) {
                if let viewModel = viewModel {
                    AddInvoiceView(viewModel: viewModel)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = InvoiceViewModel(modelContext: modelContext)
            }

            selectedIssuerID = IssuerSelectionStore.issuerID(from: selectedIssuerStorage)
            applyIssuerFilter()
        }
        .onChange(of: searchText) { _, newValue in
            viewModel?.searchInvoices(query: newValue)
        }
        .onChange(of: selectedClientID) { _, newValue in
            if let id = newValue, let client = clients.first(where: { $0.id == id }) {
                viewModel?.filterByClient(client)
            } else {
                viewModel?.filterByClient(nil)
            }
        }
        .onChange(of: selectedIssuerID) { _, _ in
            selectedIssuerStorage = IssuerSelectionStore.storageValue(from: selectedIssuerID)
            applyIssuerFilter()
        }
        .onChange(of: selectedIssuerStorage) { _, _ in
            let storageID = IssuerSelectionStore.issuerID(from: selectedIssuerStorage)
            if selectedIssuerID != storageID {
                selectedIssuerID = storageID
            }
            applyIssuerFilter()
        }
        .onChange(of: issuers.count) { _, _ in
            applyIssuerFilter()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Invoices")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create your first invoice to get started")
                .foregroundStyle(.secondary)

            Button(action: { showingAddInvoice = true }) {
                Label("Create Invoice", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func invoiceList(viewModel: InvoiceViewModel) -> some View {
        List {
            ForEach(viewModel.invoices) { invoice in
                NavigationLink {
                    InvoiceDetailView(invoice: invoice, viewModel: viewModel)
                } label: {
                    InvoiceRowView(invoice: invoice)
                }
                .platformContextActions {
                    viewModel.deleteInvoice(invoice)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
            addInvoiceButton
        }
        ToolbarItem(placement: .navigationBarLeading) {
            filterMenu
        }
        ToolbarItem(placement: .navigationBarLeading) {
            clientFilterMenu
        }
        ToolbarItem(placement: .navigationBarLeading) {
            issuerFilterMenu
        }
        #else
        ToolbarItem(placement: .automatic) {
            addInvoiceButton
        }
        ToolbarItem(placement: .automatic) {
            filterMenu
        }
        ToolbarItem(placement: .automatic) {
            clientFilterMenu
        }
        ToolbarItem(placement: .automatic) {
            issuerFilterMenu
        }
        #endif
    }

    private var addInvoiceButton: some View {
        Button(action: { showingAddInvoice = true }) {
            Label("Add Invoice", systemImage: "plus")
        }
    }

    private var filterMenu: some View {
        Menu {
            Button("All Invoices") {
                selectedStatus = nil
                viewModel?.filterByStatus(nil)
            }

            ForEach(InvoiceStatus.allCases, id: \.self) { status in
                Button(status.localizedTitle) {
                    selectedStatus = status
                    viewModel?.filterByStatus(status)
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    private var clientFilterMenu: some View {
        Menu {
            Button("All Clients") {
                selectedClientID = nil
            }

            ForEach(clients) { client in
                Button(client.name) {
                    selectedClientID = client.id
                }
            }
        } label: {
            Label(clientFilterLabel, systemImage: "person.2.crop.square.stack")
        }
    }

    private var issuerFilterMenu: some View {
        Menu {
            Button("All Emitters") {
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

    private var clientFilterLabel: String {
        if let id = selectedClientID, let client = clients.first(where: { $0.id == id }) {
            return client.name
        }

        return "Client"
    }

    private var issuerFilterLabel: String {
        if let id = selectedIssuerID, let issuer = issuers.first(where: { $0.id == id }) {
            return issuer.name
        }

        return "All Emitters"
    }

    private func applyIssuerFilter() {
        guard let viewModel else { return }

        if let issuerID = selectedIssuerID, let issuer = issuers.first(where: { $0.id == issuerID }) {
            viewModel.filterByIssuer(issuer)
        } else {
            viewModel.filterByIssuer(nil)
        }
    }
}

/// Row view for invoice in list
struct InvoiceRowView: View {
    let invoice: Invoice

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(invoice.invoiceNumber)
                    .font(.headline)

                Spacer()

                Text(invoice.totalAmount.formattedAsCurrency)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Text(invoice.clientName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !invoice.issuerName.isEmpty {
                Text(invoice.issuerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label(invoice.issueDate.shortFormat, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 8) {
                    statusBadge
                    pdfBadge
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        Text(invoice.status.localizedTitle)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .cornerRadius(8)
    }

    private var pdfBadge: some View {
        Label(
            invoice.hasGeneratedPDF ? "PDF Ready" : "PDF Pending",
            systemImage: invoice.hasGeneratedPDF ? "doc.richtext.fill" : "doc.badge.gearshape"
        )
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial)
        .clipShape(Capsule())
        .foregroundStyle(invoice.hasGeneratedPDF ? .teal : .secondary)
        .animation(.easeInOut(duration: 0.2), value: invoice.hasGeneratedPDF)
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

#Preview {
    InvoiceListView()
        .modelContainer(for: [Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self, Issuer.self])
}

// MARK: - Platform helpers

private extension View {
    @ViewBuilder
    func platformContextActions(onDelete: @escaping () -> Void) -> some View {
        #if os(iOS)
        self.swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        #else
        self.contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete Invoice", systemImage: "trash")
            }
        }
        #endif
    }
}
