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
                    IssuerListView()
                } label: {
                    settingsRow(
                        title: "Emisores",
                        subtitle: "Gestiona los emisores y su numeracion",
                        systemImage: "building.2"
                    )
                }

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
                    Label("Sincronizacion iCloud", systemImage: "icloud")
                }

                Text(
                    subscriptionService.isPro
                    ? "Pro activo. La sincronizacion puede quedar siempre encendida."
                    : "La sincronizacion esta disponible con Pro. En gratis todo se guarda localmente."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

                Button("Ver Pro") {
                    paywallReason = .settings
                    showingPaywall = true
                }
                .buttonStyle(.bordered)
            }

            #if os(macOS)
            Section("PDF") {
                VStack(alignment: .leading, spacing: 8) {
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
        panel.prompt = "Elegir"
        panel.message = "Selecciona la carpeta donde quieres guardar los PDF."

        if panel.runModal() == .OK, let url = panel.url {
            macSavePath = url.path
            PDFStorageManager.setMacDirectory(path: url.path)
        }
    }
    #endif
}
