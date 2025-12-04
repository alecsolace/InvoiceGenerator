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
                Section("Invoice Details") {
                    TextField("Invoice Number", text: $invoiceNumber)
                    
                    DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
                    
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
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
