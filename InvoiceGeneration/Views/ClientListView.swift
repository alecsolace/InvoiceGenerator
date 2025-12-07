import SwiftUI
import SwiftData

/// View displaying list of clients
struct ClientListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ClientViewModel?
    @State private var showingAddClient = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    if viewModel.isLoading {
                        ProgressView("Loading clients...")
                    } else if viewModel.clients.isEmpty {
                        emptyState
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
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddClient = true }) {
                        Label("Add Client", systemImage: "plus")
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button(action: { showingAddClient = true }) {
                        Label("Add Client", systemImage: "plus")
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingAddClient) {
                if let viewModel = viewModel {
                    AddClientView(viewModel: viewModel)
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Clients")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add clients to reuse their details on invoices")
                .foregroundStyle(.secondary)

            Button(action: { showingAddClient = true }) {
                Label("Add Client", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func clientList(viewModel: ClientViewModel) -> some View {
        List {
            ForEach(viewModel.clients) { client in
                VStack(alignment: .leading, spacing: 6) {
                    Text(client.name)
                        .font(.headline)

                    if !client.email.isEmpty {
                        Label(client.email, systemImage: "envelope")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !client.address.isEmpty {
                        Label(client.address, systemImage: "house")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .platformContextActions {
                    viewModel.deleteClient(client)
                }
            }
        }
    }
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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self,
        configurations: config
    )

    return ClientListView()
        .modelContainer(container)
}
