import Foundation
import SwiftUI
import SwiftData
import PDFKit
#if canImport(MessageUI)
import MessageUI
#endif
#if canImport(AppKit)
import AppKit
#endif

struct InvoiceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @Bindable var invoice: Invoice
    @Bindable var viewModel: InvoiceViewModel

    @State private var showingAddItem = false
    @State private var showingEditInvoice = false
    @State private var showingShareSheet = false
    @State private var showingPDFSaveConfirmation = false
    @State private var emailDraft: EmailDraft?
    @State private var pdfURL: URL?
    @State private var savedPDFURL: URL?
    @State private var previewDocument: PDFDocument?
    @State private var templateViewModel: InvoiceTemplateViewModel?
    @State private var isPreviewLoading = false
    @State private var editingItem: InvoiceItem?
    @State private var previewNeedsRefresh = true
    @State private var composerSeed: InvoiceComposerSeed?
    @State private var duplicatedInvoice: Invoice?
    @State private var syncResultMessage: String?
    @State private var showingSyncResult = false
    #if canImport(UIKit)
    @State private var showingFullScreenPreview = false
    @State private var fullScreenDocument: PDFDocument?
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    invoiceInformationCard
                    clientInformationCard
                    itemsCard
                    if !invoice.notes.isEmpty {
                        notesCard
                    }
                    pdfPreviewCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Detalle factura")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                toolbarMenu
            }
            .navigationDestination(item: $duplicatedInvoice) { invoice in
                InvoiceDetailView(invoice: invoice, viewModel: viewModel)
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
            #if canImport(UIKit) && canImport(MessageUI)
            .sheet(item: $emailDraft) { draft in
                MailComposeView(draft: draft)
            }
            #endif
            #if canImport(UIKit)
            .fullScreenCover(isPresented: $showingFullScreenPreview) {
                if let document = fullScreenDocument {
                    NavigationStack {
                        PDFPreview(document: document)
                            .ignoresSafeArea()
                            .navigationTitle(String(localized: "Document Preview", comment: "Title for full-screen PDF preview"))
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button(String(localized: "Close", comment: "Dismiss full-screen PDF preview")) {
                                        showingFullScreenPreview = false
                                    }
                                }
                            }
                    }
                }
            }
            #endif
            .sheet(item: $editingItem) { item in
                InvoiceItemEditorView(invoice: invoice, viewModel: viewModel, item: item)
            }
            .sheet(item: $composerSeed) { seed in
                AddInvoiceView(viewModel: viewModel, seed: seed) { created in
                    duplicatedInvoice = created
                }
            }
        }
        .onAppear {
            if templateViewModel == nil {
                templateViewModel = InvoiceTemplateViewModel(modelContext: modelContext)
            }
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
            "Factura guardada",
            isPresented: $showingPDFSaveConfirmation,
            actions: {
                if savedPDFURL != nil {
                    Button("Compartir") { shareSavedPDF() }
                    #if canImport(AppKit)
                    Button("Mostrar en Finder") { revealPDFInFinder() }
                    #endif
                }
                Button("OK", role: .cancel) {}
            },
            message: {
                if let savedPDFURL {
                    #if os(macOS)
                    Text(
                        String(
                            format: "El PDF se guardo en %@.",
                            savedPDFURL.deletingLastPathComponent().path
                        )
                    )
                    #else
                    Text(
                        String(
                            format: "El PDF \"%@\" ya esta listo para compartir.",
                            savedPDFURL.lastPathComponent
                        )
                    )
                    #endif
                }
            }
        )
        .alert("Sincronizacion completada", isPresented: $showingSyncResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(syncResultMessage ?? "")
        }
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

            HStack(spacing: 12) {
                if invoice.status != .sent {
                    Button("Marcar enviada") {
                        viewModel.markSent(invoice)
                    }
                    .buttonStyle(.bordered)
                }

                if invoice.status != .paid {
                    Button("Marcar cobrada") {
                        viewModel.markPaid(invoice)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            HStack(spacing: 12) {
                infoCapsule(icon: "calendar.badge.clock", title: "Emitida", value: invoice.issueDate.mediumFormat)
                infoCapsule(icon: "calendar.badge.exclamationmark", title: "Vence", value: invoice.dueDate.mediumFormat)
            }
        }
        .padding(20)
        .materialCardStyle(cornerRadius: 16)
    }

    private var invoiceInformationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Datos de la factura")
                .font(.title2)
                .fontWeight(.semibold)

            infoRow(title: "Numero", value: invoice.invoiceNumber)
            if !invoice.issuerName.isEmpty {
                infoRow(title: "Emisor", value: invoice.issuerName)
            }
            if !invoice.issuerCode.isEmpty {
                infoRow(title: "Codigo emisor", value: invoice.issuerCode)
            }
            infoRow(title: "Fecha de emision", value: invoice.issueDate.mediumFormat)
            infoRow(title: "Fecha de vencimiento", value: invoice.dueDate.mediumFormat)
            if let updated = invoice.pdfLastGeneratedAt {
                infoRow(title: "PDF actualizado", value: formattedDate(updated))
            }
        }
        .padding(20)
        .cardStyle(cornerRadius: 16)
    }

    private var clientInformationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Cliente")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showingEditInvoice = true }) {
                    Label("Editar", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
            }

            infoRow(title: "Nombre", value: invoice.clientName)
            if !clientIdentificationNumber.isEmpty {
                infoRow(
                    title: "NIF/CIF",
                    value: clientIdentificationNumber
                )
            }
            if !invoice.clientEmail.isEmpty {
                infoRow(title: "Email", value: invoice.clientEmail)
            }
            if !invoice.clientAddress.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Direccion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(invoice.clientAddress)
                        .font(.body)
                }
            }
        }
        .padding(20)
        .cardStyle(cornerRadius: 16)
    }

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Conceptos")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showingAddItem = true }) {
                    Label("Anadir concepto", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            if (invoice.items ?? []).isEmpty {
                Text("Aun no hay conceptos. Anadelos para calcular los totales.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(invoice.items ?? []) { item in
                        itemCard(for: item)
                    }
                }
            }

            Divider()

            VStack(spacing: 8) {
                HStack {
                    Text("Subtotal")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(invoice.itemsSubtotal.formattedAsCurrency)
                }
                .font(.subheadline)

                HStack {
                    Text("IVA (\(invoice.ivaPercentage.formattedAsPercent))")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(invoice.ivaAmount.formattedAsCurrency)
                }
                .font(.subheadline)

                HStack {
                    Text("IRPF (\(invoice.irpfPercentage.formattedAsPercent))")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text((-invoice.irpfAmount).formattedAsCurrency)
                }
                .font(.subheadline)

                Divider()

                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    Text(invoice.totalAmount.formattedAsCurrency)
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
        }
        .padding(20)
        .cardStyle(cornerRadius: 16)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notas")
                .font(.title2)
                .fontWeight(.semibold)
            Text(invoice.notes)
                .font(.body)
        }
        .padding(20)
        .cardStyle(cornerRadius: 16)
    }

    private var pdfPreviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vista previa del PDF")
                .font(.title2)
                .fontWeight(.semibold)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.cardBackground)
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 2)

                if isPreviewLoading {
                    ProgressView("Generando vista previa…")
                } else if let previewDocument {
                    PDFPreview(document: previewDocument)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .onTapGesture { handlePreviewTap() }
                        .accessibilityAddTraits(.isButton)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.gearshape")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(previewNeedsRefresh ? "Pulsa en crear vista previa para renderizar la factura actual." : "La vista previa no esta disponible. Intentalo de nuevo.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button(action: { refreshPreview() }) {
                            Text("Crear vista previa")
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                }
            }
            .frame(height: 360)

            pdfActionButtons
        }
        .padding(20)
        .cardStyle(cornerRadius: 16)
    }

    @ViewBuilder
    private var pdfActionButtons: some View {
        if usesCompactPDFActionLayout {
            let columns = [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
            LazyVGrid(columns: columns, spacing: 12) {
                pdfPreviewButton
                pdfGenerateButton
                pdfSyncButton
                if savedPDFURL != nil {
                    pdfShareButton
                }
                pdfSendEmailButton
            }
        } else {
            HStack(spacing: 12) {
                pdfPreviewButton
                pdfGenerateButton
                pdfSyncButton
                if savedPDFURL != nil {
                    pdfShareButton
                }
                pdfSendEmailButton
            }
        }
    }

    private var usesCompactPDFActionLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    private var pdfPreviewButton: some View {
        Button(action: { refreshPreview() }) {
            actionLabel(title: "Vista previa", systemImage: "sparkles.rectangle.stack")
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)
    }

    private var pdfGenerateButton: some View {
        Button(action: { generatePDF() }) {
            actionLabel(title: "Generar PDF", systemImage: "doc.fill")
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }

    private var pdfSyncButton: some View {
        Button(action: { syncAndRegeneratePDF() }) {
            actionLabel(title: "Sincronizar y regenerar", systemImage: "arrow.triangle.2.circlepath.doc.on.clipboard")
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }

    private var pdfShareButton: some View {
        Button(action: { shareSavedPDF() }) {
            actionLabel(title: "Compartir PDF", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }

    private var pdfSendEmailButton: some View {
        Button(action: { sendInvoiceByEmail() }) {
            actionLabel(title: "Enviar email", systemImage: "envelope")
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }

    private func actionLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Components

    private var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button(action: { generatePDF() }) {
                    Label("Generar PDF", systemImage: "doc.fill")
                }
                Button(action: { syncAndRegeneratePDF() }) {
                    Label("Sincronizar y regenerar", systemImage: "arrow.triangle.2.circlepath.doc.on.clipboard")
                }
                if savedPDFURL != nil {
                    Button(action: { shareSavedPDF() }) {
                        Label("Compartir PDF", systemImage: "square.and.arrow.up")
                    }
                }
                Button(action: { sendInvoiceByEmail() }) {
                    Label("Enviar email", systemImage: "envelope")
                }
                Button(action: { composerSeed = .duplicate(invoice) }) {
                    Label("Duplicar este mes", systemImage: "plus.square.on.square")
                }
                Button(action: { saveTemplate() }) {
                    Label("Guardar como plantilla", systemImage: "doc.on.doc")
                }
                if invoice.status != .sent {
                    Button(action: { viewModel.markSent(invoice) }) {
                        Label("Marcar enviada", systemImage: "paperplane")
                    }
                }
                if invoice.status != .paid {
                    Button(action: { viewModel.markPaid(invoice) }) {
                        Label("Marcar cobrada", systemImage: "checkmark.circle")
                    }
                }
                Button(action: { showingEditInvoice = true }) {
                    Label("Editar factura", systemImage: "pencil")
                }
            } label: {
                Label("Mas", systemImage: "ellipsis.circle")
            }
        }
    }

    private var pdfStateChip: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(
                invoice.hasGeneratedPDF ? "PDF listo" : "Sin PDF",
                systemImage: invoice.hasGeneratedPDF ? "doc.richtext.fill" : "doc.badge.arrow.trianglebadge.exclamationmark"
            )
            .font(.subheadline.weight(.semibold))
            Text(pdfStateSubtitle)
                .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .foregroundStyle(invoice.hasGeneratedPDF ? .teal : .secondary)
        .materialCardStyle(cornerRadius: 12)
    }

    private var pdfStateSubtitle: String {
        if let date = invoice.pdfLastGeneratedAt {
            let formatter = RelativeDateTimeFormatter()
            return "Actualizado \(formatter.localizedString(for: date, relativeTo: Date()))"
        }
        return "Genera el PDF para compartirlo con el cliente."
    }

    private var clientIdentificationNumber: String {
        if !invoice.clientIdentificationNumber.isEmpty {
            return invoice.clientIdentificationNumber
        }
        return invoice.client?.identificationNumber ?? ""
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
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.cardBackground)
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
                    Label("Editar", systemImage: "slider.horizontal.3")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)

                Button(role: .destructive, action: { viewModel.removeItem(item, from: invoice) }) {
                    Label("Eliminar", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.cardBackground)
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
                "Factura_%@",
                comment: "Saved invoice PDF file name format"
            ),
            invoice.invoiceNumber
        )
    }

    // MARK: - Actions

    private func refreshPreview() {
        isPreviewLoading = true
        let document = PDFGeneratorService.generateInvoicePDF(invoice: invoice)
        previewDocument = document
        previewNeedsRefresh = document == nil
        isPreviewLoading = false
    }

    private func handlePreviewTap() {
        guard let previewDocument else { return }
        #if canImport(AppKit)
        openInPreviewApp(document: previewDocument)
        #else
        fullScreenDocument = previewDocument
        showingFullScreenPreview = true
        #endif
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

    #if canImport(AppKit)
    private func openInPreviewApp(document: PDFDocument) {
        if let url = savedPDFURL ?? persistTemporaryPDF(document: document) {
            NSWorkspace.shared.open(url)
        }
    }
    #endif

    private func persistTemporaryPDF(document: PDFDocument) -> URL? {
        guard let data = document.dataRepresentation() else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(pdfFileName)-preview-\(UUID().uuidString).pdf")
        do {
            try data.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            return nil
        }
    }

    @discardableResult
    private func generatePDF(showConfirmation: Bool = true) -> URL? {
        guard let pdfDocument = PDFGeneratorService.generateInvoicePDF(invoice: invoice),
              let url = PDFGeneratorService.savePDF(pdfDocument, fileName: pdfFileName) else {
            return nil
        }

        pdfURL = url
        savedPDFURL = url
        invoice.pdfLastGeneratedAt = Date()
        viewModel.updateInvoice(invoice)
        if showConfirmation {
            showingPDFSaveConfirmation = true
        }
        refreshPreview()
        return url
    }

    private func ensurePDFExists() -> URL? {
        if let savedPDFURL,
           FileManager.default.fileExists(atPath: savedPDFURL.path) {
            return savedPDFURL
        }

        return generatePDF(showConfirmation: false)
    }

    private func sendInvoiceByEmail() {
        guard let url = ensurePDFExists() else { return }
        let draft = EmailService.makeDraft(invoice: invoice, pdfURL: url)

        if invoice.status == .draft {
            viewModel.markSent(invoice)
        }

        #if canImport(UIKit) && canImport(MessageUI)
        if EmailService.canComposeOnIOS {
            emailDraft = draft
        } else {
            pdfURL = url
            showingShareSheet = true
        }
        #elseif canImport(AppKit)
        if !EmailService.composeOnMac(draft) {
            pdfURL = url
            showingShareSheet = true
        }
        #else
        pdfURL = url
        showingShareSheet = true
        #endif
    }

    private func shareSavedPDF() {
        guard let url = savedPDFURL else { return }
        pdfURL = url
        showingShareSheet = true
    }

    private func syncAndRegeneratePDF() {
        let result = viewModel.syncLinkedData(into: invoice)
        syncResultMessage = result.message
        showingSyncResult = true
        _ = generatePDF(showConfirmation: false)
    }

    private func saveTemplate() {
        guard let templateViewModel else { return }
        _ = templateViewModel.createTemplate(from: invoice)
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

#if canImport(UIKit) && canImport(MessageUI)
private struct MailComposeView: UIViewControllerRepresentable {
    let draft: EmailDraft

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(draft.recipients)
        controller.setSubject(draft.subject)
        controller.setMessageBody(draft.body, isHTML: false)
        if let data = try? Data(contentsOf: draft.attachmentURL) {
            controller.addAttachmentData(data, mimeType: "application/pdf", fileName: draft.attachmentURL.lastPathComponent)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}
#endif

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
                Section("Concepto") {
                    TextField("Descripcion", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...4)
                    Stepper("Cantidad: \(quantity)", value: $quantity, in: 1...999)
                    TextField("Precio unitario", text: $unitPrice)
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
            .navigationTitle("Editar concepto")
    #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
    #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { saveChanges() }
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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self, Issuer.self, InvoiceTemplate.self, InvoiceTemplateItem.self,
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
