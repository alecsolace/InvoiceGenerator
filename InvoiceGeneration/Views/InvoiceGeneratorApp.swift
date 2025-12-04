import SwiftUI
import SwiftData

/// Main app entry point with SwiftData configuration
@main
struct InvoiceGeneratorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Invoice.self, InvoiceItem.self, CompanyProfile.self])
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
                    Label(L10n.Tabs.invoices, systemImage: "doc.text")
                }
                .tag(0)

            CompanyProfileView()
                .tabItem {
                    Label(L10n.Tabs.profile, systemImage: "building.2")
                }
                .tag(1)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Invoice.self, InvoiceItem.self, CompanyProfile.self])
}
