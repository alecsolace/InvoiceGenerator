import SwiftUI

/// Settings page for managing PDF storage preferences
struct SettingsView: View {
    var body: some View {
        #if os(macOS)
        SettingsContentMac()
        #else
        NavigationStack {
            SettingsContentIOS()
        }
        #endif
    }
}

#if os(macOS)
private struct SettingsContentMac: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.openURL) private var openURL
    @AppStorage("macPDFSavePath") private var macSavePath: String = ""
    @State private var showingPaywall = false
    @State private var paywallReason: PaywallReason = .settings

    var body: some View {
        Form {
            Section {
                subscriptionStatus
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(String(localized: "PDF Storage", comment: "Settings section title"), systemImage: "folder")
                        .font(.headline)

                    Text(
                        macSavePath.isEmpty
                        ? defaultPathDescription
                        : macSavePath
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)

                    HStack {
                        Button(String(localized: "Choose Folder", comment: "Button to pick PDF folder")) {
                            chooseFolder()
                        }

                        if !macSavePath.isEmpty {
                            Button(String(localized: "Use Documents Folder", comment: "Reset PDF folder button")) {
                                macSavePath = ""
                                PDFStorageManager.resetMacDirectory()
                            }
                        }
                    }
                }
            }

            Section {
                Text(String(localized: "Invoices are saved directly to the folder above so you can share or archive them however you like.", comment: "Settings helper text"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(reason: paywallReason)
                .environmentObject(subscriptionService)
        }
        .padding()
        .task {
            await refreshSyncState()
        }
    }

    private var subscriptionStatus: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(String(localized: "Sync & Pro", comment: "Settings sync section title"))
                    .font(.headline)
            } icon: {
                Image(systemName: "cloud")
                    .foregroundStyle(.tint)
            }

            Toggle(isOn: syncBinding) {
                Text(String(localized: "iCloud Sync", comment: "Sync toggle title"))
            }
            .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 6) {
                statusLabel
                Text(syncMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button(String(localized: "Restore purchases", comment: "Restore purchases button")) {
                    Task { await subscriptionService.restorePurchases() }
                }
                .buttonStyle(.bordered)
                .disabled(subscriptionService.isPurchaseInFlight)

                Button(String(localized: "Manage subscription", comment: "Manage subscription button")) {
                    openManageSubscriptions()
                }
                .buttonStyle(.bordered)
            }

            Button(String(localized: "See Pro benefits", comment: "Open paywall from settings")) {
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

    private var defaultPathDescription: String {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return url?.path ?? String(localized: "Documents", comment: "Documents folder name")
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

    private func refreshSyncState() async {
        await subscriptionService.refreshEntitlements()
        await subscriptionService.refreshICloudAvailability()
    }

    private func openManageSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        openURL(url)
    }
}
#else
private struct SettingsContentIOS: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.openURL) private var openURL
    @State private var showingPaywall = false
    @State private var paywallReason: PaywallReason = .settings

    var body: some View {
        Form {
            Section(String(localized: "Sync & Pro", comment: "Settings sync section title")) {
                Toggle(isOn: syncBinding) {
                    Label(String(localized: "iCloud Sync", comment: "Sync toggle title"), systemImage: "icloud")
                }

                Text(syncMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Label(syncStatusTitle, systemImage: syncStatusIcon)
                    .foregroundStyle(syncStatusColor)
                    .font(.subheadline)

                Button(String(localized: "Restore purchases", comment: "Restore purchases button")) {
                    Task { await subscriptionService.restorePurchases() }
                }
                .disabled(subscriptionService.isPurchaseInFlight)

                Button(String(localized: "Manage subscription", comment: "Manage subscription button")) {
                    openManageSubscriptions()
                }

                Button {
                    paywallReason = .settings
                    showingPaywall = true
                } label: {
                    Label(String(localized: "See Pro benefits", comment: "Open paywall from settings"), systemImage: "sparkles")
                }

                if let error = subscriptionService.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("PDF Storage", systemImage: "folder")
                        .font(.headline)

                    Text(String(localized: "Invoices are stored securely inside the app. Share them using the PDF options after generation.", comment: "iOS storage description"))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle(String(localized: "Settings", comment: "Settings title"))
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

    private var syncStatusIcon: String {
        switch subscriptionService.syncStatus {
        case .ready:
            return "checkmark.icloud.fill"
        case .pausedNoICloud:
            return "icloud.slash"
        case .disabledByUser:
            return "icloud"
        case .lockedByPaywall:
            return "lock.icloud"
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

    private func refreshSyncState() async {
        await subscriptionService.refreshEntitlements()
        await subscriptionService.refreshICloudAvailability()
    }

    private func openManageSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        openURL(url)
    }
}
#endif
