import SwiftUI

/// Tab-based navigation for iPhone compact layout.
struct TabNavigationView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            iOSDashboardView()
                .tabItem {
                    Label(String(localized: "Inicio"), systemImage: "house")
                }
                .tag(0)

            iOSInvoiceListView()
                .tabItem {
                    Label(String(localized: "Facturas"), systemImage: "doc.text")
                }
                .tag(1)

            iOSClientListView()
                .tabItem {
                    Label(String(localized: "Clientes"), systemImage: "person.3")
                }
                .tag(2)

            emitterOrMyDataTab
                .tag(3)

            iOSSettingsView()
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
            iOSIssuerProfileView()
                .tabItem {
                    Label(String(localized: "Mis datos"), systemImage: "person.crop.rectangle")
                }
        }
    }
}
