import SwiftUI
import SwiftData

/// Detailed view for a single invoice
struct InvoiceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let invoice: Invoice
    @Bindable var viewModel: InvoiceViewModel
    
    @State private var showingAddItem = false
    @State private var showingEditInvoice = false
    @State private var showingShareSheet = false
    @State private var pdfURL: URL?
    
    var body: some View {
        NavigationStack {
            List {
                Section("Invoice Information") {
                    LabeledContent("Invoice Number", value: invoice.invoiceNumber)
                    LabeledContent("Issue Date", value: invoice.issueDate.mediumFormat)
                    LabeledContent("Due Date", value: invoice.dueDate.mediumFormat)
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        Menu {
                            ForEach(InvoiceStatus.allCases, id: \.self) { status in
                                Button(status.rawValue) {
                                    viewModel.updateStatus(invoice, status: status)
                                }
                            }
                        } label: {
                            HStack {
                                Text(invoice.status.rawValue)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                            }
                            .foregroundStyle(statusColor)
                        }
                    }
                }
                
                Section("Client Information") {
                    LabeledContent("Name", value: invoice.clientName)
                    if !invoice.clientEmail.isEmpty {
                        LabeledContent("Email", value: invoice.clientEmail)
                    }
                    if !invoice.clientAddress.isEmpty {
                        LabeledContent("Address", value: invoice.clientAddress)
                    }
                }
                
                Section {
                    ForEach(invoice.items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.itemDescription)
                                    .font(.headline)
                                Spacer()
                                Text(item.total.formattedAsCurrency)
                                    .font(.headline)
                            }
                            
                            HStack {
                                Text("\(item.quantity) × \(item.unitPrice.formattedAsCurrency)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.removeItem(item, from: invoice)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    
                    Button(action: { showingAddItem = true }) {
                        Label("Add Item", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Items")
                } footer: {
                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text(invoice.totalAmount.formattedAsCurrency)
                            .font(.headline)
                    }
                    .padding(.top, 8)
                }
                
                if !invoice.notes.isEmpty {
                    Section("Notes") {
                        Text(invoice.notes)
                    }
                }
            }
            .navigationTitle("Invoice Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { generatePDF() }) {
                            Label("Generate PDF", systemImage: "doc.fill")
                        }
                        
                        Button(action: { showingEditInvoice = true }) {
                            Label("Edit", systemImage: "pencil")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView(invoice: invoice, viewModel: viewModel)
            }
            .sheet(isPresented: $showingEditInvoice) {
                EditInvoiceView(invoice: invoice, viewModel: viewModel)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let pdfURL = pdfURL {
                    ShareSheet(items: [pdfURL])
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch invoice.status {
        case .draft: return .gray
        case .sent: return .blue
        case .paid: return .green
        case .overdue: return .red
        case .cancelled: return .orange
        }
    }
    
    private func generatePDF() {
        let descriptor = FetchDescriptor<CompanyProfile>()
        let profiles = try? modelContext.fetch(descriptor)
        let profile = profiles?.first
        
        if let pdfDocument = PDFGeneratorService.generateInvoicePDF(
            invoice: invoice,
            companyProfile: profile
        ) {
            let fileName = "Invoice_\(invoice.invoiceNumber)"
            if let url = PDFGeneratorService.savePDF(pdfDocument, fileName: fileName) {
                pdfURL = url
                showingShareSheet = true
            }
        }
    }
}

/// Share sheet for iOS
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
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
    
    return InvoiceDetailView(invoice: invoice, viewModel: viewModel)
        .modelContainer(container)
}
