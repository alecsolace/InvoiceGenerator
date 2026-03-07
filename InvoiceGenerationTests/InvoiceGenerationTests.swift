import Foundation
import PDFKit
import SwiftData
import Testing
@testable import InvoiceGeneration

struct InvoiceGenerationTests {

    @MainActor
    private func makeSubscriptionService(
        suiteName: String = UUID().uuidString,
        iCloudAvailability: ICloudAvailability = .temporarilyUnavailable
    ) -> SubscriptionService {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return try! SubscriptionService(
            defaults: defaults,
            storeConfiguration: .testing,
            iCloudAvailabilityProvider: { iCloudAvailability },
            startTasks: false
        )
    }

    private func makeBundle(info: [String: Any]) throws -> Bundle {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let bundleURL = rootURL.appendingPathComponent("StoreConfigurationTests.bundle", isDirectory: true)

        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        let plistURL = bundleURL.appendingPathComponent("Info.plist")
        let dictionary = info as NSDictionary
        let wrote = dictionary.write(to: plistURL, atomically: true)
        #expect(wrote)

        guard let bundle = Bundle(url: bundleURL) else {
            Issue.record("Failed to create bundle for StoreConfiguration tests")
            throw NSError(domain: "InvoiceGenerationTests", code: 1)
        }

        return bundle
    }

    @MainActor
    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    @Test func freePlanCapsClientsAtTwo() async throws {
        let service = makeSubscriptionService()

        #expect(service.canAddClient(currentCount: 0))
        #expect(service.canAddClient(currentCount: 1))
        #expect(!service.canAddClient(currentCount: service.freeClientLimit))
    }

    @MainActor
    @Test func syncStatusRequiresActiveEntitlement() async throws {
        let service = makeSubscriptionService(iCloudAvailability: .available)
        service.syncPreferred = true
        #expect(service.syncStatus == .lockedByPaywall)
        #expect(service.syncEnabled == false)

        #if DEBUG
        service.debugSetEntitlementStatus(.active)
        #expect(service.syncEnabled == true)
        #expect(service.syncStatus == .ready)
        #endif
    }

    @MainActor
    @Test func syncStatusPausesWhenICloudIsUnavailable() async throws {
        let service = makeSubscriptionService(iCloudAvailability: .noAccount)
        service.syncPreferred = true

        #if DEBUG
        service.debugSetEntitlementStatus(.active)
        service.debugSetICloudAvailability(.noAccount)
        #endif

        #expect(service.syncStatus == .pausedNoICloud)
        #expect(service.syncEnabled == false)
    }

    @MainActor
    @Test func syncPreferencePersistsWhenEntitlementExpires() async throws {
        let suiteName = UUID().uuidString
        let service = makeSubscriptionService(suiteName: suiteName, iCloudAvailability: .available)
        service.syncPreferred = true

        #if DEBUG
        service.debugSetEntitlementStatus(.active)
        service.debugSetICloudAvailability(.available)
        #expect(service.syncStatus == .ready)

        service.debugSetEntitlementStatus(.expired)
        #expect(service.syncStatus == .lockedByPaywall)
        #expect(service.syncPreferred == true)
        #endif

        let reloadedService = try! SubscriptionService(
            defaults: UserDefaults(suiteName: suiteName)!,
            storeConfiguration: .testing,
            iCloudAvailabilityProvider: { .available },
            startTasks: false
        )
        #expect(reloadedService.syncPreferred == true)
    }

    @Test func storeConfigurationLoadRequiresMonthlyProductID() throws {
        let bundle = try makeBundle(
            info: [
                StoreConfiguration.yearlyProductIDKey: "pro_yearly"
            ]
        )

        #expect(throws: StoreConfigurationError.missingValue(StoreConfiguration.monthlyProductIDKey)) {
            try StoreConfiguration.load(bundle: bundle)
        }
    }

    @Test func storeConfigurationLoadRequiresYearlyProductID() throws {
        let bundle = try makeBundle(
            info: [
                StoreConfiguration.monthlyProductIDKey: "pro_monthly"
            ]
        )

        #expect(throws: StoreConfigurationError.missingValue(StoreConfiguration.yearlyProductIDKey)) {
            try StoreConfiguration.load(bundle: bundle)
        }
    }

    @Test func storeConfigurationLoadRejectsWhitespaceProductIDs() throws {
        let bundle = try makeBundle(
            info: [
                StoreConfiguration.monthlyProductIDKey: "pro monthly",
                StoreConfiguration.yearlyProductIDKey: "pro_yearly"
            ]
        )

        #expect(throws: StoreConfigurationError.invalidProductIdentifier("pro monthly")) {
            try StoreConfiguration.load(bundle: bundle)
        }
    }

    @Test func storeConfigurationLoadReturnsValidatedConfiguration() throws {
        let bundle = try makeBundle(
            info: [
                StoreConfiguration.monthlyProductIDKey: "pro_monthly",
                StoreConfiguration.yearlyProductIDKey: "pro_yearly",
                StoreConfiguration.subscriptionGroupIDKey: "group.invoicegeneration.pro"
            ]
        )

        let configuration = try StoreConfiguration.load(bundle: bundle)

        #expect(configuration.monthlyProductID == "pro_monthly")
        #expect(configuration.yearlyProductID == "pro_yearly")
        #expect(configuration.subscriptionGroupID == "group.invoicegeneration.pro")
    }

    @MainActor
    @Test func issuerNumberingIncrementsSequence() async throws {
        let issuer = Issuer(name: "Family", code: "FAM")

        #expect(InvoiceNumberingService.nextInvoiceNumber(for: issuer) == "FAM-0001")

        InvoiceNumberingService.registerUsedInvoiceNumber("FAM-0001", for: issuer)
        #expect(issuer.nextInvoiceSequence == 2)
        #expect(InvoiceNumberingService.nextInvoiceNumber(for: issuer) == "FAM-0002")
    }

    @MainActor
    @Test func issuerManualOverrideBumpsSequenceWhenHigher() async throws {
        let issuer = Issuer(name: "Family", code: "FAM", nextInvoiceSequence: 2)

        InvoiceNumberingService.registerUsedInvoiceNumber("FAM-0150", for: issuer)

        #expect(issuer.nextInvoiceSequence == 151)
        #expect(InvoiceNumberingService.nextInvoiceNumber(for: issuer) == "FAM-0151")
    }

    @MainActor
    @Test func explicitInvoiceNumberSequenceFormatsPerIssuer() async throws {
        let issuer = Issuer(name: "Family", code: "FAM", nextInvoiceSequence: 8)

        #expect(InvoiceNumberingService.invoiceNumber(for: issuer, sequence: 8) == "FAM-0008")
        #expect(InvoiceNumberingService.invoiceNumber(for: issuer, sequence: 12) == "FAM-0012")
        #expect(InvoiceNumberingService.sequence(from: "FAM-0012", for: issuer) == 12)
    }

    @MainActor
    @Test func issuerMigrationCreatesDefaultAndLinksInvoices() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let profile = CompanyProfile(companyName: "Acme Family", email: "hello@acme.dev")
        context.insert(profile)

        let invoice = Invoice(invoiceNumber: "ACM-0007", clientName: "Client")
        context.insert(invoice)
        try context.save()

        IssuerMigrationService.runIfNeeded(modelContext: context)

        let issuers = try context.fetch(FetchDescriptor<Issuer>())
        let invoices = try context.fetch(FetchDescriptor<Invoice>())

        #expect(issuers.count == 1)
        #expect(invoices.count == 1)
        #expect(invoices[0].issuer != nil)
        #expect(!invoices[0].issuerName.isEmpty)
    }

    @MainActor
    @Test func issuerMigrationPersistsDefaultWithoutInvoices() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let profile = CompanyProfile(companyName: "No Invoices Co", email: "hola@example.com")
        context.insert(profile)
        try context.save()

        IssuerMigrationService.runIfNeeded(modelContext: context)

        let issuers = try context.fetch(FetchDescriptor<Issuer>())
        #expect(issuers.count == 1)
        #expect(issuers[0].name == "No Invoices Co")
    }

    @MainActor
    @Test func issuerDeleteBlockedWhenInvoicesExist() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let viewModel = IssuerViewModel(modelContext: context)

        guard let issuer = viewModel.createIssuer(name: "Main", code: "MNN") else {
            Issue.record("Failed to create issuer")
            return
        }

        let invoice = Invoice(invoiceNumber: "MNN-0001", clientName: "Client", issuer: issuer)
        invoice.captureIssuerSnapshot(from: issuer)
        context.insert(invoice)
        try context.save()
        viewModel.fetchIssuers()

        let deleted = viewModel.deleteIssuer(issuer)
        #expect(deleted == false)
    }

    @MainActor
    @Test func createInvoiceFromTemplateAppliesTemplateValues() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let issuer = Issuer(name: "Acme", code: "ACM")
        let client = Client(name: "Cliente", email: "hola@cliente.com", identificationNumber: "B12345678")
        let template = InvoiceTemplate(
            name: "Cliente mensual",
            client: client,
            issuer: issuer,
            dueDays: 15,
            ivaPercentage: 21,
            irpfPercentage: 15,
            notes: "Retainer mensual"
        )
        let templateItem = InvoiceTemplateItem(description: "Retainer", quantity: 1, unitPrice: 1200, sortOrder: 0)
        templateItem.template = template
        template.items.append(templateItem)

        context.insert(issuer)
        context.insert(client)
        context.insert(template)
        context.insert(templateItem)
        try context.save()

        let viewModel = InvoiceViewModel(modelContext: context)
        let targetMonth = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 1))!

        let created = viewModel.createInvoice(fromTemplate: template, month: targetMonth)

        #expect(created != nil)
        #expect(created?.clientName == "Cliente")
        #expect(created?.invoiceNumber == "ACM-0001")
        #expect(created?.items.count == 1)
        #expect(created?.ivaPercentage == 21)
        #expect(created?.irpfPercentage == 15)
        #expect(created?.notes == "Retainer mensual")
        #expect(created?.dueDate == targetMonth.startOfMonth.addingDays(15))
        #expect(created?.totalAmount == Decimal(1272))
    }

    @MainActor
    @Test func duplicateInvoiceForNextMonthAdvancesDatesAndNumbering() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let issuer = Issuer(name: "Acme", code: "ACM", nextInvoiceSequence: 2)
        let client = Client(name: "Cliente")
        let original = Invoice(
            invoiceNumber: "ACM-0001",
            clientName: client.name,
            client: client,
            issuer: issuer,
            issueDate: Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            dueDate: Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 21))!,
            ivaPercentage: 21,
            irpfPercentage: 15
        )
        original.captureIssuerSnapshot(from: issuer)
        let item = InvoiceItem(description: "Retainer", quantity: 1, unitPrice: 1000)
        item.invoice = original
        original.items.append(item)
        original.calculateTotal()

        context.insert(issuer)
        context.insert(client)
        context.insert(original)
        context.insert(item)
        try context.save()

        let viewModel = InvoiceViewModel(modelContext: context)
        let copy = viewModel.duplicateInvoiceForNextMonth(original)

        #expect(copy != nil)
        #expect(copy?.invoiceNumber == "ACM-0002")
        #expect(copy?.issueDate == original.issueDate.addingMonths(1))
        #expect(copy?.dueDate == original.issueDate.addingMonths(1).addingDays(15))
        #expect(copy?.items.count == 1)
        #expect(copy?.totalAmount == original.totalAmount)
    }

    @MainActor
    @Test func createTemplateFromInvoiceSetsPreferredTemplateOnClient() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let issuer = Issuer(name: "Acme", code: "ACM")
        let client = Client(name: "Cliente")
        let invoice = Invoice(
            invoiceNumber: "ACM-0001",
            clientName: "Cliente",
            client: client,
            issuer: issuer,
            notes: "Servicio mensual",
            ivaPercentage: 21,
            irpfPercentage: 15
        )
        invoice.captureIssuerSnapshot(from: issuer)
        let item = InvoiceItem(description: "Retainer", quantity: 1, unitPrice: 1000)
        item.invoice = invoice
        invoice.items.append(item)
        invoice.calculateTotal()

        context.insert(issuer)
        context.insert(client)
        context.insert(invoice)
        context.insert(item)
        try context.save()

        let viewModel = InvoiceTemplateViewModel(modelContext: context)
        let template = viewModel.createTemplate(from: invoice)

        #expect(template != nil)
        #expect(client.preferredTemplateID == template?.id)
        #expect(template?.items.count == 1)
    }

    @MainActor
    @Test func markSentAndPaidUpdateStatus() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let issuer = Issuer(name: "Acme", code: "ACM")
        let invoice = Invoice(invoiceNumber: "ACM-0001", clientName: "Cliente", issuer: issuer)
        invoice.captureIssuerSnapshot(from: issuer)
        context.insert(issuer)
        context.insert(invoice)
        try context.save()

        let viewModel = InvoiceViewModel(modelContext: context)

        viewModel.markSent(invoice)
        #expect(invoice.status == .sent)

        viewModel.markPaid(invoice)
        #expect(invoice.status == .paid)
    }

    @MainActor
    @Test func syncLinkedDataCopiesCurrentClientAndIssuerSnapshots() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let issuer = Issuer(name: "Acme", code: "ACM", address: "Linea 1\nLinea 2", taxId: "B123")
        let client = Client(name: "Cliente", email: "hola@cliente.com", address: "Calle 1\n28001 Madrid", identificationNumber: "X123")
        let invoice = Invoice(
            invoiceNumber: "ACM-0001",
            clientName: "Nombre viejo",
            clientEmail: "",
            clientIdentificationNumber: "",
            clientAddress: "",
            client: client,
            issuer: issuer
        )
        context.insert(issuer)
        context.insert(client)
        context.insert(invoice)
        try context.save()

        client.name = "Cliente actualizado"
        client.address = "Nueva calle\n08001 Barcelona"
        issuer.address = "Avenida nueva\n46001 Valencia"
        issuer.taxId = "B999"

        let viewModel = InvoiceViewModel(modelContext: context)
        let result = viewModel.syncLinkedData(into: invoice)

        #expect(result.didSyncClient)
        #expect(result.didSyncIssuer)
        #expect(invoice.clientName == "Cliente actualizado")
        #expect(invoice.clientAddress == "Nueva calle\n08001 Barcelona")
        #expect(invoice.issuerAddress == "Avenida nueva\n46001 Valencia")
        #expect(invoice.issuerTaxId == "B999")
    }

    @MainActor
    @Test func pdfGenerationSupportsMultilineAddressContent() async throws {
        let issuer = Issuer(name: "Acme", code: "ACM", address: "Linea 1\nLinea 2\nLinea 3")
        let client = Client(name: "Cliente", address: "Direccion muy larga\nSegunda linea\nTercera linea")
        let invoice = Invoice(
            invoiceNumber: "ACM-0001",
            clientName: client.name,
            clientEmail: "cliente@example.com",
            clientAddress: client.address,
            client: client,
            issuer: issuer,
            notes: "Nota inicial\nNota final"
        )
        invoice.captureIssuerSnapshot(from: issuer)
        let item = InvoiceItem(description: "Servicio mensual", quantity: 1, unitPrice: 1000)
        item.invoice = invoice
        invoice.items.append(item)
        invoice.calculateTotal()

        let document = PDFGeneratorService.generateInvoicePDF(invoice: invoice)

        #expect(document != nil)
        #expect(document?.pageCount == 1)
    }

    @MainActor
    @Test func createClientPersistsMonthlyDefaults() async throws {
        let container = try makeContainer()
        let viewModel = ClientViewModel(modelContext: container.mainContext)

        let client = viewModel.createClient(
            name: "Cliente recurrente",
            defaultDueDays: 7,
            defaultIVAPercentage: 21,
            defaultIRPFPercentage: 15,
            defaultNotes: "Retainer mensual"
        )

        #expect(client != nil)
        #expect(client?.defaultDueDays == 7)
        #expect(client?.defaultIVAPercentage == 21)
        #expect(client?.defaultIRPFPercentage == 15)
        #expect(client?.defaultNotes == "Retainer mensual")
    }

    @Test func imageImportParserExtractsSpanishInvoiceFields() async throws {
        let text = """
        NUEVA FACTURA
        Cliente
        no especificado
        Fecha factura
        28-02-2026
        SERVICIOS FEBRERO 2026 BIBIANA
        1,00 x 1.560,00
        IVA 1.560,00 21,00% 327,60
        IRPF 1.560,00 -1,00% -15,60
        Vencimientos
        10-03-2026 Pendiente 1.872,00
        """

        let draft = InvoiceImageImportService.parseDraft(fromRecognizedText: text)

        #expect(draft.clientName == "Bibiana")
        #expect(draft.issueDate == Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 28)))
        #expect(draft.dueDate == Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 10)))
        #expect(draft.items.count == 1)
        #expect(draft.items.first?.description == "Servicios Febrero 2026 Bibiana")
        #expect(draft.items.first?.quantity == 1)
        #expect(draft.items.first?.unitPrice == Decimal(string: "1560"))
        #expect(draft.ivaPercentage == 21)
        #expect(draft.irpfPercentage == 1)
    }

    @Test func imageImportClientMatchingRequiresExactNormalizedName() async throws {
        let clients = [
            Client(name: "Bibiana"),
            Client(name: "Otro Cliente")
        ]

        let matchedClient = InvoiceImageImportService.exactClientMatch(for: "  bíBIANA ", in: clients)
        let missingClient = InvoiceImageImportService.exactClientMatch(for: "Bibiana Studio", in: clients)

        #expect(matchedClient?.name == "Bibiana")
        #expect(missingClient == nil)
    }

    @Test func imageImportServiceUsesHeuristicPathWhenFoundationModelsAreDisabled() async throws {
        let expectedText = "SERVICIOS FEBRERO 2026 BIBIANA\n1,00 x 1.560,00"
        let service = InvoiceImageImportService(
            supportsFoundationModels: false,
            recognizeTextHandler: { _ in expectedText },
            foundationModelRefiner: { _, _ in
                Issue.record("Foundation Models should not run in fallback mode")
                return ImportedInvoiceDraft()
            }
        )

        let draft = try await service.extractDraft(from: Data([0x00]))

        #expect(draft.items.count == 1)
        #expect(draft.engineDescription == AppleIntelligenceAvailability.importEngineDescription)
    }

    @Test func imageImportServiceUsesFoundationModelRefinerWhenEnabled() async throws {
        let expectedText = "SERVICIOS FEBRERO 2026 BIBIANA\n1,00 x 1.560,00"
        let service = InvoiceImageImportService(
            supportsFoundationModels: true,
            recognizeTextHandler: { _ in expectedText },
            foundationModelRefiner: { _, baseDraft in
                var refinedDraft = baseDraft
                refinedDraft.clientName = "Cliente IA"
                refinedDraft.engineDescription = "Apple Intelligence"
                return refinedDraft
            }
        )

        let draft = try await service.extractDraft(from: Data([0x00]))

        #expect(draft.clientName == "Cliente IA")
        #expect(draft.engineDescription == "Apple Intelligence")
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Invoice.self,
            InvoiceItem.self,
            CompanyProfile.self,
            Client.self,
            Issuer.self,
            InvoiceTemplate.self,
            InvoiceTemplateItem.self,
            configurations: configuration
        )
    }
}
