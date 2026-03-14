import SwiftUI
import SwiftData
import Foundation

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
    @State private var issuerViewModel: IssuerViewModel?
    @State private var selectedClientID: UUID?
    @State private var selectedIssuerID: UUID?
    @State private var showingAddClient = false
    @State private var showingPaywall = false
    @State private var showingAddItem = false
    @State private var editingDraftItem: DraftInvoiceItem?
    @State private var invoiceNumber: String
    @State private var clientName: String
    @State private var clientEmail: String
    @State private var clientIdentificationNumber: String
    @State private var clientAddress: String
    @State private var issueDate: Date
    @State private var dueDate: Date
    @State private var notes: String
    @State private var ivaPercentage: String
    @State private var irpfPercentage: String
    @State private var draftItems: [DraftInvoiceItem]
    @State private var pendingInvoiceSequenceByIssuerID: [UUID: Int] = [:]
    private let initialClientName: String
    private let initialClientEmail: String
    private let initialClientIdentificationNumber: String
    private let initialClientAddress: String
    
    init(invoice: Invoice, viewModel: InvoiceViewModel) {
        self.invoice = invoice
        self.viewModel = viewModel
        self.initialClientName = invoice.clientName
        self.initialClientEmail = invoice.clientEmail
        self.initialClientIdentificationNumber = invoice.clientIdentificationNumber
        self.initialClientAddress = invoice.clientAddress
        _invoiceNumber = State(initialValue: invoice.invoiceNumber)
        _clientName = State(initialValue: invoice.clientName)
        _clientEmail = State(initialValue: invoice.clientEmail)
        _clientIdentificationNumber = State(initialValue: invoice.clientIdentificationNumber)
        _clientAddress = State(initialValue: invoice.clientAddress)
        _issueDate = State(initialValue: invoice.issueDate)
        _dueDate = State(initialValue: invoice.dueDate)
        _notes = State(initialValue: invoice.notes)
        _ivaPercentage = State(initialValue: NSDecimalNumber(decimal: invoice.ivaPercentage).stringValue)
        _irpfPercentage = State(initialValue: NSDecimalNumber(decimal: invoice.irpfPercentage).stringValue)
        _selectedClientID = State(initialValue: invoice.client?.id)
        _selectedIssuerID = State(initialValue: invoice.issuer?.id)
        _draftItems = State(
            initialValue: (invoice.items ?? []).map {
                DraftInvoiceItem(
                    id: $0.id,
                    description: $0.itemDescription,
                    quantity: $0.quantity,
                    unitPrice: $0.unitPrice
                )
            }
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                InvoiceEditorSections(
                    issuers: issuerViewModel?.issuers ?? [],
                    clients: clientViewModel?.clients ?? [],
                    selectedIssuerID: $selectedIssuerID,
                    selectedClientID: $selectedClientID,
                    invoiceNumber: $invoiceNumber,
                    clientName: $clientName,
                    clientEmail: $clientEmail,
                    clientIdentificationNumber: $clientIdentificationNumber,
                    clientAddress: $clientAddress,
                    issueDate: $issueDate,
                    dueDate: $dueDate,
                    ivaPercentage: $ivaPercentage,
                    irpfPercentage: $irpfPercentage,
                    notes: $notes,
                    draftItems: $draftItems,
                    showingAddItem: $showingAddItem,
                    editingDraftItem: $editingDraftItem,
                    onAddClient: handleAddClientTap,
                    onUseNextInvoiceNumber: incrementSuggestedInvoiceNumber,
                    onRemoveDraftItem: removeDraftItem
                )
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
                    .disabled(clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if clientViewModel == nil {
                clientViewModel = ClientViewModel(modelContext: modelContext)
            }
            if issuerViewModel == nil {
                issuerViewModel = IssuerViewModel(modelContext: modelContext)
            }
            if let selectedIssuerID,
               pendingInvoiceSequenceByIssuerID[selectedIssuerID] == nil,
               let issuer = issuerViewModel?.issuers.first(where: { $0.id == selectedIssuerID }) {
                pendingInvoiceSequenceByIssuerID[selectedIssuerID] = max(issuer.nextInvoiceSequence - 1, 0)
            }
        }
        .onChange(of: selectedClientID) { _, newValue in
            guard
                let id = newValue,
                let client = clientViewModel?.clients.first(where: { $0.id == id })
            else {
                clientName = initialClientName
                clientEmail = initialClientEmail
                clientIdentificationNumber = initialClientIdentificationNumber
                clientAddress = initialClientAddress
                return
            }
            clientName = client.name
            clientEmail = client.email
            clientIdentificationNumber = client.identificationNumber
            clientAddress = client.address
        }
        .onChange(of: selectedIssuerID) { _, newValue in
            guard let newValue else { return }
            if pendingInvoiceSequenceByIssuerID[newValue] == nil,
               let issuer = issuerViewModel?.issuers.first(where: { $0.id == newValue }) {
                pendingInvoiceSequenceByIssuerID[newValue] = max(issuer.nextInvoiceSequence - 1, 0)
            }
        }
        .sheet(isPresented: $showingAddClient) {
            if let clientViewModel {
                AddClientView(viewModel: clientViewModel) { client in
                    selectedClientID = client.id
                    clientName = client.name
                    clientEmail = client.email
                    clientIdentificationNumber = client.identificationNumber
                    clientAddress = client.address
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            InvoiceDraftItemEditor(mode: .add) { draft in
                draftItems.append(draft)
            }
        }
        .sheet(item: $editingDraftItem) { item in
            InvoiceDraftItemEditor(mode: .edit(item)) { updated in
                if let index = draftItems.firstIndex(where: { $0.id == updated.id }) {
                    draftItems[index] = updated
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(reason: .clientLimit)
                .environmentObject(subscriptionService)
        }
    }
    
    private func saveChanges() {
        let selectedClient = selectedClientID.flatMap { id in
            clientViewModel?.clients.first(where: { $0.id == id })
        }
        let selectedIssuer = selectedIssuerID.flatMap { id in
            issuerViewModel?.issuers.first(where: { $0.id == id })
        }
        let items = draftItems.map {
            InvoiceLineItemInput(
                description: $0.description,
                quantity: $0.quantity,
                unitPrice: $0.unitPrice
            )
        }

        viewModel.updateInvoice(
            invoice,
            invoiceNumber: invoiceNumber,
            issuer: selectedIssuer,
            clientName: clientName,
            clientEmail: clientEmail,
            clientIdentificationNumber: clientIdentificationNumber,
            clientAddress: clientAddress,
            client: selectedClient,
            issueDate: issueDate,
            dueDate: dueDate,
            notes: notes,
            ivaPercentage: ivaPercentageValue,
            irpfPercentage: irpfPercentageValue,
            items: items
        )
        dismiss()
    }

    private var ivaPercentageValue: Decimal {
        Decimal(string: ivaPercentage) ?? 0
    }

    private var irpfPercentageValue: Decimal {
        Decimal(string: irpfPercentage) ?? 0
    }

    private func handleAddClientTap() {
        let count = clientViewModel?.clients.count ?? 0
        if subscriptionService.canAddClient(currentCount: count) {
            showingAddClient = true
        } else {
            showingPaywall = true
        }
    }

    private func incrementSuggestedInvoiceNumber() {
        guard let selectedIssuerID,
              let issuer = issuerViewModel?.issuers.first(where: { $0.id == selectedIssuerID }) else { return }
        let currentSequence = pendingInvoiceSequenceByIssuerID[issuer.id] ?? max(issuer.nextInvoiceSequence - 1, 0)
        let nextSequence = max(currentSequence + 1, 1)
        pendingInvoiceSequenceByIssuerID[issuer.id] = nextSequence
        invoiceNumber = InvoiceNumberingService.invoiceNumber(for: issuer, sequence: nextSequence)
    }

    private func removeDraftItem(_ item: DraftInvoiceItem) {
        draftItems.removeAll { $0.id == item.id }
    }
}

#Preview("Add Item") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self, Issuer.self,
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
        for: Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self, Issuer.self,
        configurations: config
    )
    
    let invoice = Invoice(
        invoiceNumber: "INV-202412-1234",
        clientName: "Acme Corp"
    )
    container.mainContext.insert(invoice)
    
    let viewModel = InvoiceViewModel(modelContext: container.mainContext)
    
    return EditInvoiceView(invoice: invoice, viewModel: viewModel)
        .environmentObject(try! SubscriptionService(storeConfiguration: .testing, startTasks: false))
}
