import SwiftUI

/// Sidebar-based navigation for iPad and Mac using NavigationSplitView.
struct SidebarNavigationView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var selection: NavigationSection? = .home

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    Label(String(localized: "Inicio"), systemImage: "house")
                        .tag(NavigationSection.home)

                    Label(String(localized: "Facturas"), systemImage: "doc.text")
                        .tag(NavigationSection.invoices)

                    Label(String(localized: "Clientes"), systemImage: "person.3")
                        .tag(NavigationSection.clients)
                }

                Section {
                    if subscriptionService.isPro {
                        Label(String(localized: "Emisores"), systemImage: "building.2")
                            .tag(NavigationSection.emitters)
                    } else {
                        Label(String(localized: "Mis datos"), systemImage: "person.crop.rectangle")
                            .tag(NavigationSection.myData)
                    }
                }

                Section {
                    Label(String(localized: "Ajustes"), systemImage: "gearshape")
                        .tag(NavigationSection.settings)
                }
            }
            .navigationTitle(String(localized: "Facturación"))
        } detail: {
            detailView
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .home:
            HomeView()
        case .invoices:
            InvoiceListView()
        case .clients:
            ClientListView()
        case .emitters:
            NavigationStack {
                IssuerListView()
            }
        case .myData:
            NavigationStack {
                MyDataView()
            }
        case .settings:
            SettingsView()
        case nil:
            Text(String(localized: "Selecciona una sección"))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Navigation Section

enum NavigationSection: String, Hashable, CaseIterable {
    case home
    case invoices
    case clients
    case emitters
    case myData
    case settings
}
