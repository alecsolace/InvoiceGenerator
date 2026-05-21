import SwiftUI

/// iPhone-specific settings view matching the Stitch "Ajustes" design.
struct iOSSettingsView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.openURL) private var openURL
    @AppStorage(InvoiceFlowPreferences.defaultDueDaysKey) private var defaultDueDays = InvoiceFlowPreferences.defaultDueDays
    @AppStorage(InvoiceFlowPreferences.afterSaveActionKey) private var afterSaveActionRaw = InvoiceFlowPreferences.defaultAfterSaveAction

    @State private var showingPaywall = false
    @State private var paywallReason: PaywallReason = .settings

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                defaultsSection
                syncSection
                dataSection
                aboutSection
            }
            .navigationTitle(String(localized: "Ajustes"))
            .sheet(isPresented: $showingPaywall) {
                iOSPaywallView()
                    .environmentObject(subscriptionService)
            }
            .task {
                await refreshSyncState()
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Mi cuenta"))
                        .font(.headline)

                    HStack(spacing: 6) {
                        Text(subscriptionService.isPro
                            ? String(localized: "Pro")
                            : String(localized: "Free"))
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                (subscriptionService.isPro ? Color.accentColor : Color.secondary)
                                    .opacity(0.15),
                                in: Capsule()
                            )
                            .foregroundStyle(subscriptionService.isPro ? Color.accentColor : Color.secondary)
                    }
                }

                Spacer()
            }

            Button(String(localized: "Gestionar suscripcion")) {
                openManageSubscriptions()
            }
        }
    }

    // MARK: - Defaults Section

    private var defaultsSection: some View {
        Section(String(localized: "Valores por defecto")) {
            Stepper(
                String(localized: "Dias de vencimiento: \(defaultDueDays)"),
                value: $defaultDueDays,
                in: 0...120
            )

            Picker(
                String(localized: "Accion tras guardar"),
                selection: Binding(
                    get: { QuickInvoiceAfterSaveAction(rawValue: afterSaveActionRaw) ?? .close },
                    set: { afterSaveActionRaw = $0.rawValue }
                )
            ) {
                ForEach(QuickInvoiceAfterSaveAction.allCases) { action in
                    Text(action.localizedTitle)
                        .tag(action)
                }
            }
        }
    }

    // MARK: - Sync Section

    private var syncSection: some View {
        Section(String(localized: "iCloud")) {
            Toggle(isOn: syncBinding) {
                HStack(spacing: 8) {
                    Image(systemName: "icloud")
                        .foregroundStyle(.tint)
                    Text(String(localized: "Sincronizar con iCloud"))
                }
            }

            if !subscriptionService.isPro {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Requiere Pro"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(syncStatusColor)
                        .frame(width: 8, height: 8)
                    Text(syncStatusTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section(String(localized: "Mi perfil")) {
            NavigationLink {
                MyDataView()
            } label: {
                Label(String(localized: "Datos del emisor"), systemImage: "building.2")
            }

            NavigationLink {
                TemplateListView()
            } label: {
                Label(String(localized: "Plantillas guardadas"), systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section(String(localized: "Informacion")) {
            HStack {
                Text(String(localized: "Version"))
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            Button {
                if let url = URL(string: "mailto:support@facturapro.app") {
                    openURL(url)
                }
            } label: {
                Label(String(localized: "Soporte"), systemImage: "envelope")
            }

            Button(String(localized: "Terminos y condiciones")) {
                if let url = URL(string: "https://facturapro.app/terms") {
                    openURL(url)
                }
            }

            Button(String(localized: "Politica de privacidad")) {
                if let url = URL(string: "https://facturapro.app/privacy") {
                    openURL(url)
                }
            }

            if !subscriptionService.isPro {
                Button {
                    paywallReason = .settings
                    showingPaywall = true
                } label: {
                    Label(String(localized: "Ver Pro"), systemImage: "star.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }

    // MARK: - Sync Binding

    private var syncBinding: Binding<Bool> {
        Binding(
            get: { subscriptionService.syncPreferred },
            set: { newValue in
                if newValue {
                    if subscriptionService.entitlementStatus == .active {
                        subscriptionService.syncPreferred = true
                        Task { await subscriptionService.refreshICloudAvailability() }
                    } else {
                        paywallReason = .sync
                        showingPaywall = true
                    }
                } else {
                    subscriptionService.syncPreferred = false
                }
            }
        )
    }

    // MARK: - Sync Status

    private var syncStatusColor: Color {
        switch subscriptionService.syncStatus {
        case .ready: return .green
        case .pausedNoICloud: return .orange
        case .disabledByUser: return .secondary
        case .lockedByPaywall: return .red
        }
    }

    private var syncStatusTitle: String {
        switch subscriptionService.syncStatus {
        case .ready: return String(localized: "Sincronizacion activa")
        case .pausedNoICloud: return String(localized: "Pausado — iCloud no disponible")
        case .disabledByUser: return String(localized: "Desactivado")
        case .lockedByPaywall: return String(localized: "Requiere Pro")
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func refreshSyncState() async {
        await subscriptionService.refreshEntitlements()
        await subscriptionService.refreshICloudAvailability()
    }

    private func openManageSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        openURL(url)
    }
}

#Preview {
    iOSSettingsView()
        .environmentObject(try! SubscriptionService(storeConfiguration: .testing, startTasks: false))
}
