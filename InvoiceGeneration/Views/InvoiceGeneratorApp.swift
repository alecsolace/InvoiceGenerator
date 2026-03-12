import CloudKit
import OSLog
import SwiftData
import SwiftUI

/// Main app entry point with SwiftData configuration
@main
struct InvoiceGeneratorApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var subscriptionService = SubscriptionService.shared

    private static let containerResult: Result<ModelContainer, Error> = {
        do {
            return .success(try PersistenceController.makeContainer())
        } catch {
            PersistenceController.logger.critical("ModelContainer failed to initialize: \(error.localizedDescription)")
            return .failure(error)
        }
    }()

    var body: some Scene {
        WindowGroup {
            switch Self.containerResult {
            case .success(let container):
                ContentView()
                    .environmentObject(subscriptionService)
                    .modelContainer(container)
                    .onChange(of: scenePhase) { _, newPhase in
                        guard newPhase == .active else { return }
                        Task {
                            await subscriptionService.refreshEntitlements()
                            await subscriptionService.refreshICloudAvailability()

                            if subscriptionService.syncEnabled {
                                await performCloudKitFetch(container: container)
                            }
                        }
                    }
            case .failure(let error):
                PersistenceErrorView(error: error)
            }
        }
    }
}

// MARK: - CloudKit Fetch

@MainActor
private func performCloudKitFetch(container: ModelContainer) async {
    let context = container.mainContext

    // Register for CloudKit push notifications once
    let subscriptionKey = "cloudkit.subscriptionSetup"
    if !UserDefaults.standard.bool(forKey: subscriptionKey) {
        do {
            try await CloudKitService.shared.setupSubscription()
            UserDefaults.standard.set(true, forKey: subscriptionKey)
        } catch {
            PersistenceController.logger.error("CloudKit subscription setup failed: \(error.localizedDescription)")
        }
    }

    do {
        // Fetch invoices
        let invoiceRecords = try await CloudKitService.shared.fetchInvoices()
        for record in invoiceRecords {
            guard let idString = record.recordID.recordName as String?,
                  let id = UUID(uuidString: idString) else { continue }

            let descriptor = FetchDescriptor<Invoice>(predicate: #Predicate { $0.id == id })
            let existing = try? context.fetch(descriptor).first
            let cloudDate = record.modificationDate ?? record.creationDate ?? Date.distantPast

            if let invoice = existing {
                guard cloudDate > invoice.updatedAt else { continue }
                if let invoiceNumber = record["invoiceNumber"] as? String { invoice.invoiceNumber = invoiceNumber }
                if let status = record["status"] as? String, let s = InvoiceStatus(rawValue: status) { invoice.status = s }
                if let notes = record["notes"] as? String { invoice.notes = notes }
                if let dueDate = record["dueDate"] as? Date { invoice.dueDate = dueDate }
            } else {
                guard let invoiceNumber = record["invoiceNumber"] as? String,
                      let issueDate = record["issueDate"] as? Date,
                      let dueDate = record["dueDate"] as? Date,
                      let statusRaw = record["status"] as? String,
                      let status = InvoiceStatus(rawValue: statusRaw) else { continue }

                let invoice = Invoice(
                    invoiceNumber: invoiceNumber,
                    clientName: record["clientName"] as? String ?? "",
                    clientEmail: record["clientEmail"] as? String ?? "",
                    clientIdentificationNumber: record["clientIdentificationNumber"] as? String ?? "",
                    clientAddress: record["clientAddress"] as? String ?? "",
                    issuerName: record["issuerName"] as? String ?? "",
                    issuerCode: record["issuerCode"] as? String ?? "",
                    issuerOwnerName: record["issuerOwnerName"] as? String ?? "",
                    issuerEmail: record["issuerEmail"] as? String ?? "",
                    issuerPhone: record["issuerPhone"] as? String ?? "",
                    issuerAddress: record["issuerAddress"] as? String ?? "",
                    issuerTaxId: record["issuerTaxId"] as? String ?? "",
                    issueDate: issueDate,
                    dueDate: dueDate,
                    status: status,
                    notes: record["notes"] as? String ?? "",
                    ivaPercentage: (record["ivaPercentage"] as? NSDecimalNumber)?.decimalValue ?? 0,
                    irpfPercentage: (record["irpfPercentage"] as? NSDecimalNumber)?.decimalValue ?? 0
                )
                context.insert(invoice)
            }
        }

        // Fetch clients
        let clientRecords = try await CloudKitService.shared.fetchClients()
        for record in clientRecords {
            guard let idString = record.recordID.recordName as String?,
                  let id = UUID(uuidString: idString) else { continue }

            let descriptor = FetchDescriptor<Client>(predicate: #Predicate { $0.id == id })
            let existing = try? context.fetch(descriptor).first
            let cloudDate = record.modificationDate ?? record.creationDate ?? Date.distantPast

            if let client = existing {
                guard cloudDate > client.updatedAt else { continue }
                if let name = record["name"] as? String { client.name = name }
                if let email = record["email"] as? String { client.email = email }
                if let address = record["address"] as? String { client.address = address }
                if let idNum = record["identificationNumber"] as? String { client.identificationNumber = idNum }
                if let colorHex = record["accentColorHex"] as? String { client.accentColorHex = colorHex }
                if let dueDays = record["defaultDueDays"] as? Int { client.defaultDueDays = dueDays }
                if let notes = record["defaultNotes"] as? String { client.defaultNotes = notes }
                client.defaultIVAPercentage = (record["defaultIVAPercentage"] as? NSDecimalNumber)?.decimalValue
                client.defaultIRPFPercentage = (record["defaultIRPFPercentage"] as? NSDecimalNumber)?.decimalValue
                if let templateIDString = record["preferredTemplateID"] as? String {
                    client.preferredTemplateID = UUID(uuidString: templateIDString)
                }
            } else {
                guard let name = record["name"] as? String else { continue }
                let client = Client(
                    name: name,
                    email: record["email"] as? String ?? "",
                    address: record["address"] as? String ?? "",
                    identificationNumber: record["identificationNumber"] as? String ?? "",
                    accentColorHex: record["accentColorHex"] as? String ?? Client.defaultAccentHex,
                    defaultDueDays: record["defaultDueDays"] as? Int ?? 0,
                    defaultIVAPercentage: (record["defaultIVAPercentage"] as? NSDecimalNumber)?.decimalValue,
                    defaultIRPFPercentage: (record["defaultIRPFPercentage"] as? NSDecimalNumber)?.decimalValue,
                    defaultNotes: record["defaultNotes"] as? String ?? ""
                )
                if let templateIDString = record["preferredTemplateID"] as? String {
                    client.preferredTemplateID = UUID(uuidString: templateIDString)
                }
                context.insert(client)
            }
        }

        // Fetch issuers
        let issuerRecords = try await CloudKitService.shared.fetchIssuers()
        for record in issuerRecords {
            guard let idString = record.recordID.recordName as String?,
                  let id = UUID(uuidString: idString) else { continue }

            let descriptor = FetchDescriptor<Issuer>(predicate: #Predicate { $0.id == id })
            let existing = try? context.fetch(descriptor).first
            let cloudDate = record.modificationDate ?? record.creationDate ?? Date.distantPast

            if let issuer = existing {
                guard cloudDate > issuer.updatedAt else { continue }
                if let name = record["name"] as? String { issuer.name = name }
                if let code = record["code"] as? String { issuer.code = code }
                if let ownerName = record["ownerName"] as? String { issuer.ownerName = ownerName }
                if let email = record["email"] as? String { issuer.email = email }
                if let phone = record["phone"] as? String { issuer.phone = phone }
                if let address = record["address"] as? String { issuer.address = address }
                if let taxId = record["taxId"] as? String { issuer.taxId = taxId }
                if let seq = record["nextInvoiceSequence"] as? Int { issuer.nextInvoiceSequence = seq }
                issuer.logoData = record["logoData"] as? Data
            } else {
                guard let name = record["name"] as? String,
                      let code = record["code"] as? String else { continue }
                let issuer = Issuer(
                    name: name,
                    code: code,
                    ownerName: record["ownerName"] as? String ?? "",
                    email: record["email"] as? String ?? "",
                    phone: record["phone"] as? String ?? "",
                    address: record["address"] as? String ?? "",
                    taxId: record["taxId"] as? String ?? "",
                    logoData: record["logoData"] as? Data,
                    nextInvoiceSequence: record["nextInvoiceSequence"] as? Int ?? 1
                )
                context.insert(issuer)
            }
        }

        try context.save()
    } catch {
        PersistenceController.logger.error("CloudKit fetch failed: \(error.localizedDescription)")
    }
}

/// Main content view
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0
    @State private var showingOnboarding = false
    @State private var hasRunIssuerMigration = false
    @State private var hasPreparedUITestState = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Inicio", systemImage: "house")
                }
                .tag(0)

            InvoiceListView()
                .tabItem {
                    Label("Facturas", systemImage: "doc.text")
                }
                .tag(1)

            ClientListView()
                .tabItem {
                    Label("Clientes", systemImage: "person.3")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape")
                }
                .tag(3)
        }
        .onAppear {
            if !hasRunIssuerMigration {
                IssuerMigrationService.runIfNeeded(modelContext: modelContext)
                hasRunIssuerMigration = true
            }
            prepareUITestStateIfNeeded()
            showingOnboarding = !hasCompletedOnboarding
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView(isPresented: $showingOnboarding) {
                hasCompletedOnboarding = true
            }
            #if os(iOS)
            .presentationDetents([.large])
            #endif
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active, SharedImageImportStore.hasPendingImport else { return }
            selectedTab = 0
        }
    }

    private func prepareUITestStateIfNeeded() {
        guard !hasPreparedUITestState else { return }
        hasPreparedUITestState = true

        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("UITEST_SKIP_ONBOARDING") {
            hasCompletedOnboarding = true
        }

        guard arguments.contains("UITEST_SEED_SAMPLE_DATA") else { return }

        do {
            let existingInvoices = try modelContext.fetch(FetchDescriptor<Invoice>())
            if !existingInvoices.isEmpty {
                return
            }
        } catch {
            return
        }

        let issuer = Issuer(name: "Acme Studio", code: "ACM", ownerName: "Alex", email: "hola@acme.test", nextInvoiceSequence: 3)
        let client = Client(
            name: "Cliente Mensual",
            email: "facturas@cliente.test",
            identificationNumber: "B12345678",
            defaultDueDays: 15,
            defaultIVAPercentage: 21,
            defaultIRPFPercentage: 15,
            defaultNotes: "Servicio mensual"
        )
        let template = InvoiceTemplate(
            name: "Cliente Mensual",
            client: client,
            issuer: issuer,
            dueDays: 15,
            ivaPercentage: 21,
            irpfPercentage: 15,
            notes: "Servicio mensual"
        )
        let item = InvoiceTemplateItem(description: "Retainer mensual", quantity: 1, unitPrice: 1200, sortOrder: 0)
        item.template = template
        template.items?.append(item)
        client.preferredTemplateID = template.id

        let sentInvoice = Invoice(
            invoiceNumber: "ACM-0001",
            clientName: client.name,
            clientEmail: client.email,
            clientIdentificationNumber: client.identificationNumber,
            clientAddress: client.address,
            client: client,
            issuer: issuer,
            issueDate: Date().addingMonths(-1),
            dueDate: Date().addingDays(-5),
            status: .sent,
            notes: "Servicio mensual",
            ivaPercentage: 21,
            irpfPercentage: 15
        )
        sentInvoice.captureIssuerSnapshot(from: issuer)

        let sentItem = InvoiceItem(description: "Retainer mensual", quantity: 1, unitPrice: 1200)
        sentItem.invoice = sentInvoice
        sentInvoice.items?.append(sentItem)
        sentInvoice.calculateTotal()

        let draftInvoice = Invoice(
            invoiceNumber: "ACM-0002",
            clientName: client.name,
            clientEmail: client.email,
            clientIdentificationNumber: client.identificationNumber,
            clientAddress: client.address,
            client: client,
            issuer: issuer,
            issueDate: Date(),
            dueDate: Date().addingDays(15),
            status: .draft,
            notes: "Servicio mensual",
            ivaPercentage: 21,
            irpfPercentage: 15
        )
        draftInvoice.captureIssuerSnapshot(from: issuer)
        let draftItem = InvoiceItem(description: "Retainer mensual", quantity: 1, unitPrice: 1200)
        draftItem.invoice = draftInvoice
        draftInvoice.items?.append(draftItem)
        draftInvoice.calculateTotal()

        modelContext.insert(issuer)
        modelContext.insert(client)
        modelContext.insert(template)
        modelContext.insert(item)
        modelContext.insert(sentInvoice)
        modelContext.insert(sentItem)
        modelContext.insert(draftInvoice)
        modelContext.insert(draftItem)

        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(PersistenceController.preview)
}
