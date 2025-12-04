import SwiftUI
import SwiftData
import Foundation

/// View for adding a new invoice
struct AddInvoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: InvoiceViewModel

    @State private var clientViewModel: ClientViewModel?

    @State private var invoiceNumber = String.generateInvoiceNumber()
    @State private var clientName = ""
    @State private var clientEmail = ""
    @State private var clientAddress = ""
    @State private var issueDate = Date()
    @State private var dueDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
    @State private var selectedClientID: UUID?
    @State private var showingAddClient = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Invoice Details") {
                    TextField("Invoice Number", text: $invoiceNumber)

                    DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)

                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }

                Section("Saved Clients") {
                    if let clients = clientViewModel?.clients, !clients.isEmpty {
                        Picker("Client", selection: $selectedClientID) {
                            Text("None")
                                .tag(UUID?.none)

                            ForEach(clients) { client in
                                Text(client.name)
                                    .tag(Optional(client.id))
                            }
                        }
                    } else {
                        Text("No saved clients yet")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingAddClient = true
                    } label: {
                        Label("Add Client", systemImage: "plus")
                    }
                }

                Section("Client Information") {
                    TextField("Client Name", text: $clientName)

                    TextField("Email", text: $clientEmail)
                        .textContentType(.emailAddress)
                        .disableAutocorrection(true)

                    
                    TextField("Address", text: $clientAddress, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Invoice")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createInvoice()
                    }
                    .disabled(clientName.isEmpty || invoiceNumber.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddClient) {
                if let clientViewModel = clientViewModel {
                    AddClientView(viewModel: clientViewModel) { client in
                        selectedClientID = client.id
                        clientName = client.name
                        clientEmail = client.email
                        clientAddress = client.address
                    }
                }
            }
        }
        .onAppear {
            if clientViewModel == nil {
                clientViewModel = ClientViewModel(modelContext: modelContext)
            }
        }
        .onChange(of: selectedClientID) { _, newValue in
            guard
                let newValue,
                let client = clientViewModel?.clients.first(where: { $0.id == newValue })
            else { return }

            clientName = client.name
            clientEmail = client.email
            clientAddress = client.address
        }
    }

    private func createInvoice() {
        let selectedClient = clientViewModel?.clients.first(where: { $0.id == selectedClientID })

        viewModel.createInvoice(
            invoiceNumber: invoiceNumber,
            clientName: clientName,
            clientEmail: clientEmail,
            clientAddress: clientAddress,
            client: selectedClient
        )
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self,
        configurations: config
    )
    
    let viewModel = InvoiceViewModel(modelContext: container.mainContext)
    
    return AddInvoiceView(viewModel: viewModel)
}
