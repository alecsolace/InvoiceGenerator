import SwiftData
import SwiftUI

/// iPhone-specific client list matching the Stitch "Gestion de Clientes" design.
struct iOSClientListView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: ClientViewModel?
    @State private var invoiceViewModel: InvoiceViewModel?
    @State private var editorState: iOSClientEditorState?
    @State private var composerSeed: InvoiceComposerSeed?
    @State private var selectedInvoice: Invoice?
    @State private var showingPaywall = false
    @State private var paywallReason: PaywallReason = .clientLimit
    @State private var searchText = ""

    @Query(sort: [SortDescriptor(\InvoiceTemplate.updatedAt, order: .reverse)]) private var templates: [InvoiceTemplate]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                subtitleHeader
                searchBar
                content
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(String(localized: "Mis Clientes"))
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        handleAddClientTap()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(item: $selectedInvoice) { invoice in
                if let invoiceViewModel {
                    iOSInvoiceDetailView(invoice: invoice, viewModel: invoiceViewModel)
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
            .sheet(isPresented: $showingPaywall) {
                PaywallView(reason: paywallReason)
                    .environmentObject(subscriptionService)
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
    }

    // MARK: - Subtitle

    private var subtitleHeader: some View {
        Text(String(localized: "Gestiona tu cartera y emite facturas rapidamente"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(String(localized: "Buscar cliente…"), text: $searchText)
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
                ProgressView(String(localized: "Cargando clientes…"))
                Spacer()
            } else if viewModel.clients.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if !subscriptionService.isPro && viewModel.clients.count >= subscriptionService.freeClientLimit {
                            paywallBanner(currentCount: viewModel.clients.count)
                        }

                        ForEach(viewModel.clients) { client in
                            iOSClientCard(
                                client: client,
                                revenue: viewModel.totalRevenue(for: client),
                                onView: { editorState = .edit(client) },
                                onInvoice: { startInvoice(for: client) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        } else {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "person.crop.circle.badge.plus",
            title: String(localized: "No hay clientes"),
            message: String(localized: "Guarda clientes para reutilizar datos y plantillas."),
            buttonTitle: String(localized: "Nuevo cliente")
        ) {
            handleAddClientTap()
        }
    }

    // MARK: - Paywall Banner

    private func paywallBanner(currentCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(String(localized: "Plan gratis: 2 clientes"), systemImage: "star.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(currentCount)/\(subscriptionService.freeClientLimit)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }

            Button {
                paywallReason = .clientLimit
                showingPaywall = true
            } label: {
                Text(String(localized: "Desbloquear Pro"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .cardStyle(cornerRadius: 12)
    }

    // MARK: - Helpers

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
}

// MARK: - iOS Client Card

private struct iOSClientCard: View {
    let client: Client
    let revenue: Decimal
    let onView: () -> Void
    let onInvoice: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ClientAvatarView(
                    name: client.name,
                    accentColor: client.accentColor,
                    size: 48
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(client.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if !client.identificationNumber.isEmpty {
                        Text(client.identificationNumber)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(revenue.formattedAsCurrency)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Text(String(localized: "facturado"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 12) {
                Button(action: onView) {
                    Label(String(localized: "Ver detalles"), systemImage: "eye")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: onInvoice) {
                    Label(String(localized: "Facturar"), systemImage: "plus.circle")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(16)
        .cardStyle(cornerRadius: 12)
    }
}

// MARK: - Client Editor State

private enum iOSClientEditorState: Identifiable {
    case create
    case edit(Client)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let client): return client.id.uuidString
        }
    }

    var mode: AddClientView.Mode {
        switch self {
        case .create: return .create
        case .edit(let client): return .edit(client)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Invoice.self, InvoiceItem.self, CompanyProfile.self,
        Client.self, Issuer.self, InvoiceTemplate.self, InvoiceTemplateItem.self,
        configurations: config
    )
    return iOSClientListView()
        .modelContainer(container)
        .environmentObject(try! SubscriptionService(storeConfiguration: .testing, startTasks: false))
}
