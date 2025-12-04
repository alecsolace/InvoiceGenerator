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
    @State private var selectedClient: Client?
    @State private var showingAddClient = false

    @Query(sort: [SortDescriptor(\.name)]) private var clients: [Client]

    var body: some View {
        NavigationStack {
            Form {
                Section("Invoice Details") {
                    TextField("Invoice Number", text: $invoiceNumber)
                    
                    DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
                    
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }

                Section("Client Information") {
                    if clients.isEmpty {
                        Label("No clients yet", systemImage: "person.crop.circle.badge.plus")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Select Client", selection: $selectedClient) {
                            Text("None").tag(Client?.none)
                            ForEach(clients) { client in
                                Text(client.name).tag(Optional(client))
                            }
                        }
                    }

                    Button {
                        showingAddClient = true
                    } label: {
                        Label("Add Client", systemImage: "plus.circle")
                    }

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
            .onAppear {
                if clientViewModel == nil {
                    clientViewModel = ClientViewModel(modelContext: modelContext)
                }
            }
            .onChange(of: selectedClient) { _, client in
                guard let client else { return }
                clientName = client.name
                clientEmail = client.email
                clientAddress = client.address
            }
            .sheet(isPresented: $showingAddClient) {
                if let clientViewModel = clientViewModel {
                    AddClientView(viewModel: clientViewModel) { newClient in
                        selectedClient = newClient
                        clientName = newClient.name
                        clientEmail = newClient.email
                        clientAddress = newClient.address
                    }
                }
            }
        }
    }

    private func createInvoice() {
        viewModel.createInvoice(
            invoiceNumber: invoiceNumber,
            clientName: clientName,
            clientEmail: clientEmail,
            clientAddress: clientAddress,
            client: selectedClient,
            issueDate: issueDate,
            dueDate: dueDate
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
