import SwiftUI
import SwiftData
import Foundation

/// View for adding a new invoice
struct AddInvoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: InvoiceViewModel
    @State private var clientViewModel: ClientViewModel?
    @Query(sort: [SortDescriptor(\.name)]) private var clients: [Client]
    
    @State private var invoiceNumber = String.generateInvoiceNumber()
    @State private var clientName = ""
    @State private var clientEmail = ""
    @State private var clientAddress = ""
    @State private var selectedClient: Client?
    @State private var showingAddClient = false
    @State private var issueDate = Date()
    @State private var dueDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Invoice Details") {
                    TextField("Invoice Number", text: $invoiceNumber)
                    
                    DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
                    
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }

                Section("Client Information") {
                    Picker("Client", selection: $selectedClient) {
                        Text("New Client").tag(nil as Client?)

                        ForEach(clients) { client in
                            Text(client.name).tag(Optional(client))
                        }
                    }

                    TextField("Client Name", text: $clientName)

                    TextField("Email", text: $clientEmail)
                        .textContentType(.emailAddress)
                        .disableAutocorrection(true)

                    
                    TextField("Address", text: $clientAddress, axis: .vertical)
                        .lineLimit(3...6)

                    Button(action: { showingAddClient = true }) {
                        Label("Add Client", systemImage: "person.crop.circle.badge.plus")
                    }
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
            .onChange(of: selectedClient) { _, newClient in
                guard let newClient else { return }
                clientName = newClient.name
                clientEmail = newClient.email
                clientAddress = newClient.address
            }
            .sheet(isPresented: $showingAddClient) {
                if let clientViewModel {
                    AddClientView(viewModel: clientViewModel) { client in
                        selectedClient = client
                        clientName = client.name
                        clientEmail = client.email
                        clientAddress = client.address
                    }
                }
            }
        }
    }
    
    private func createInvoice() {
        viewModel.createInvoice(
            invoiceNumber: invoiceNumber,
            client: selectedClient,
            clientName: clientName,
            clientEmail: clientEmail,
            clientAddress: clientAddress
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
    
    let client = Client(name: "Globex", email: "ap@globex.com")
    container.mainContext.insert(client)

    return AddInvoiceView(viewModel: viewModel)
}
