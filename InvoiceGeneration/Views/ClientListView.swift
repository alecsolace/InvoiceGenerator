import SwiftUI
import SwiftData

/// View listing saved clients for reuse
struct ClientListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ClientViewModel?
    @State private var showingAddClient = false
    @State private var selectedClient: Client?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    if viewModel.isLoading {
                        ProgressView("Loading clients...")
                    } else if viewModel.clients.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(viewModel.clients) { client in
                                ClientRowView(client: client)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedClient = client }
                                    .platformContextActions {
                                        viewModel.deleteClient(client)
                                    }
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Clients")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingAddClient) {
                if let viewModel = viewModel {
                    AddClientView(viewModel: viewModel)
                }
            }
            .sheet(item: $selectedClient) { client in
                if let viewModel = viewModel {
                    AddClientView(viewModel: viewModel, clientToEdit: client)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ClientViewModel(modelContext: modelContext)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No Clients")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add clients to reuse their details when creating invoices.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(action: { showingAddClient = true }) {
                Label("Add Client", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(action: { showingAddClient = true }) {
                Label("Add Client", systemImage: "plus")
            }
        }
    }
}

/// Row view for a client entry
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
            if !client.phone.isEmpty {
                Label(client.phone, systemImage: "phone")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Reusable form for creating or editing a client
struct AddClientView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: ClientViewModel
    var clientToEdit: Client?
    var onSave: ((Client) -> Void)?

    @State private var name: String
    @State private var email: String
    @State private var address: String
    @State private var phone: String

    init(viewModel: ClientViewModel, clientToEdit: Client? = nil, onSave: ((Client) -> Void)? = nil) {
        self.viewModel = viewModel
        self.clientToEdit = clientToEdit
        self.onSave = onSave
        _name = State(initialValue: clientToEdit?.name ?? "")
        _email = State(initialValue: clientToEdit?.email ?? "")
        _address = State(initialValue: clientToEdit?.address ?? "")
        _phone = State(initialValue: clientToEdit?.phone ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Client Information") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
#if os(iOS)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
#endif
                    TextField("Phone", text: $phone)
#if os(iOS)
                        .keyboardType(.phonePad)
#endif
                    TextField("Address", text: $address, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(clientToEdit == nil ? "Add Client" : "Edit Client")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(clientToEdit == nil ? "Save" : "Update") {
                        saveClient()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveClient() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let clientToEdit = clientToEdit {
            viewModel.updateClient(clientToEdit, name: trimmedName, email: email, address: address, phone: phone)
            onSave?(clientToEdit)
        } else {
            let client = viewModel.createClient(name: trimmedName, email: email, address: address, phone: phone)
            onSave?(client)
        }

        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Client.self,
        configurations: config
    )

    let viewModel = ClientViewModel(modelContext: container.mainContext)

    return ClientListView()
        .modelContainer(container)
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
