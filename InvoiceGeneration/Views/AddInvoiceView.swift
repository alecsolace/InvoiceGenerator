import SwiftUI
import SwiftData
import Foundation

/// View for adding a new invoice
struct AddInvoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: InvoiceViewModel
    
    @State private var invoiceNumber = String.generateInvoiceNumber()
    @State private var clientName = ""
    @State private var clientEmail = ""
    @State private var clientAddress = ""
    @State private var issueDate = Date()
    @State private var dueDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.InvoiceForm.invoiceNumber, text: $invoiceNumber)

                    DatePicker(L10n.InvoiceForm.issueDate, selection: $issueDate, displayedComponents: .date)

                    DatePicker(L10n.InvoiceForm.dueDate, selection: $dueDate, displayedComponents: .date)
                } header: {
                    Text(L10n.InvoiceForm.invoiceDetails)
                }

                Section {
                    TextField(L10n.InvoiceForm.clientName, text: $clientName)

                    TextField(L10n.InvoiceForm.email, text: $clientEmail)
                        .textContentType(.emailAddress)
                        .disableAutocorrection(true)


                    TextField(L10n.InvoiceForm.address, text: $clientAddress, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text(L10n.InvoiceForm.clientInformation)
                }
            }
            .navigationTitle(L10n.InvoiceForm.newInvoiceTitle)
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
                    Button(L10n.Common.create) {
                        createInvoice()
                    }
                    .disabled(clientName.isEmpty || invoiceNumber.isEmpty)
                }
            }
        }
    }
    
    private func createInvoice() {
        viewModel.createInvoice(
            invoiceNumber: invoiceNumber,
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
        for: Invoice.self, InvoiceItem.self, CompanyProfile.self,
        configurations: config
    )
    
    let viewModel = InvoiceViewModel(modelContext: container.mainContext)
    
    return AddInvoiceView(viewModel: viewModel)
}
