import SwiftUI
import SwiftData

/// View displaying saved clients
struct ClientListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ClientViewModel?
    @State private var searchText = ""
    @State private var showingAddClient = false
    @State private var editingClient: Client?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    if viewModel.isLoading {
                        ProgressView("Loading clients…")
                    } else if viewModel.clients.isEmpty {
                        emptyStateView
                    } else {
                        clientList(viewModel: viewModel)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Clients")
            .searchable(text: $searchText, prompt: "Search clients")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddClient = true }) {
                        Label("Add Client", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddClient) {
                if let viewModel = viewModel {
                    AddClientView(viewModel: viewModel) { _ in
                        self.viewModel?.fetchClients()
                    }
                }
            }
            .sheet(item: $editingClient) { client in
                if let viewModel = viewModel {
                    AddClientView(viewModel: viewModel, client: client) { _ in
                        self.viewModel?.fetchClients()
                    }
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ClientViewModel(modelContext: modelContext)
            }
        }
        .onChange(of: searchText) { _, newValue in
            viewModel?.searchClients(query: newValue)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Clients")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add your first client to reuse details when generating invoices")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { showingAddClient = true }) {
                Label("Add Client", systemImage: "person.crop.circle.badge.plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func clientList(viewModel: ClientViewModel) -> some View {
        List {
            ForEach(viewModel.clients) { client in
                ClientRowView(client: client)
                    .contentShape(Rectangle())
                    .onTapGesture { editingClient = client }
                    .platformContextActions {
                        viewModel.deleteClient(client)
                    }
            }
        }
    }
}

private struct ClientRowView: View {
    let client: Client

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(client.name)
                .font(.headline)

            if !client.email.isEmpty {
                Label(client.email, systemImage: "envelope")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !client.address.isEmpty {
                Label(client.address, systemImage: "location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddClientView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: ClientViewModel
    let client: Client?
    var onSave: ((Client) -> Void)?

    @State private var name: String
    @State private var email: String
    @State private var address: String

    init(viewModel: ClientViewModel, client: Client? = nil, onSave: ((Client) -> Void)? = nil) {
        self.viewModel = viewModel
        self.client = client
        self.onSave = onSave
        _name = State(initialValue: client?.name ?? "")
        _email = State(initialValue: client?.email ?? "")
        _address = State(initialValue: client?.address ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Client Details") {
                    TextField("Name", text: $name)

                    TextField("Email", text: $email)
#if os(iOS)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
#endif

                    TextField("Address", text: $address, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(client == nil ? "Add Client" : "Edit Client")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(client == nil ? "Save" : "Update") {
                        saveClient()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func saveClient() {
        if let client {
            viewModel.updateClient(client, name: name, email: email, address: address)
            onSave?(client)
        } else if let newClient = viewModel.createClient(name: name, email: email, address: address) {
            onSave?(newClient)
        }

        dismiss()
    }
}

#Preview("Clients") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self,
        configurations: config
    )

    let viewModel = ClientViewModel(modelContext: container.mainContext)
    viewModel.createClient(name: "Acme Corp", email: "billing@acme.com", address: "123 Main St")

    return ClientListView()
        .modelContainer(container)
}

#Preview("Add Client") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self,
        configurations: config
    )

    let viewModel = ClientViewModel(modelContext: container.mainContext)

    return AddClientView(viewModel: viewModel)
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
                Label("Delete", systemImage: "trash")
            }
        }
        #endif
    }
}
