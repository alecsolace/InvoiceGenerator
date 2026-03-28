import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            #if os(macOS)
            SettingsContent()
                .padding()
            #else
            SettingsContent()
            #endif
        }
    }
}

private struct SettingsContent: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.openURL) private var openURL
    @AppStorage("macPDFSavePath") private var macSavePath: String = ""
    @AppStorage(InvoiceFlowPreferences.defaultDueDaysKey) private var defaultDueDays = InvoiceFlowPreferences.defaultDueDays
    @AppStorage(InvoiceFlowPreferences.afterSaveActionKey) private var afterSaveActionRaw = InvoiceFlowPreferences.defaultAfterSaveAction

    @State private var showingPaywall = false
    @State private var paywallReason: PaywallReason = .settings

    var body: some View {
        Form {
            Section("Facturacion mensual") {
                Stepper("Vencimiento por defecto: \(defaultDueDays) dias", value: $defaultDueDays, in: 0...120)

                Picker(
                    "Despues de guardar",
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

            Section("Datos maestros") {
                NavigationLink {
                    TemplateListView()
                } label: {
                    settingsRow(
                        title: "Plantillas",
                        subtitle: "Reutiliza facturas mensuales",
                        systemImage: "doc.on.doc"
                    )
                }
            }

            Section("Sync y Pro") {
                Toggle(isOn: syncBinding) {
                    Label("Sincronizacion iCloud", systemImage: "icloud")
                }

                VStack(alignment: .leading, spacing: 6) {
                    statusLabel
                    Text(syncMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button("Restore purchases") {
                        Task { await subscriptionService.restorePurchases() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(subscriptionService.isPurchaseInFlight)

                    Button("Manage subscription") {
                        openManageSubscriptions()
                    }
                    .buttonStyle(.bordered)
                }

                Button("Ver Pro") {
                    paywallReason = .settings
                    showingPaywall = true
                }
                .buttonStyle(.borderedProminent)

                if let error = subscriptionService.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            #if os(macOS)
            Section("PDF") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("PDF Storage", systemImage: "folder")
                        .font(.headline)

                    Text(macSavePath.isEmpty ? defaultPathDescription : macSavePath)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Elegir carpeta") {
                            chooseFolder()
                        }

                        if !macSavePath.isEmpty {
                            Button("Usar Documentos") {
                                macSavePath = ""
                                PDFStorageManager.resetMacDirectory()
                            }
                        }
                    }
                }
            }
            #else
            Section("PDF") {
                Text("Los PDF se guardan dentro de la app y puedes compartirlos desde cada factura.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            #endif
        }
        .navigationTitle("Ajustes")
        .sheet(isPresented: $showingPaywall) {
            PaywallView(reason: paywallReason)
                .environmentObject(subscriptionService)
        }
        .task {
            await refreshSyncState()
        }
    }

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

    private var statusLabel: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(syncStatusColor)
                .frame(width: 10, height: 10)

            Text(syncStatusTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var syncStatusColor: Color {
        switch subscriptionService.syncStatus {
        case .ready:
            return .green
        case .pausedNoICloud:
            return .orange
        case .disabledByUser:
            return .secondary
        case .lockedByPaywall:
            return .red
        }
    }

    private var syncStatusTitle: String {
        switch subscriptionService.syncStatus {
        case .ready:
            return String(localized: "Sync ready", comment: "Ready sync status label")
        case .pausedNoICloud:
            return String(localized: "Sync paused", comment: "Paused sync status label")
        case .disabledByUser:
            return String(localized: "Sync turned off", comment: "Disabled sync status label")
        case .lockedByPaywall:
            switch subscriptionService.entitlementStatus {
            case .expired:
                return String(localized: "Pro expired", comment: "Expired subscription status label")
            case .free:
                return String(localized: "Free plan", comment: "Free plan status label")
            case .active:
                return String(localized: "Sync unavailable", comment: "Fallback sync status label")
            }
        }
    }

    private var syncMessage: String {
        switch subscriptionService.syncStatus {
        case .ready:
            return String(localized: "Your Pro entitlement is active and iCloud is available. Sync can run whenever you use the app.", comment: "Ready sync helper text")
        case .pausedNoICloud:
            return String(localized: "Pro is active, but iCloud is unavailable on this device. Sync will resume automatically when iCloud is ready.", comment: "Paused sync helper text")
        case .disabledByUser:
            return String(localized: "Sync is currently disabled by preference. Your data continues to be stored locally.", comment: "Disabled sync helper text")
        case .lockedByPaywall:
            switch subscriptionService.entitlementStatus {
            case .expired:
                return String(localized: "Your Pro access expired. Sync preference is preserved and will resume automatically if Pro becomes active again.", comment: "Expired sync helper text")
            case .free:
                return String(localized: "Sync is part of Pro. Upgrade to unlock cross-device sync while keeping local data on Free.", comment: "Free sync helper text")
            case .active:
                return String(localized: "Sync is unavailable right now.", comment: "Fallback locked sync helper text")
            }
        }
    }

    private func settingsRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    #if os(macOS)
    private var defaultPathDescription: String {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return url?.path ?? "Documents"
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Choose", comment: "Choose folder prompt")
        panel.message = String(localized: "Select where you want Invoice Generator to store PDF files.", comment: "Choose folder description")

        if panel.runModal() == .OK, let url = panel.url {
            macSavePath = url.path
            PDFStorageManager.setMacDirectory(path: url.path)
        }
    }
    #endif

    private func refreshSyncState() async {
        await subscriptionService.refreshEntitlements()
        await subscriptionService.refreshICloudAvailability()
    }

    private func openManageSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        openURL(url)
    }
}
