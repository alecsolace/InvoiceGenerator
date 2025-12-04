import SwiftUI
import SwiftData

/// Main app entry point with SwiftData configuration
@main
struct InvoiceGeneratorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self])
    }
}

/// Main content view
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            InvoiceListView()
                .tabItem {
                    Label("Invoices", systemImage: "doc.text")
                }
                .tag(0)

            ClientListView()
                .tabItem {
                    Label("Clients", systemImage: "person.3")
                }
                .tag(1)

            CompanyProfileView()
                .tabItem {
                    Label("Profile", systemImage: "building.2")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self])
}
