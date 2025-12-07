import SwiftUI
import SwiftData
import Foundation

/// View for adding a new invoice
struct AddInvoiceView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
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
    @State private var showingPaywall = false
    @State private var draftItems: [DraftInvoiceItem] = []
    @State private var showingAddItem = false
    @State private var editingDraftItem: DraftInvoiceItem?

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
                        handleAddClientTap()
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

                Section("Items") {
                    if draftItems.isEmpty {
                        Text("Add invoice items now so totals are accurate from the start.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(draftItems) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.description)
                                        .font(.headline)
                                    Spacer()
                                    Text(item.total.formattedAsCurrency)
                                        .font(.headline)
                                }
                                Text("\(item.quantity) × \(item.unitPrice.formattedAsCurrency)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 12) {
                                    Button(action: { editingDraftItem = item }) {
                                        Label("Edit", systemImage: "slider.horizontal.3")
                                            .labelStyle(.iconOnly)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(role: .destructive, action: { removeDraftItem(item) }) {
                                        Label("Delete", systemImage: "trash")
                                            .labelStyle(.iconOnly)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        HStack {
                            Text("Items Total")
                            Spacer()
                            Text(itemsTotal.formattedAsCurrency)
                                .fontWeight(.semibold)
                        }
                    }
                    Button {
                        showingAddItem = true
                    } label: {
                        Label("Add Item", systemImage: "plus.circle")
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

    private func handleAddClientTap() {
        let count = clientViewModel?.clients.count ?? 0
        if subscriptionService.canAddClient(currentCount: count) {
            showingAddClient = true
        } else {
            showingPaywall = true
        }
    }

    private func createInvoice() {
        let selectedClient = clientViewModel?.clients.first(where: { $0.id == selectedClientID })
        let preparedItems = draftItems.map {
            InvoiceLineItemInput(
                description: $0.description,
                quantity: $0.quantity,
                unitPrice: $0.unitPrice
            )
        }

        viewModel.createInvoice(
            invoiceNumber: invoiceNumber,
            clientName: clientName,
            clientEmail: clientEmail,
            clientAddress: clientAddress,
            client: selectedClient,
            issueDate: issueDate,
            dueDate: dueDate,
            items: preparedItems
        )
        dismiss()
    }

    private func removeDraftItem(_ item: DraftInvoiceItem) {
        draftItems.removeAll { $0.id == item.id }
    }

    private var itemsTotal: Decimal {
        draftItems.reduce(0) { $0 + $1.total }
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
        .environmentObject(SubscriptionService())
}

// MARK: - Draft Item Support

private struct DraftInvoiceItem: Identifiable, Equatable {
    let id: UUID
    var description: String
    var quantity: Int
    var unitPrice: Decimal
    
    init(id: UUID = UUID(), description: String, quantity: Int, unitPrice: Decimal) {
        self.id = id
        self.description = description
        self.quantity = quantity
        self.unitPrice = unitPrice
    }
    
    var total: Decimal { Decimal(quantity) * unitPrice }
}

private struct InvoiceDraftItemEditor: View {
    enum Mode {
        case add
        case edit(DraftInvoiceItem)
        
        var title: String {
            switch self {
            case .add: return "Add Item"
            case .edit: return "Edit Item"
            }
        }
    }
    
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    let onSave: (DraftInvoiceItem) -> Void
    
    @State private var descriptionText: String
    @State private var quantity: Int
    @State private var unitPrice: String
    
    init(mode: Mode, onSave: @escaping (DraftInvoiceItem) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            _descriptionText = State(initialValue: "")
            _quantity = State(initialValue: 1)
            _unitPrice = State(initialValue: "")
        case .edit(let item):
            _descriptionText = State(initialValue: item.description)
            _quantity = State(initialValue: item.quantity)
            _unitPrice = State(initialValue: NSDecimalNumber(decimal: item.unitPrice).stringValue)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Description", text: $descriptionText, axis: .vertical)
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
            .navigationTitle(mode.title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { persist() }
                        .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !descriptionText.isEmpty && Decimal(string: unitPrice) != nil
    }
    
    private func persist() {
        guard let price = Decimal(string: unitPrice) else { return }
        let identifier: UUID
        switch mode {
        case .add:
            identifier = UUID()
        case .edit(let item):
            identifier = item.id
        }
        let draft = DraftInvoiceItem(
            id: identifier,
            description: descriptionText,
            quantity: quantity,
            unitPrice: price
        )
        onSave(draft)
        dismiss()
    }
}
