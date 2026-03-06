import SwiftUI
import SwiftData

/// Main app entry point with SwiftData configuration
@main
struct InvoiceGeneratorApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var subscriptionService = SubscriptionService.shared
    private let modelContainer = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subscriptionService)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await subscriptionService.refreshEntitlements()
                await subscriptionService.refreshICloudAvailability()
            }
        }
    }
}

/// Main content view
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0
    @State private var showingOnboarding = false
    @State private var hasRunIssuerMigration = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.pie")
                }
                .tag(0)

            InvoiceListView()
                .tabItem {
                    Label("Invoices", systemImage: "doc.text")
                }
                .tag(1)

            ClientListView()
                .tabItem {
                    Label("Clients", systemImage: "person.3")
                }
                .tag(2)

            IssuerListView()
                .tabItem {
                    Label("Emitters", systemImage: "building.2")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(4)
        }
        .onAppear {
            if !hasRunIssuerMigration {
                IssuerMigrationService.runIfNeeded(modelContext: modelContext)
                hasRunIssuerMigration = true
            }
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
    }
}

#Preview {
    ContentView()
        .modelContainer(PersistenceController.preview)
}
