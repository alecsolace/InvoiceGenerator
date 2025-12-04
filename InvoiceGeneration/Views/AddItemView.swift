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
                Section {
                    TextField(L10n.InvoiceItemForm.description, text: $itemDescription, axis: .vertical)
                        .lineLimit(2...4)

                    Stepper(value: $quantity, in: 1...999) {
                        Text(L10n.Messages.quantity(quantity))
                    }

                    TextField(L10n.InvoiceItemForm.unitPrice, text: $unitPrice)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                } header: {
                    Text(L10n.InvoiceItemForm.itemDetails)
                }

                if let price = Decimal(string: unitPrice), price > 0 {
                    Section {
                        LabeledContent(L10n.InvoiceDetail.total, value: (price * Decimal(quantity)).formattedAsCurrency)
                    }
                }
            }
            .navigationTitle(L10n.InvoiceItemForm.addItemTitle)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.add) {
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
                Section {
                    TextField(L10n.InvoiceForm.clientName, text: $clientName)

                    TextField(L10n.InvoiceForm.email, text: $clientEmail)
#if os(iOS)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
#endif

                    TextField(L10n.InvoiceForm.address, text: $clientAddress, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text(L10n.InvoiceForm.clientInformation)
                }

                Section {
                    TextField(L10n.InvoiceDetail.notes, text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                } header: {
                    Text(L10n.InvoiceDetail.notes)
                }
            }
            .navigationTitle(L10n.InvoiceForm.editInvoiceTitle)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) {
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
