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
    @Environment(\.dismiss) private var dismiss
    
    let invoice: Invoice
    @Bindable var viewModel: InvoiceViewModel
    
    @State private var clientName: String
    @State private var clientEmail: String
    @State private var clientAddress: String
    @State private var notes: String
    
    init(invoice: Invoice, viewModel: InvoiceViewModel) {
        self.invoice = invoice
        self.viewModel = viewModel
        _clientName = State(initialValue: invoice.clientName)
        _clientEmail = State(initialValue: invoice.clientEmail)
        _clientAddress = State(initialValue: invoice.clientAddress)
        _notes = State(initialValue: invoice.notes)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Client Information") {
                    TextField("Client Name", text: $clientName)
                    
                    TextField("Email", text: $clientEmail)
#if os(iOS)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
#endif
                    
                    TextField("Address", text: $clientAddress, axis: .vertical)
                        .lineLimit(3...6)
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
    }
    
    private func saveChanges() {
        invoice.clientName = clientName
        invoice.clientEmail = clientEmail
        invoice.clientAddress = clientAddress
        invoice.notes = notes
        
        viewModel.updateInvoice(invoice)
        dismiss()
    }
}

#Preview("Add Item") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Invoice.self, InvoiceItem.self, CompanyProfile.self,
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
        for: Invoice.self, InvoiceItem.self, CompanyProfile.self,
        configurations: config
    )
    
    let invoice = Invoice(
        invoiceNumber: "INV-202412-1234",
        clientName: "Acme Corp"
    )
    container.mainContext.insert(invoice)
    
    let viewModel = InvoiceViewModel(modelContext: container.mainContext)
    
    return EditInvoiceView(invoice: invoice, viewModel: viewModel)
}
