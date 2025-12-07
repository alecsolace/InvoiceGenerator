import Foundation
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

/// Detailed view for a single invoice
struct InvoiceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var invoice: Invoice
    @Bindable var viewModel: InvoiceViewModel
    
    @State private var showingAddItem = false
    @State private var showingEditInvoice = false
    @State private var showingShareSheet = false
    @State private var showingPDFSaveConfirmation = false
    @State private var pdfURL: URL?
    @State private var savedPDFURL: URL?
    
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
                                Button(status.localizedTitle) {
                                    viewModel.updateStatus(invoice, status: status)
                                }
                            }
                        } label: {
                            HStack {
                                Text(invoice.status.localizedTitle)
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
            #if iOS
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { generatePDF() }) {
                            Label("Generate PDF", systemImage: "doc.fill")
                        }
                        
                        if savedPDFURL != nil {
                            Button(action: { shareSavedPDF() }) {
                                Label("Share Saved PDF", systemImage: "square.and.arrow.up")
                            }
                        }
                        
                        Button(action: { showingEditInvoice = true }) {
                            Label("Edit", systemImage: "pencil")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button(action: { generatePDF() }) {
                            Label("Generate PDF", systemImage: "doc.fill")
                        }
                        
                        if savedPDFURL != nil {
                            Button(action: { shareSavedPDF() }) {
                                Label("Share Saved PDF", systemImage: "square.and.arrow.up")
                            }
                        }
                        
                        Button(action: { showingEditInvoice = true }) {
                            Label("Edit", systemImage: "pencil")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
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
        .alert("Invoice Saved", isPresented: $showingPDFSaveConfirmation, actions: {
            if savedPDFURL != nil {
                Button("Share") { shareSavedPDF() }
                #if canImport(AppKit)
                Button("Show in Finder") { revealPDFInFinder() }
                #endif
            }
            Button("OK", role: .cancel) {}
        }, message: {
            if let savedPDFURL {
                Text(
                    String(
                        format: NSLocalizedString(
                            "The PDF was saved to %@ in your Documents folder.",
                            comment: "Alert message when PDF is saved locally"
                        ),
                        savedPDFURL.lastPathComponent
                    )
                )
            }
        })
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
            let fileName = String(
                format: NSLocalizedString(
                    "Invoice_%@",
                    comment: "Saved invoice PDF file name format"
                ),
                invoice.invoiceNumber
            )
            if let url = PDFGeneratorService.savePDF(pdfDocument, fileName: fileName) {
                pdfURL = url
                savedPDFURL = url
                showingPDFSaveConfirmation = true
            }
        }
    }
    
    private func shareSavedPDF() {
        guard let url = savedPDFURL else { return }
        pdfURL = url
        showingShareSheet = true
    }
    
    #if canImport(AppKit)
    private func revealPDFInFinder() {
        guard let url = savedPDFURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    #endif
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
        DispatchQueue.main.async {
            let picker = NSSharingServicePicker(items: items)
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif

#Preview {
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
    
    return InvoiceDetailView(invoice: invoice, viewModel: viewModel)
        .modelContainer(container)
}
