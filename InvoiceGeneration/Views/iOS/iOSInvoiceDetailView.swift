import Foundation
import PDFKit
import SwiftData
import SwiftUI
#if canImport(MessageUI)
import MessageUI
#endif

/// iPhone-specific invoice detail view with Stitch-design layout.
struct iOSInvoiceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var invoice: Invoice
    @Bindable var viewModel: InvoiceViewModel

    @State private var showingShareSheet = false
    @State private var showingEditInvoice = false
    @State private var composerSeed: InvoiceComposerSeed?
    @State private var duplicatedInvoice: Invoice?
    @State private var pdfURL: URL?
    @State private var templateViewModel: InvoiceTemplateViewModel?
    @State private var syncResultMessage: String?
    @State private var showingSyncResult = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statusSection
                clientInfoCard
                issuerInfoCard
                itemsCard
                taxSummaryCard
                if invoice.verifactuRecord != nil {
                    verifactuCard
                }
                if !invoice.notes.isEmpty {
                    notesCard
                }
                actionButtons
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(invoice.invoiceNumber)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditInvoice = true
                    } label: {
                        Label(String(localized: "Editar"), systemImage: "pencil")
                    }
                    Button {
                        composerSeed = .duplicate(invoice)
                    } label: {
                        Label(String(localized: "Duplicar"), systemImage: "plus.square.on.square")
                    }
                    if let templateViewModel {
                        Button {
                            templateViewModel.createTemplate(from: invoice)
                        } label: {
                            Label(String(localized: "Guardar plantilla"), systemImage: "doc.on.doc")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .navigationDestination(item: $duplicatedInvoice) { dup in
            iOSInvoiceDetailView(invoice: dup, viewModel: viewModel)
        }
        .sheet(isPresented: $showingEditInvoice) {
            EditInvoiceView(invoice: invoice, viewModel: viewModel)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let pdfURL {
                ShareSheet(items: [pdfURL])
            }
        }
        .sheet(item: $composerSeed) { seed in
            AddInvoiceView(viewModel: viewModel, seed: seed) { created in
                duplicatedInvoice = created
            }
        }
        // Email compose uses the shared InvoiceDetailView flow
        .onAppear {
            if templateViewModel == nil {
                templateViewModel = InvoiceTemplateViewModel(modelContext: modelContext)
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 10) {
            StatusBadge(status: invoice.status)
                .scaleEffect(1.2)

            HStack(spacing: 20) {
                Label(invoice.issueDate.mediumFormat, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(String(localized: "Vence \(invoice.dueDate.mediumFormat)"), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(invoice.status == .overdue ? .red : .secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .cardStyle(cornerRadius: 14)
    }

    // MARK: - Client Info

    private var clientInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(String(localized: "Cliente"))

            Text(invoice.clientName)
                .font(.headline)

            if !invoice.clientIdentificationNumber.isEmpty {
                HStack(spacing: 6) {
                    Text("NIF/CIF")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    Text(invoice.clientIdentificationNumber)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }

            if !invoice.clientEmail.isEmpty {
                Label(invoice.clientEmail, systemImage: "envelope")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !invoice.clientAddress.isEmpty {
                Label(invoice.clientAddress, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 12)
    }

    // MARK: - Issuer Info

    private var issuerInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(String(localized: "Emisor"))

            Text(invoice.issuerName)
                .font(.subheadline)
                .fontWeight(.medium)

            if !invoice.issuerTaxId.isEmpty {
                Text("CIF: \(invoice.issuerTaxId)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !invoice.issuerAddress.isEmpty {
                Text(invoice.issuerAddress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.cardBackground.opacity(0.7))
        )
    }

    // MARK: - Line Items

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(String(localized: "Conceptos"))

            if let items = invoice.items, !items.isEmpty {
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.itemDescription)
                                .font(.subheadline)
                            Text("\(item.quantity) x \(item.unitPrice.formattedAsCurrency)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.total.formattedAsCurrency)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            } else {
                Text(String(localized: "Sin conceptos"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 12)
    }

    // MARK: - Tax Summary

    private var taxSummaryCard: some View {
        VStack(spacing: 12) {
            sectionHeader(String(localized: "Resumen fiscal"))

            taxRow(String(localized: "Base imponible"), value: invoice.itemsSubtotal)

            if invoice.ivaPercentage > 0 || invoice.usesMultiRateIVA {
                taxRow("IVA (\(invoice.ivaPercentage.formattedAsPercent))", value: invoice.ivaAmount)
            }

            if invoice.surchargeAmount > 0 {
                taxRow(String(localized: "Recargo equiv."), value: invoice.surchargeAmount)
            }

            if invoice.irpfPercentage > 0 {
                taxRow("IRPF (-\(invoice.irpfPercentage.formattedAsPercent))", value: -invoice.irpfAmount, color: .red)
            }

            Divider()

            HStack {
                Text(String(localized: "Total"))
                    .font(.headline)
                Spacer()
                Text(invoice.totalAmount.formattedAsCurrency)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .prominentCardStyle(cornerRadius: 14)
    }

    private func taxRow(_ label: String, value: Decimal, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.formattedAsCurrency)
                .font(.subheadline)
                .foregroundStyle(color)
        }
    }

    // MARK: - VeriFACTU

    private var verifactuCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(String(localized: "VeriFactu"), systemImage: "checkmark.seal.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.green)

            if let record = invoice.verifactuRecord {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.secondary)
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: "qrcode")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hash: \(String(record.recordHash.prefix(20)))…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospaced()

                        Text("Seq: #\(record.sequenceNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(record.submissionStatus.rawValue.capitalized)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 12)
    }

    // MARK: - Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(String(localized: "Notas"))
            Text(invoice.notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if invoice.status == .sent || invoice.status == .overdue {
                Button {
                    viewModel.markPaid(invoice)
                } label: {
                    Label(String(localized: "Marcar como pagada"), systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
            } else if invoice.status == .draft {
                Button {
                    viewModel.markSent(invoice)
                } label: {
                    Label(String(localized: "Marcar como enviada"), systemImage: "paperplane.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Button {
                sharePDF()
            } label: {
                Label(String(localized: "Compartir PDF"), systemImage: "square.and.arrow.up")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                composerSeed = .duplicate(invoice)
            } label: {
                Label(String(localized: "Duplicar factura"), systemImage: "plus.square.on.square")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button(role: .destructive) {
                viewModel.deleteInvoice(invoice)
                dismiss()
            } label: {
                Label(String(localized: "Eliminar"), systemImage: "trash")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func sharePDF() {
        let fileName = "Factura_\(invoice.invoiceNumber)"
        if let url = PDFStorageManager.targetURL(for: fileName),
           FileManager.default.fileExists(atPath: url.path) {
            pdfURL = url
            showingShareSheet = true
            return
        }
        guard let doc = PDFGeneratorService.generateInvoicePDF(invoice: invoice) else { return }
        if let url = PDFGeneratorService.savePDF(doc, fileName: fileName) {
            pdfURL = url
            showingShareSheet = true
        }
    }
}

// Preview requires a managed Invoice — use the app's PersistenceController.preview container.
