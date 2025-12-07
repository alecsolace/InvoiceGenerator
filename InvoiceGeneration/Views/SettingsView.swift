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

            Toggle(isOn: Binding(
                get: { subscriptionService.syncEnabled },
                set: { newValue in
                    if subscriptionService.isPro {
                        subscriptionService.syncPreferred = newValue
                    } else {
                        paywallReason = .sync
                        showingPaywall = true
                    }
                }
            )) {
                Text(String(localized: "iCloud Sync", comment: "Sync toggle title"))
            }
            .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 6) {
                statusLabel
                Text(String(localized: "Sync invoices across devices when Pro is active. Free includes local data only.", comment: "Sync helper text"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button(String(localized: "See Pro benefits", comment: "Open paywall from settings")) {
                paywallReason = .settings
                showingPaywall = true
            }
            .buttonStyle(.bordered)
        }
    }

    private var statusLabel: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(subscriptionService.isPro ? Color.green : Color.orange)
                .frame(width: 10, height: 10)

            Text(subscriptionService.isPro
                 ? String(localized: "Pro active — sync ready", comment: "Pro status label")
                 : String(localized: "Free plan — upgrade to unlock sync", comment: "Free status label")
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
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
}
#else
private struct SettingsContentIOS: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var showingPaywall = false
    @State private var paywallReason: PaywallReason = .settings

    var body: some View {
        Form {
            Section(String(localized: "Sync & Pro", comment: "Settings sync section title")) {
                Toggle(isOn: Binding(
                    get: { subscriptionService.syncEnabled },
                set: { newValue in
                    if subscriptionService.isPro {
                        subscriptionService.syncPreferred = newValue
                    } else {
                        paywallReason = .sync
                        showingPaywall = true
                    }
                }
            )) {
                    Label(String(localized: "iCloud Sync", comment: "Sync toggle title"), systemImage: "icloud")
                }

                Text(subscriptionService.isPro
                     ? String(localized: "Pro is active. Sync resumes automatically.", comment: "Active sync helper text")
                     : String(localized: "Sync is available with Pro. Keep local invoices on Free.", comment: "Free sync helper text")
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

                Button {
                    paywallReason = .settings
                    showingPaywall = true
                } label: {
                    Label(String(localized: "See Pro benefits", comment: "Open paywall from settings"), systemImage: "sparkles")
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
    }
}
#endif
