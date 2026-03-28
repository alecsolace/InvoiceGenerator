import SwiftUI

/// Tab-based navigation for iPhone compact layout.
struct TabNavigationView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(String(localized: "Inicio"), systemImage: "house")
                }
                .tag(0)

            InvoiceListView()
                .tabItem {
                    Label(String(localized: "Facturas"), systemImage: "doc.text")
                }
                .tag(1)

            ClientListView()
                .tabItem {
                    Label(String(localized: "Clientes"), systemImage: "person.3")
                }
                .tag(2)

            emitterOrMyDataTab
                .tag(3)

            SettingsView()
                .tabItem {
                    Label(String(localized: "Ajustes"), systemImage: "gearshape")
                }
                .tag(4)
        }
    }

    @ViewBuilder
    private var emitterOrMyDataTab: some View {
        if subscriptionService.isPro {
            NavigationStack {
                IssuerListView()
            }
            .tabItem {
                Label(String(localized: "Emisores"), systemImage: "building.2")
            }
        } else {
            NavigationStack {
                MyDataView()
            }
            .tabItem {
                Label(String(localized: "Mis datos"), systemImage: "person.crop.rectangle")
            }
        }
    }
}
