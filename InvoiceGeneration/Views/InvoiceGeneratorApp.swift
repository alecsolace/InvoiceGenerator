import SwiftUI
import SwiftData

/// Main app entry point with SwiftData configuration
@main
struct InvoiceGeneratorApp: App {
    @StateObject private var subscriptionService = SubscriptionService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subscriptionService)
        }
        .modelContainer(for: [Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self])
    }
}

/// Main content view
struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0
    @State private var showingOnboarding = false
    
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

            CompanyProfileView()
                .tabItem {
                    Label("Profile", systemImage: "building.2")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(4)
        }
        .onAppear {
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
        .modelContainer(for: [Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self])
}
