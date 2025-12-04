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
                Section {
                    LabeledContent(L10n.InvoiceForm.invoiceNumber, value: invoice.invoiceNumber)
                    LabeledContent(L10n.InvoiceForm.issueDate, value: invoice.issueDate.mediumFormat)
                    LabeledContent(L10n.InvoiceForm.dueDate, value: invoice.dueDate.mediumFormat)

                    HStack {
                        Text(L10n.InvoiceDetail.status)
                        Spacer()
                        Menu {
                            ForEach(InvoiceStatus.allCases, id: \.self) { status in
                                Button(status.localizedName) {
                                    viewModel.updateStatus(invoice, status: status)
                                }
                            }
                        } label: {
                            HStack {
                                Text(invoice.status.localizedName)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                            }
                            .foregroundStyle(statusColor)
                        }
                    }
                } header: {
                    Text(L10n.InvoiceDetail.information)
                }

                Section {
                    LabeledContent(L10n.InvoiceForm.clientName, value: invoice.clientName)
                    if !invoice.clientEmail.isEmpty {
                        LabeledContent(L10n.InvoiceForm.email, value: invoice.clientEmail)
                    }
                    if !invoice.clientAddress.isEmpty {
                        LabeledContent(L10n.InvoiceForm.address, value: invoice.clientAddress)
                    }
                } header: {
                    Text(L10n.InvoiceForm.clientInformation)
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
                                Text(L10n.Messages.itemQuantityPrice(
                                    quantity: item.quantity,
                                    unitPrice: item.unitPrice.formattedAsCurrency
                                ))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.removeItem(item, from: invoice)
                            } label: {
                                Label(L10n.Common.delete, systemImage: "trash")
                            }
                        }
                    }

                    Button(action: { showingAddItem = true }) {
                        Label(L10n.InvoiceItemForm.addItemTitle, systemImage: "plus.circle")
                    }
                } header: {
                    Text(L10n.InvoiceDetail.items)
                } footer: {
                    HStack {
                        Text(L10n.InvoiceDetail.total)
                            .font(.headline)
                        Spacer()
                        Text(invoice.totalAmount.formattedAsCurrency)
                            .font(.headline)
                    }
                    .padding(.top, 8)
                }
                
                if !invoice.notes.isEmpty {
                    Section {
                        Text(invoice.notes)
                    } header: {
                        Text(L10n.InvoiceDetail.notes)
                    }
                }
            }
            .navigationTitle(L10n.InvoiceDetail.title)
            #if iOS
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.done) {
                        dismiss()
                    }
                }

                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { generatePDF() }) {
                            Label(L10n.InvoiceDetail.generatePDF, systemImage: "doc.fill")
                        }

                        Button(action: { showingEditInvoice = true }) {
                            Label(L10n.Common.edit, systemImage: "pencil")
                        }
                    } label: {
                        Label(L10n.Common.more, systemImage: "ellipsis.circle")
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button(action: { generatePDF() }) {
                            Label(L10n.InvoiceDetail.generatePDF, systemImage: "doc.fill")
                        }

                        Button(action: { showingEditInvoice = true }) {
                            Label(L10n.Common.edit, systemImage: "pencil")
                        }
                    } label: {
                        Label(L10n.Common.more, systemImage: "ellipsis.circle")
                    }
                }
                #endif
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
            let fileName = L10n.PDF.fileName(invoice.invoiceNumber)
            if let url = PDFGeneratorService.savePDF(pdfDocument, fileName: fileName) {
                pdfURL = url
                showingShareSheet = true
            }
        }
    }
}

/// Share sheet for sharing PDF documents - iOS/macOS compatible
#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#elseif canImport(AppKit)
struct ShareSheet: NSViewRepresentable {
    let items: [Any]
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // On macOS, use NSSharingService
        DispatchQueue.main.async {
            guard let url = items.first as? URL else { return }
            let sharingService = NSSharingService(named: .sendViaAirDrop)
            sharingService?.perform(withItems: [url])
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif

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
