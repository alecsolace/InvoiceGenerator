import SwiftData
import SwiftUI

struct ClientListView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: ClientViewModel?
    @State private var invoiceViewModel: InvoiceViewModel?
    @State private var editorState: ClientEditorState?
    @State private var composerSeed: InvoiceComposerSeed?
    @State private var selectedInvoice: Invoice?
    @State private var showingPaywall = false
    @State private var paywallReason: PaywallReason = .clientLimit
    @State private var searchText = ""

    @Query(sort: [SortDescriptor(\InvoiceTemplate.updatedAt, order: .reverse)]) private var templates: [InvoiceTemplate]

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel, let invoiceViewModel {
                    if viewModel.isLoading {
                        ProgressView("Cargando clientes…")
                    } else if viewModel.clients.isEmpty {
                        emptyState
                    } else {
                        clientList(viewModel: viewModel, invoiceViewModel: invoiceViewModel)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Clientes")
            .searchable(text: $searchText, prompt: "Buscar cliente")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        handleAddClientTap()
                    } label: {
                        Label("Nuevo cliente", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(item: $selectedInvoice) { invoice in
                if let invoiceViewModel {
                    InvoiceDetailView(invoice: invoice, viewModel: invoiceViewModel)
                }
            }
            .sheet(item: $editorState) { state in
                if let viewModel {
                    AddClientView(viewModel: viewModel, mode: state.mode) { _ in
                        refreshAll()
                    }
                }
            }
            .sheet(item: $composerSeed, onDismiss: refreshAll) { seed in
                if let invoiceViewModel {
                    AddInvoiceView(viewModel: invoiceViewModel, seed: seed) { created in
                        selectedInvoice = created
                        refreshAll()
                    }
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ClientViewModel(modelContext: modelContext)
            }

            if invoiceViewModel == nil {
                invoiceViewModel = InvoiceViewModel(modelContext: modelContext)
            }
        }
        .onChange(of: searchText) { _, newValue in
            viewModel?.searchClients(query: newValue)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(reason: paywallReason)
                .environmentObject(subscriptionService)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No hay clientes")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Guarda clientes para reutilizar datos, defaults y plantillas en cada mes.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { handleAddClientTap() }) {
                Label("Nuevo cliente", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func clientList(viewModel: ClientViewModel, invoiceViewModel: InvoiceViewModel) -> some View {
        List {
            let currentCount = viewModel.clients.count
            if !subscriptionService.isPro && currentCount >= subscriptionService.freeClientLimit {
                paywallBanner(currentCount: currentCount)
            }

            ForEach(viewModel.clients) { client in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(client.name)
                                .font(.headline)

                            if !client.email.isEmpty {
                                Label(client.email, systemImage: "envelope")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if !client.identificationNumber.isEmpty {
                                Label(client.identificationNumber, systemImage: "number")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button("Facturar") {
                            startInvoice(for: client)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if let templateName = preferredTemplateName(for: client) {
                        Label("Plantilla: \(templateName)", systemImage: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Label("Vence en \(effectiveDueDays(for: client)) dias", systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let iva = client.defaultIVAPercentage {
                            Label("IVA \(iva.formattedAsPercent)", systemImage: "percent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
                .clientRowActions(
                    onInvoice: { startInvoice(for: client) },
                    onEdit: { editorState = .edit(client) },
                    onDelete: { viewModel.deleteClient(client) }
                )
            }
        }
        .listStyle(.plain)
    }

    private func handleAddClientTap() {
        guard let viewModel else { return }

        if subscriptionService.canAddClient(currentCount: viewModel.clients.count) {
            editorState = .create
        } else {
            paywallReason = .clientLimit
            showingPaywall = true
        }
    }

    private func startInvoice(for client: Client) {
        if let preferredTemplateID = client.preferredTemplateID,
           let template = templates.first(where: { $0.id == preferredTemplateID }) {
            composerSeed = .template(template)
        } else {
            composerSeed = .client(client)
        }
    }

    private func refreshAll() {
        viewModel?.fetchClients()
        invoiceViewModel?.fetchInvoices()
    }

    private func effectiveDueDays(for client: Client) -> Int {
        client.defaultDueDays > 0 ? client.defaultDueDays : InvoiceFlowPreferences.defaultDueDays
    }

    private func preferredTemplateName(for client: Client) -> String? {
        guard let preferredTemplateID = client.preferredTemplateID else { return nil }
        return templates.first(where: { $0.id == preferredTemplateID })?.name
    }

    private func paywallBanner(currentCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Plan gratis: 2 clientes incluidos", systemImage: "star")
                    .font(.headline)
                Spacer()
                Text("\(currentCount)/\(subscriptionService.freeClientLimit)")
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text("Activa Pro para clientes ilimitados y sincronizacion iCloud.")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            Button {
                paywallReason = .clientLimit
                showingPaywall = true
            } label: {
                Text("Ver Pro")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

private enum ClientEditorState: Identifiable {
    case create
    case edit(Client)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let client):
            return client.id.uuidString
        }
    }

    var mode: AddClientView.Mode {
        switch self {
        case .create:
            return .create
        case .edit(let client):
            return .edit(client)
        }
    }
}

private extension View {
    @ViewBuilder
    func clientRowActions(
        onInvoice: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        #if os(iOS)
        self
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button(action: onInvoice) {
                    Label("Facturar", systemImage: "bolt.fill")
                }
                .tint(.blue)

                Button(action: onEdit) {
                    Label("Editar", systemImage: "pencil")
                }
                .tint(.orange)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive, action: onDelete) {
                    Label("Eliminar", systemImage: "trash")
                }
            }
        #else
        self.contextMenu {
            Button(action: onInvoice) {
                Label("Facturar", systemImage: "bolt.fill")
            }
            Button(action: onEdit) {
                Label("Editar", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Eliminar", systemImage: "trash")
            }
        }
        #endif
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Invoice.self,
        InvoiceItem.self,
        CompanyProfile.self,
        Client.self,
        Issuer.self,
        InvoiceTemplate.self,
        InvoiceTemplateItem.self,
        configurations: config
    )

    return ClientListView()
        .modelContainer(container)
        .environmentObject(SubscriptionService())
}
