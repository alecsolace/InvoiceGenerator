import SwiftUI
import SwiftData

/// View for adding an item to an invoice
struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    
    let invoice: Invoice
    @Bindable var viewModel: InvoiceViewModel
    
    @State private var itemDescription = ""
    @State private var quantity = 1
    @State private var unitPrice = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Description", text: $itemDescription, axis: .vertical)
                        .lineLimit(2...4)
                    
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...999)
                    
                    TextField("Unit Price", text: $unitPrice)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                }
                
                if let price = Decimal(string: unitPrice), price > 0 {
                    Section {
                        LabeledContent("Total", value: (price * Decimal(quantity)).formattedAsCurrency)
                    }
                }
            }
            .navigationTitle("Add Item")
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
                    Button("Add") {
                        addItem()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !itemDescription.isEmpty && quantity > 0 && Decimal(string: unitPrice) != nil
    }
    
    private func addItem() {
        guard let price = Decimal(string: unitPrice) else { return }
        
        viewModel.addItem(
            to: invoice,
            description: itemDescription,
            quantity: quantity,
            unitPrice: price
        )
        dismiss()
    }
}

/// View for editing an invoice
struct EditInvoiceView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let invoice: Invoice
    @Bindable var viewModel: InvoiceViewModel
    
    @State private var clientViewModel: ClientViewModel?
    @State private var selectedClientID: UUID?
    @State private var showingAddClient = false
    @State private var showingPaywall = false
    @State private var clientName: String
    @State private var clientEmail: String
    @State private var clientAddress: String
    @State private var notes: String
    private let initialClientName: String
    private let initialClientEmail: String
    private let initialClientAddress: String
    
    init(invoice: Invoice, viewModel: InvoiceViewModel) {
        self.invoice = invoice
        self.viewModel = viewModel
        self.initialClientName = invoice.clientName
        self.initialClientEmail = invoice.clientEmail
        self.initialClientAddress = invoice.clientAddress
        _clientName = State(initialValue: invoice.clientName)
        _clientEmail = State(initialValue: invoice.clientEmail)
        _clientAddress = State(initialValue: invoice.clientAddress)
        _notes = State(initialValue: invoice.notes)
        _selectedClientID = State(initialValue: invoice.client?.id)
    }
    
    var body: some View {
        NavigationStack {
            Form {
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
                        handleAddClientTap()
                    } label: {
                        Label("Add Client", systemImage: "plus")
                    }
                }
                
                Section("Client Information") {
                    LabeledContent("Client Name", value: clientName.isEmpty ? "—" : clientName)
                    LabeledContent("Email", value: clientEmail.isEmpty ? "—" : clientEmail)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Address")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(clientAddress.isEmpty ? "—" : clientAddress)
                    }
                }
                
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle("Edit Invoice")
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
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(clientName.isEmpty)
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
                let id = newValue,
                let client = clientViewModel?.clients.first(where: { $0.id == id })
            else {
                clientName = initialClientName
                clientEmail = initialClientEmail
                clientAddress = initialClientAddress
                return
            }
            clientName = client.name
            clientEmail = client.email
            clientAddress = client.address
        }
        .sheet(isPresented: $showingAddClient) {
            if let clientViewModel {
                AddClientView(viewModel: clientViewModel) { client in
                    selectedClientID = client.id
                    clientName = client.name
                    clientEmail = client.email
                    clientAddress = client.address
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(reason: .clientLimit)
                .environmentObject(subscriptionService)
        }
    }
    
    private func saveChanges() {
        if let clientViewModel,
           let selectedClientID,
           let selectedClient = clientViewModel.clients.first(where: { $0.id == selectedClientID }) {
            invoice.client = selectedClient
        } else {
            invoice.client = nil
        }
        invoice.clientName = clientName
        invoice.clientEmail = clientEmail
        invoice.clientAddress = clientAddress
        invoice.notes = notes
        
        viewModel.updateInvoice(invoice)
        dismiss()
    }

    private func handleAddClientTap() {
        let count = clientViewModel?.clients.count ?? 0
        if subscriptionService.canAddClient(currentCount: count) {
            showingAddClient = true
        } else {
            showingPaywall = true
        }
    }
}

#Preview("Add Item") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self,
        configurations: config
    )
    
    let invoice = Invoice(
        invoiceNumber: "INV-202412-1234",
        clientName: "Acme Corp"
    )
    container.mainContext.insert(invoice)
    
    let viewModel = InvoiceViewModel(modelContext: container.mainContext)
    
    return AddItemView(invoice: invoice, viewModel: viewModel)
}

#Preview("Edit Invoice") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self,
        configurations: config
    )
    
    let invoice = Invoice(
        invoiceNumber: "INV-202412-1234",
        clientName: "Acme Corp"
    )
    container.mainContext.insert(invoice)
    
    let viewModel = InvoiceViewModel(modelContext: container.mainContext)
    
    return EditInvoiceView(invoice: invoice, viewModel: viewModel)
        .environmentObject(SubscriptionService())
}
