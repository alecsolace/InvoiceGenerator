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
                        }
                    }
            case .failure(let error):
                PersistenceErrorView(error: error)
            }
        }
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
        template.items.append(item)
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
        sentInvoice.items.append(sentItem)
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
        draftInvoice.items.append(draftItem)
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
