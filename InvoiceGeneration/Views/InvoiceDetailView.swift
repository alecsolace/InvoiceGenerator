import Foundation
import SwiftUI
import SwiftData
import PDFKit
#if canImport(AppKit)
import AppKit
#endif

/// Detailed view for a single invoice with modern, glass-inspired layout
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
    @State private var previewDocument: PDFDocument?
    @State private var isPreviewLoading = false
    @State private var editingItem: InvoiceItem?
    @State private var previewNeedsRefresh = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    invoiceInformationCard
                    clientInformationCard
                    itemsCard
                    if !invoice.notes.isEmpty {
                        notesCard
                    }
                    pdfPreviewCard
                }
                .padding(.horizontal)
                .padding(.vertical, 32)
            }
            .background(backgroundGradient)
            .navigationTitle("Invoice Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                toolbarMenu
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
            .sheet(item: $editingItem) { item in
                InvoiceItemEditorView(invoice: invoice, viewModel: viewModel, item: item)
            }
        }
        .onAppear {
            hydrateSavedPDFIfNeeded()
        }
        .onChange(of: invoice.updatedAt) { _, _ in
            previewDocument = nil
            previewNeedsRefresh = true
        }
        .onChange(of: invoice.pdfLastGeneratedAt) { _, _ in
            hydrateSavedPDFIfNeeded()
        }
        .alert(
            "Invoice Saved",
            isPresented: $showingPDFSaveConfirmation,
            actions: {
                if savedPDFURL != nil {
                    Button("Share") { shareSavedPDF() }
                    #if canImport(AppKit)
                    Button("Show in Finder") { revealPDFInFinder() }
                    #endif
                }
                Button("OK", role: .cancel) {}
            },
            message: {
                if let savedPDFURL {
                    #if os(macOS)
                    Text(
                        String(
                            format: NSLocalizedString(
                                "The PDF was saved to %@.",
                                comment: "Alert message when PDF is saved locally with full path"
                            ),
                            savedPDFURL.deletingLastPathComponent().path
                        )
                    )
                    #else
                    Text(
                        String(
                            format: NSLocalizedString(
                                "The PDF \"%@\" is stored securely inside the app. Share it from here whenever you need.",
                                comment: "Alert message when PDF stored inside the app sandbox"
                            ),
                            savedPDFURL.lastPathComponent
                        )
                    )
                    #endif
                }
            }
        )
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(invoice.invoiceNumber)
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                    Text(invoice.clientName)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                pdfStateChip
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 16) {
                Text(invoice.totalAmount.formattedAsCurrency)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Spacer()
                statusPicker
            }
            
            HStack(spacing: 16) {
                infoCapsule(icon: "calendar.badge.clock", title: "Issued", value: invoice.issueDate.mediumFormat)
                infoCapsule(icon: "calendar.badge.exclamationmark", title: "Due", value: invoice.dueDate.mediumFormat)
            }
        }
        .padding(24)
        .glassBackground()
    }
    
    private var invoiceInformationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invoice Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            infoRow(title: "Invoice Number", value: invoice.invoiceNumber)
            infoRow(title: "Issue Date", value: invoice.issueDate.mediumFormat)
            infoRow(title: "Due Date", value: invoice.dueDate.mediumFormat)
            if let updated = invoice.pdfLastGeneratedAt {
                infoRow(title: "PDF Updated", value: formattedDate(updated))
            }
        }
        .padding(24)
        .glassBackground()
    }
    
    private var clientInformationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Client")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showingEditInvoice = true }) {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
            }
            
            infoRow(title: "Name", value: invoice.clientName)
            if !invoice.clientEmail.isEmpty {
                infoRow(title: "Email", value: invoice.clientEmail)
            }
            if !invoice.clientAddress.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Address")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(invoice.clientAddress)
                        .font(.body)
                }
            }
        }
        .padding(24)
        .glassBackground()
    }
    
    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Items")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showingAddItem = true }) {
                    Label("Add Item", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            
            if invoice.items.isEmpty {
                Text("No items yet. Add services or products to calculate totals.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(invoice.items) { item in
                        itemCard(for: item)
                    }
                }
            }
            
            Divider()
                .tint(.white.opacity(0.4))
            
            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text(invoice.totalAmount.formattedAsCurrency)
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
        .padding(24)
        .glassBackground()
    }
    
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.title2)
                .fontWeight(.semibold)
            Text(invoice.notes)
                .font(.body)
        }
        .padding(24)
        .glassBackground()
    }
    
    private var pdfPreviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Document Preview")
                .font(.title2)
                .fontWeight(.semibold)
            
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.thickMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                if isPreviewLoading {
                    ProgressView("Rendering preview…")
                } else if let previewDocument {
                    PDFPreview(document: previewDocument)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.gearshape")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(previewNeedsRefresh ? "Tap \"Create Preview\" to render the latest invoice." : "Preview unavailable. Try rendering again.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button(action: { refreshPreview() }) {
                            Text("Create Preview")
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                }
            }
            .frame(height: 360)
            
            HStack {
                Button(action: { refreshPreview() }) {
                    Label("Create Preview", systemImage: "sparkles.rectangle.stack")
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: { generatePDF() }) {
                    Label("Generate PDF", systemImage: "doc.fill")
                }
                .buttonStyle(.bordered)
                
                if savedPDFURL != nil {
                    Button(action: { shareSavedPDF() }) {
                        Label("Share Saved PDF", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .padding(24)
        .glassBackground()
    }
    
    // MARK: - Components
    
    private var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
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
                    Label("Edit Invoice", systemImage: "pencil")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.indigo.opacity(0.18),
                Color.teal.opacity(0.12),
                {
                    #if canImport(UIKit)
                    return Color(.systemBackground)
                    #elseif canImport(AppKit)
                    return Color(NSColor.windowBackgroundColor)
                    #else
                    return Color.white
                    #endif
                }()
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var pdfStateChip: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(
                invoice.hasGeneratedPDF ? "PDF Ready" : "PDF Missing",
                systemImage: invoice.hasGeneratedPDF ? "doc.richtext.fill" : "doc.badge.arrow.trianglebadge.exclamationmark"
            )
            .font(.subheadline.weight(.semibold))
            Text(pdfStateSubtitle)
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .foregroundStyle(invoice.hasGeneratedPDF ? .teal : .secondary)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(invoice.hasGeneratedPDF ? Color.teal.opacity(0.3) : Color.gray.opacity(0.25), lineWidth: 1)
        )
    }
    
    private var pdfStateSubtitle: String {
        if let date = invoice.pdfLastGeneratedAt {
            let formatter = RelativeDateTimeFormatter()
            return String(
                format: NSLocalizedString("Updated %@", comment: "Relative text for PDF timestamp"),
                formatter.localizedString(for: date, relativeTo: Date())
            )
        }
        return NSLocalizedString("Generate a PDF to keep clients in sync.", comment: "Default PDF state subtitle")
    }
    
    private var statusPicker: some View {
        Menu {
            ForEach(InvoiceStatus.allCases, id: \.self) { status in
                Button(status.localizedTitle) {
                    viewModel.updateStatus(invoice, status: status)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(invoice.status.localizedTitle)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(statusColor.opacity(0.15), in: Capsule())
            .foregroundStyle(statusColor)
        }
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
    
    private func infoCapsule(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func itemCard(for item: InvoiceItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.itemDescription)
                    .font(.headline)
                Spacer()
                Text(item.total.formattedAsCurrency)
                    .font(.headline)
            }
            Text("\(item.quantity) × \(item.unitPrice.formattedAsCurrency)")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button(action: { editingItem = item }) {
                    Label("Edit", systemImage: "slider.horizontal.3")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                
                Button(role: .destructive, action: { viewModel.removeItem(item, from: invoice) }) {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thinMaterial)
        )
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
    
    private var pdfFileName: String {
        String(
            format: NSLocalizedString(
                "Invoice_%@",
                comment: "Saved invoice PDF file name format"
            ),
            invoice.invoiceNumber
        )
    }
    
    // MARK: - Actions
    
    private func refreshPreview() {
        isPreviewLoading = true
        let descriptor = FetchDescriptor<CompanyProfile>()
        let profile = (try? modelContext.fetch(descriptor))?.first
        let document = PDFGeneratorService.generateInvoicePDF(
            invoice: invoice,
            companyProfile: profile
        )
        previewDocument = document
        previewNeedsRefresh = document == nil
        isPreviewLoading = false
    }
    
    private func hydrateSavedPDFIfNeeded() {
        guard invoice.hasGeneratedPDF else {
            savedPDFURL = nil
            previewDocument = nil
            previewNeedsRefresh = true
            return
        }
        if let url = PDFStorageManager.targetURL(for: pdfFileName),
           FileManager.default.fileExists(atPath: url.path) {
            savedPDFURL = url
            previewDocument = PDFDocument(url: url)
            previewNeedsRefresh = false
        } else {
            previewDocument = nil
            previewNeedsRefresh = true
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
            if let url = PDFGeneratorService.savePDF(pdfDocument, fileName: pdfFileName) {
                pdfURL = url
                savedPDFURL = url
                invoice.pdfLastGeneratedAt = Date()
                viewModel.updateInvoice(invoice)
                showingPDFSaveConfirmation = true
                refreshPreview()
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

// MARK: - Supporting Views

private struct PDFPreview: View {
    let document: PDFDocument
    
    var body: some View {
        #if canImport(UIKit)
        PDFKitView(document: document)
        #elseif canImport(AppKit)
        PDFKitNSView(document: document)
        #else
        EmptyView()
        #endif
    }
}

#if canImport(UIKit)
private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayDirection = .vertical
        view.displayMode = .singlePageContinuous
        view.document = document
        return view
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
#elseif canImport(AppKit)
private struct PDFKitNSView: NSViewRepresentable {
    let document: PDFDocument
    
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayDirection = .vertical
        view.displayMode = .singlePageContinuous
        view.document = document
        return view
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = document
    }
}
#endif

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

/// Inline editor for existing invoice items
struct InvoiceItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    let invoice: Invoice
    @Bindable var viewModel: InvoiceViewModel
    let item: InvoiceItem
    
    @State private var descriptionText: String
    @State private var quantity: Int
    @State private var unitPrice: String
    
    init(invoice: Invoice, viewModel: InvoiceViewModel, item: InvoiceItem) {
        self.invoice = invoice
        self.viewModel = viewModel
        self.item = item
        _descriptionText = State(initialValue: item.itemDescription)
        _quantity = State(initialValue: item.quantity)
        _unitPrice = State(initialValue: NSDecimalNumber(decimal: item.unitPrice).stringValue)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
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
            .navigationTitle("Edit Item")
    #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
    #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !descriptionText.isEmpty && Decimal(string: unitPrice) != nil
    }
    
    private func saveChanges() {
        guard let price = Decimal(string: unitPrice) else { return }
        viewModel.updateItem(
            item,
            from: invoice,
            description: descriptionText,
            quantity: quantity,
            unitPrice: price
        )
        dismiss()
    }
}

// MARK: - Styling Helpers

private extension View {
    func glassBackground(cornerRadius: CGFloat = 32) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
    }
}

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
