import Foundation
import SwiftData
import SwiftUI
#if os(iOS)
import PhotosUI
#endif

struct AddInvoiceView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage(IssuerSelectionStore.appStorageKey) private var selectedIssuerStorage = IssuerSelectionStore.allIssuersToken
    @AppStorage(InvoiceFlowPreferences.defaultDueDaysKey) private var appDefaultDueDays = InvoiceFlowPreferences.defaultDueDays
    @AppStorage(InvoiceFlowPreferences.afterSaveActionKey) private var afterSaveActionRaw = InvoiceFlowPreferences.defaultAfterSaveAction

    let viewModel: InvoiceViewModel
    let seed: InvoiceComposerSeed
    let onComplete: ((Invoice) -> Void)?

    @State private var clientViewModel: ClientViewModel?
    @State private var issuerViewModel: IssuerViewModel?
    @State private var templateViewModel: InvoiceTemplateViewModel?

    @State private var creationMode: InvoiceCreationMode = .quick
    @State private var quickStep: QuickInvoiceStep = .base
    @State private var hasAppliedSeed = false
    @State private var showingAddClient = false
    @State private var showingPaywall = false
    @State private var showingShareSheet = false

    @State private var selectedTemplateID: UUID?
    @State private var selectedClientID: UUID?
    @State private var selectedIssuerID: UUID?

    @State private var invoiceNumber = ""
    @State private var clientName = ""
    @State private var clientEmail = ""
    @State private var clientAddress = ""
    @State private var clientIdentificationNumber = ""
    @State private var issueDate = Date()
    @State private var dueDate = Date().addingDays(InvoiceFlowPreferences.defaultDueDays)
    @State private var dueDays = InvoiceFlowPreferences.defaultDueDays
    @State private var ivaPercentage = "0"
    @State private var irpfPercentage = "0"
    @State private var notes = ""
    @State private var draftItems: [DraftInvoiceItem] = []
    @State private var showingAddItem = false
    @State private var editingDraftItem: DraftInvoiceItem?
    @State private var hasManuallyEditedInvoiceNumber = false
    @State private var lastSuggestedInvoiceNumber = ""
    @State private var pendingInvoiceSequenceByIssuerID: [UUID: Int] = [:]
    @State private var generatedPDFURL: URL?
    @State private var invoicePendingShareCompletion: Invoice?
    @State private var importWarnings: [String] = []
    @State private var importErrorMessage: String?
    @State private var importEngineDescription = AppleIntelligenceAvailability.importEngineDescription
    @State private var importConfidence: Double?
    @State private var isImportingDraft = false
    @State private var hasConsumedPendingSharedImport = false
    @State private var pendingImportedOverrides: ImportedInvoiceDraft?
#if os(iOS)
    @State private var selectedPhotoImportItem: PhotosPickerItem?
#endif

    init(
        viewModel: InvoiceViewModel,
        seed: InvoiceComposerSeed = .quick,
        onComplete: ((Invoice) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.seed = seed
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            Form {
                modePickerSection
                importSection

                if creationMode == .quick {
                    quickStepSection
                    if quickStep == .base {
                        quickBaseSection
                    } else {
                        quickAmountsSection
                    }
                } else {
                    advancedSections
                }
            }
            .navigationTitle(seedTitle)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(primaryActionTitle) {
                        handlePrimaryAction()
                    }
                    .disabled(primaryActionDisabled)
                    .accessibilityIdentifier("invoice-composer-primary")
                }
            }
            .sheet(isPresented: $showingAddClient) {
                if let clientViewModel {
                    AddClientView(viewModel: clientViewModel) { client in
                        selectedClientID = client.id
                        applyClientDefaults(from: client)
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                InvoiceDraftItemEditor(mode: .add) { draft in
                    draftItems.append(draft)
                }
            }
            .sheet(item: $editingDraftItem) { item in
                InvoiceDraftItemEditor(mode: .edit(item)) { updated in
                    if let index = draftItems.firstIndex(where: { $0.id == updated.id }) {
                        draftItems[index] = updated
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(reason: .clientLimit)
                    .environmentObject(subscriptionService)
            }
            .sheet(
                isPresented: $showingShareSheet,
                onDismiss: finalizePendingShareCompletion
            ) {
                if let generatedPDFURL {
                    ShareSheet(items: [generatedPDFURL])
                }
            }
        }
        .onAppear {
            prepareViewModelsIfNeeded()
            seedDefaultIssuerIfNeeded()
            applySeedIfNeeded()
            consumePendingSharedImportIfNeeded()
        }
        .onChange(of: selectedClientID) { _, newValue in
            guard let client = clientViewModel?.client(with: newValue) else { return }
            applyClientDefaults(from: client)

            if let preferredTemplateID = client.preferredTemplateID,
               selectedTemplateID != preferredTemplateID {
                selectedTemplateID = preferredTemplateID
            }

            reapplyPendingImportedDraftIfNeeded()
        }
        .onChange(of: selectedTemplateID) { _, newValue in
            guard let newValue,
                  let template = templateViewModel?.templates.first(where: { $0.id == newValue }) else { return }
            applyTemplateDefaults(from: template)
            reapplyPendingImportedDraftIfNeeded()
        }
        .onChange(of: selectedIssuerID) { _, newValue in
            selectedIssuerStorage = IssuerSelectionStore.storageValue(from: newValue)
            applySuggestedInvoiceNumber(force: false)
        }
        .onChange(of: issueDate) { _, newValue in
            dueDate = newValue.addingDays(max(dueDays, 0))
        }
        .onChange(of: dueDays) { _, newValue in
            dueDate = issueDate.addingDays(max(newValue, 0))
        }
        .onChange(of: invoiceNumber) { _, newValue in
            if newValue != lastSuggestedInvoiceNumber {
                hasManuallyEditedInvoiceNumber = true
            }
        }
#if os(iOS)
        .onChange(of: selectedPhotoImportItem) { _, newValue in
            guard let newValue else { return }

            Task {
                await importFromPhotoLibrary(newValue)
            }
        }
#endif
    }

    private var modePickerSection: some View {
        Section {
            Picker("Modo", selection: $creationMode) {
                ForEach(InvoiceCreationMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("invoice-composer-mode")
        }
    }

    private var quickStepSection: some View {
        Section {
            Picker("Paso", selection: $quickStep) {
                ForEach(QuickInvoiceStep.allCases) { step in
                    Text(step.title).tag(step)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var importSection: some View {
        Section("Importar captura") {
#if os(iOS)
            PhotosPicker(selection: $selectedPhotoImportItem, matching: .images) {
                Label("Importar desde imagen", systemImage: "photo.badge.plus")
            }
            .accessibilityIdentifier("invoice-import-photo")
#else
            Text("La importacion desde imagen esta disponible en iOS.")
                .foregroundStyle(.secondary)
#endif

            Text("Motor activo: \(importEngineDescription)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if isImportingDraft {
                ProgressView("Analizando captura…")
            }

            if let importConfidence {
                LabeledContent("Confianza", value: "\(Int(importConfidence * 100))%")
            }

            ForEach(importWarnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if let importErrorMessage {
                Label(importErrorMessage, systemImage: "xmark.octagon")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if SharedImageImportStore.hasPendingImport {
                Text("Hay una captura compartida pendiente. Se aplicara automaticamente al abrir este editor.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quickBaseSection: some View {
        Group {
            Section("Base mensual") {
                if let templates = templateViewModel?.templates, !templates.isEmpty {
                    Picker("Plantilla", selection: $selectedTemplateID) {
                        Text("Sin plantilla")
                            .tag(UUID?.none)

                        ForEach(templates) { template in
                            Text(template.name)
                                .tag(Optional(template.id))
                        }
                    }
                    .accessibilityIdentifier("invoice-template-picker")
                }

                if let clients = clientViewModel?.clients, !clients.isEmpty {
                    Picker("Cliente", selection: $selectedClientID) {
                        Text("Selecciona cliente")
                            .tag(UUID?.none)

                        ForEach(clients) { client in
                            Text(client.name)
                                .tag(Optional(client.id))
                        }
                    }
                    .accessibilityIdentifier("invoice-client-picker")
                } else {
                    Text("Aun no tienes clientes guardados.")
                        .foregroundStyle(.secondary)
                }

                Button {
                    handleAddClientTap()
                } label: {
                    Label("Crear cliente", systemImage: "plus")
                }

                if let currentIssuer {
                    LabeledContent("Emisor", value: "\(currentIssuer.name) (\(currentIssuer.code))")
                } else {
                    Text("Necesitas crear un emisor antes de facturar.")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Numero previsto", value: invoiceNumber.isEmpty ? "Sin numeracion" : invoiceNumber)

                Button("Usar siguiente numero") {
                    incrementSuggestedInvoiceNumber()
                }
                .disabled(currentIssuer == nil)

                DatePicker("Fecha de emision", selection: $issueDate, displayedComponents: .date)

                Stepper("Vencimiento: \(dueDays) dias", value: $dueDays, in: 0...120)

                LabeledContent("Fecha de vencimiento", value: dueDate.mediumFormat)
            }

            Section("Cliente") {
                LabeledContent("Nombre", value: clientName.isEmpty ? "Pendiente" : clientName)
                if !clientIdentificationNumber.isEmpty {
                    LabeledContent("NIF/CIF", value: clientIdentificationNumber)
                }
                if !clientEmail.isEmpty {
                    LabeledContent("Email", value: clientEmail)
                }
            }
        }
    }

    private var quickAmountsSection: some View {
        Group {
            itemsSection
            taxesSection
            notesSection
        }
    }

    @ViewBuilder
    private var advancedSections: some View {
        InvoiceEditorSections(
            issuers: issuerViewModel?.issuers ?? [],
            clients: clientViewModel?.clients ?? [],
            selectedIssuerID: $selectedIssuerID,
            selectedClientID: $selectedClientID,
            invoiceNumber: $invoiceNumber,
            clientName: $clientName,
            clientEmail: $clientEmail,
            clientIdentificationNumber: $clientIdentificationNumber,
            clientAddress: $clientAddress,
            issueDate: $issueDate,
            dueDate: $dueDate,
            ivaPercentage: $ivaPercentage,
            irpfPercentage: $irpfPercentage,
            notes: $notes,
            draftItems: $draftItems,
            showingAddItem: $showingAddItem,
            editingDraftItem: $editingDraftItem,
            onAddClient: handleAddClientTap,
            onUseNextInvoiceNumber: incrementSuggestedInvoiceNumber,
            onRemoveDraftItem: removeDraftItem
        )
    }

    private var itemsSection: some View {
        Section("Importes") {
            if draftItems.isEmpty {
                Text("Anade los conceptos para calcular total, IVA e IRPF desde el principio.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(draftItems) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.description)
                                .font(.headline)
                            Spacer()
                            Text(item.total.formattedAsCurrency)
                                .font(.headline)
                        }

                        Text("\(item.quantity) x \(item.unitPrice.formattedAsCurrency)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button(action: { editingDraftItem = item }) {
                                Label("Editar", systemImage: "slider.horizontal.3")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive, action: { removeDraftItem(item) }) {
                                Label("Eliminar", systemImage: "trash")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Button {
                showingAddItem = true
            } label: {
                Label("Anadir concepto", systemImage: "plus.circle")
            }
            .accessibilityIdentifier("invoice-add-item")
        }
    }

    private var taxesSection: some View {
        Section("Totales") {
            TextField("IVA %", text: $ivaPercentage)
#if os(iOS)
                .keyboardType(.decimalPad)
#endif

            TextField("IRPF %", text: $irpfPercentage)
#if os(iOS)
                .keyboardType(.decimalPad)
#endif

            LabeledContent("Subtotal", value: itemsTotal.formattedAsCurrency)
            LabeledContent("IVA (\(ivaPercentageValue.formattedAsPercent))", value: ivaAmount.formattedAsCurrency)
            LabeledContent("IRPF (\(irpfPercentageValue.formattedAsPercent))", value: (-irpfAmount).formattedAsCurrency)
            LabeledContent("Total", value: invoiceTotal.formattedAsCurrency)
        }
    }

    private var notesSection: some View {
        Section("Notas") {
            TextField("Notas para esta factura", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var seedTitle: String {
        switch seed {
        case .quick:
            return creationMode == .quick ? "Factura rapida" : "Nueva factura"
        case .client(let client):
            return "Facturar a \(client.name)"
        case .template(let template):
            return template.name
        case .duplicate:
            return "Duplicar factura"
        }
    }

    private var primaryActionTitle: String {
        if creationMode == .quick && quickStep == .base {
            return "Continuar"
        }
        return "Crear"
    }

    private var primaryActionDisabled: Bool {
        if creationMode == .quick && quickStep == .base {
            return clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || currentIssuer == nil
        }

        return clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || invoiceNumber.isEmpty || currentIssuer == nil
    }

    private var currentIssuer: Issuer? {
        guard let selectedIssuerID else { return issuerViewModel?.issuers.first }
        return issuerViewModel?.issuers.first(where: { $0.id == selectedIssuerID })
    }

    private var itemsTotal: Decimal {
        draftItems.reduce(0) { $0 + $1.total }
    }

    private var ivaPercentageValue: Decimal {
        Decimal(string: ivaPercentage) ?? 0
    }

    private var irpfPercentageValue: Decimal {
        Decimal(string: irpfPercentage) ?? 0
    }

    private var ivaAmount: Decimal {
        (itemsTotal * ivaPercentageValue) / Decimal(100)
    }

    private var irpfAmount: Decimal {
        (itemsTotal * irpfPercentageValue) / Decimal(100)
    }

    private var invoiceTotal: Decimal {
        itemsTotal + ivaAmount - irpfAmount
    }

    private var selectedAfterSaveAction: QuickInvoiceAfterSaveAction {
        QuickInvoiceAfterSaveAction(rawValue: afterSaveActionRaw) ?? .close
    }

    private func handlePrimaryAction() {
        if creationMode == .quick && quickStep == .base {
            quickStep = .amounts
            if invoiceNumber.isEmpty {
                applySuggestedInvoiceNumber(force: true)
            }
            return
        }

        createInvoice()
    }

    private func prepareViewModelsIfNeeded() {
        if clientViewModel == nil {
            clientViewModel = ClientViewModel(modelContext: modelContext)
        }

        if issuerViewModel == nil {
            issuerViewModel = IssuerViewModel(modelContext: modelContext)
        }

        if templateViewModel == nil {
            templateViewModel = InvoiceTemplateViewModel(modelContext: modelContext)
        }
    }

    private func consumePendingSharedImportIfNeeded() {
        guard !hasConsumedPendingSharedImport else { return }
        hasConsumedPendingSharedImport = true

        guard let imageData = SharedImageImportStore.consumePendingImageData() else { return }

        Task {
            await importImageData(imageData)
        }
    }

    private func seedDefaultIssuerIfNeeded() {
        let storedIssuerID = IssuerSelectionStore.issuerID(from: selectedIssuerStorage)
        if let storedIssuerID,
           issuerViewModel?.issuers.contains(where: { $0.id == storedIssuerID }) == true {
            selectedIssuerID = storedIssuerID
        } else {
            selectedIssuerID = issuerViewModel?.issuers.first?.id
        }

        applySuggestedInvoiceNumber(force: true)
    }

    private func applySeedIfNeeded() {
        guard !hasAppliedSeed else { return }
        hasAppliedSeed = true

        quickStep = seed.startsOnAmountsStep ? .amounts : .base

        switch seed {
        case .quick:
            creationMode = .quick
            dueDays = appDefaultDueDays
            dueDate = issueDate.addingDays(dueDays)
        case .client(let client):
            creationMode = .quick
            selectedClientID = client.id
            applyClientDefaults(from: client)
        case .template(let template):
            creationMode = .advanced
            selectedTemplateID = template.id
            applyTemplateDefaults(from: template)
        case .duplicate(let invoice):
            creationMode = .quick
            applyDuplicateDefaults(from: invoice)
        }
    }

    private func applyClientDefaults(from client: Client) {
        clientName = client.name
        clientEmail = client.email
        clientIdentificationNumber = client.identificationNumber
        clientAddress = client.address

        if let preferredTemplateID = client.preferredTemplateID,
           let template = templateViewModel?.templates.first(where: { $0.id == preferredTemplateID }) {
            if selectedTemplateID != preferredTemplateID {
                selectedTemplateID = preferredTemplateID
            }
            applyTemplateDefaults(from: template)
            return
        }

        dueDays = client.defaultDueDays > 0 ? client.defaultDueDays : appDefaultDueDays
        dueDate = issueDate.addingDays(dueDays)

        if let iva = client.defaultIVAPercentage {
            ivaPercentage = NSDecimalNumber(decimal: iva).stringValue
        }

        if let irpf = client.defaultIRPFPercentage {
            irpfPercentage = NSDecimalNumber(decimal: irpf).stringValue
        }

        if !client.defaultNotes.isEmpty {
            notes = client.defaultNotes
        }
    }

    private func applyTemplateDefaults(from template: InvoiceTemplate) {
        selectedTemplateID = template.id
        selectedClientID = template.client?.id
        selectedIssuerID = template.issuer?.id ?? selectedIssuerID

        clientName = template.client?.name ?? template.clientName
        clientEmail = template.client?.email ?? template.clientEmail
        clientIdentificationNumber = template.client?.identificationNumber ?? template.clientIdentificationNumber
        clientAddress = template.client?.address ?? template.clientAddress

        dueDays = template.dueDays > 0 ? template.dueDays : appDefaultDueDays
        dueDate = issueDate.addingDays(dueDays)
        ivaPercentage = NSDecimalNumber(decimal: template.ivaPercentage).stringValue
        irpfPercentage = NSDecimalNumber(decimal: template.irpfPercentage).stringValue
        notes = template.notes
        draftItems = template.items
            .sorted { $0.sortOrder < $1.sortOrder }
            .map {
                DraftInvoiceItem(
                    description: $0.itemDescription,
                    quantity: $0.quantity,
                    unitPrice: $0.unitPrice
                )
            }

        applySuggestedInvoiceNumber(force: true)
    }

    private func applyDuplicateDefaults(from invoice: Invoice) {
        selectedClientID = invoice.client?.id
        selectedIssuerID = invoice.issuer?.id ?? selectedIssuerID
        clientName = invoice.clientName
        clientEmail = invoice.clientEmail
        clientIdentificationNumber = invoice.clientIdentificationNumber
        clientAddress = invoice.clientAddress
        issueDate = invoice.issueDate.addingMonths(1)
        dueDays = max(Calendar.current.dateComponents([.day], from: invoice.issueDate, to: invoice.dueDate).day ?? appDefaultDueDays, 0)
        dueDate = issueDate.addingDays(dueDays)
        ivaPercentage = NSDecimalNumber(decimal: invoice.ivaPercentage).stringValue
        irpfPercentage = NSDecimalNumber(decimal: invoice.irpfPercentage).stringValue
        notes = invoice.notes
        draftItems = invoice.items.map {
            DraftInvoiceItem(
                description: $0.itemDescription,
                quantity: $0.quantity,
                unitPrice: $0.unitPrice
            )
        }
        applySuggestedInvoiceNumber(force: true)
    }

    private func handleAddClientTap() {
        let count = clientViewModel?.clients.count ?? 0
        if subscriptionService.canAddClient(currentCount: count) {
            showingAddClient = true
        } else {
            showingPaywall = true
        }
    }

    private func applySuggestedInvoiceNumber(force: Bool) {
        guard let issuer = currentIssuer else { return }
        let sequence = pendingInvoiceSequenceByIssuerID[issuer.id] ?? issuer.nextInvoiceSequence
        setSuggestedInvoiceNumber(
            for: issuer,
            sequence: max(sequence, 1),
            replacingCurrentValue: force || invoiceNumber.isEmpty || !hasManuallyEditedInvoiceNumber
        )
    }

    private func incrementSuggestedInvoiceNumber() {
        guard let issuer = currentIssuer else { return }
        let currentSequence = pendingInvoiceSequenceByIssuerID[issuer.id] ?? issuer.nextInvoiceSequence
        setSuggestedInvoiceNumber(for: issuer, sequence: max(currentSequence, 1) + 1, replacingCurrentValue: true)
    }

    private func setSuggestedInvoiceNumber(for issuer: Issuer, sequence: Int, replacingCurrentValue: Bool) {
        let suggestion = InvoiceNumberingService.invoiceNumber(for: issuer, sequence: sequence)
        pendingInvoiceSequenceByIssuerID[issuer.id] = sequence
        lastSuggestedInvoiceNumber = suggestion

        if replacingCurrentValue {
            invoiceNumber = suggestion
            hasManuallyEditedInvoiceNumber = false
        }
    }

    private func createInvoice() {
        guard let issuer = currentIssuer else { return }

        let selectedClient = clientViewModel?.client(with: selectedClientID)
        let preparedItems = draftItems.map {
            InvoiceLineItemInput(
                description: $0.description,
                quantity: $0.quantity,
                unitPrice: $0.unitPrice
            )
        }

        let createdInvoice = viewModel.createInvoice(
            invoiceNumber: invoiceNumber,
            issuer: issuer,
            clientName: clientName,
            clientEmail: clientEmail,
            clientIdentificationNumber: clientIdentificationNumber,
            clientAddress: clientAddress,
            client: selectedClient,
            issueDate: issueDate,
            dueDate: dueDate,
            notes: notes,
            ivaPercentage: ivaPercentageValue,
            irpfPercentage: irpfPercentageValue,
            items: preparedItems
        )

        guard let createdInvoice else { return }
        selectedIssuerStorage = IssuerSelectionStore.storageValue(from: issuer.id)
        handlePostSave(for: createdInvoice)
    }

    private func handlePostSave(for invoice: Invoice) {
        switch selectedAfterSaveAction {
        case .close:
            dismiss()
        case .openDetail:
            onComplete?(invoice)
            dismiss()
        case .generatePDF:
            guard let pdfDocument = PDFGeneratorService.generateInvoicePDF(invoice: invoice),
                  let url = PDFGeneratorService.savePDF(
                    pdfDocument,
                    fileName: "Factura_\(invoice.invoiceNumber)"
                  )
            else {
                onComplete?(invoice)
                dismiss()
                return
            }

            generatedPDFURL = url
            invoice.pdfLastGeneratedAt = Date()
            viewModel.updateInvoice(invoice)
            invoicePendingShareCompletion = invoice
            showingShareSheet = true
        }
    }

    private func finalizePendingShareCompletion() {
        if let invoicePendingShareCompletion {
            onComplete?(invoicePendingShareCompletion)
            self.invoicePendingShareCompletion = nil
        }
        dismiss()
    }

    private func removeDraftItem(_ item: DraftInvoiceItem) {
        draftItems.removeAll { $0.id == item.id }
    }

#if os(iOS)
    private func importFromPhotoLibrary(_ item: PhotosPickerItem) async {
        do {
            guard let imageData = try await item.loadTransferable(type: Data.self) else {
                importErrorMessage = "No se pudo cargar la imagen seleccionada."
                return
            }

            await importImageData(imageData)
        } catch {
            importErrorMessage = "La seleccion de imagen fallo: \(error.localizedDescription)"
        }
    }
#endif

    @MainActor
    private func importImageData(_ imageData: Data) async {
        isImportingDraft = true
        importErrorMessage = nil
        importWarnings = []

        do {
            let service = InvoiceImageImportService()
            let importedDraft = try await service.extractDraft(from: imageData)
            applyImportedDraft(importedDraft)
        } catch {
            importErrorMessage = error.localizedDescription
        }

        isImportingDraft = false
    }

    private func applyImportedDraft(_ draft: ImportedInvoiceDraft) {
        importWarnings = draft.warnings
        importConfidence = draft.confidence
        importEngineDescription = draft.engineDescription
        pendingImportedOverrides = draft

        if let importedClientName = draft.clientName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !importedClientName.isEmpty,
           let matchedClient = InvoiceImageImportService.exactClientMatch(
                for: importedClientName,
                in: clientViewModel?.clients ?? []
           ) {
            selectedClientID = matchedClient.id
            applyClientDefaults(from: matchedClient)
        } else {
            selectedClientID = nil
        }

        applyImportedOverrides(from: draft)
        reapplyPendingImportedDraftIfNeeded()
    }

    private func reapplyPendingImportedDraftIfNeeded() {
        guard let pendingImportedOverrides else { return }
        applyImportedOverrides(from: pendingImportedOverrides)
        self.pendingImportedOverrides = nil
    }

    private func applyImportedOverrides(from draft: ImportedInvoiceDraft) {
        if let importedClientName = draft.clientName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !importedClientName.isEmpty {
            clientName = importedClientName
        }

        if let importedIssueDate = draft.issueDate {
            issueDate = importedIssueDate
        }

        if let importedDueDate = draft.dueDate {
            dueDate = importedDueDate
        }

        if let ivaPercentage = draft.ivaPercentage {
            self.ivaPercentage = NSDecimalNumber(decimal: ivaPercentage).stringValue
        }

        if let irpfPercentage = draft.irpfPercentage {
            self.irpfPercentage = NSDecimalNumber(decimal: irpfPercentage).stringValue
        }

        if !draft.items.isEmpty {
            draftItems = draft.items.map {
                DraftInvoiceItem(
                    description: $0.description,
                    quantity: $0.quantity,
                    unitPrice: $0.unitPrice
                )
            }
        }
    }
}

private enum InvoiceCreationMode: String, CaseIterable, Identifiable {
    case quick
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick:
            return "Rapida"
        case .advanced:
            return "Avanzada"
        }
    }
}

private enum QuickInvoiceStep: String, CaseIterable, Identifiable {
    case base
    case amounts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .base:
            return "Base"
        case .amounts:
            return "Importes"
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Invoice.self,
        InvoiceItem.self,
        CompanyProfile.self,
        Client.self,
        Issuer.self,
        InvoiceTemplate.self,
        InvoiceTemplateItem.self,
        configurations: config
    )

    let issuer = Issuer(name: "Acme Studio", code: "ACM")
    let client = Client(name: "Cliente ejemplo", email: "facturacion@cliente.com", defaultDueDays: 15)
    container.mainContext.insert(issuer)
    container.mainContext.insert(client)

    let viewModel = InvoiceViewModel(modelContext: container.mainContext)

    return AddInvoiceView(viewModel: viewModel, seed: .client(client))
        .environmentObject(SubscriptionService())
        .modelContainer(container)
}
