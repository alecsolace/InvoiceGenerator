import SwiftUI
import SwiftData

/// Simple profile editor for free-tier users showing their single issuer/emitter data.
struct MyDataView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: IssuerViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if let issuer = viewModel.issuers.first {
                    issuerForm(issuer)
                } else {
                    createIssuerPrompt
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "Mis datos"))
        .onAppear {
            if viewModel == nil {
                viewModel = IssuerViewModel(modelContext: modelContext)
            } else {
                viewModel?.fetchIssuers()
            }
        }
    }

    // MARK: - Issuer Form

    @ViewBuilder
    private func issuerForm(_ issuer: Issuer) -> some View {
        MyDataFormView(issuer: issuer, viewModel: viewModel!)
    }

    private var createIssuerPrompt: some View {
        EmptyStateView(
            icon: "person.crop.rectangle",
            title: String(localized: "Sin datos de emisor"),
            message: String(localized: "Configura tus datos para poder emitir facturas."),
            buttonTitle: String(localized: "Configurar"),
            action: {
                _ = viewModel?.createIssuer(
                    name: String(localized: "Mi empresa"),
                    code: "FAC"
                )
            }
        )
    }
}

// MARK: - Form View

private struct MyDataFormView: View {
    @Bindable var issuer: Issuer
    @Bindable var viewModel: IssuerViewModel

    @State private var name: String = ""
    @State private var code: String = ""
    @State private var ownerName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var taxId: String = ""
    @State private var defaultNotes: String = ""
    @State private var verifactuEnabled: Bool = false
    @State private var showSavedConfirmation = false

    var body: some View {
        Form {
            Section(String(localized: "Emisor")) {
                TextField(String(localized: "Nombre"), text: $name)
                TextField(String(localized: "Código"), text: $code)
#if os(iOS)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
#endif
            }

            Section(String(localized: "Contacto")) {
                TextField(String(localized: "Propietario"), text: $ownerName)
                TextField(String(localized: "Email"), text: $email)
#if os(iOS)
                    .keyboardType(.emailAddress)
#endif
                TextField(String(localized: "Teléfono"), text: $phone)
                TextField(String(localized: "NIF/CIF"), text: $taxId)
                TextField(String(localized: "Dirección"), text: $address, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section(String(localized: "Configuración de facturas")) {
                TextField(String(localized: "Notas por defecto"), text: $defaultNotes, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section(String(localized: "VeriFACTU Compliance", comment: "Issuer verifactu section")) {
                Toggle(String(localized: "Enable VeriFACTU", comment: "Toggle to enable verifactu"), isOn: $verifactuEnabled)

                if verifactuEnabled && taxId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label(
                        String(localized: "Tax ID (NIF/CIF) is required for VeriFACTU", comment: "Verifactu NIF warning"),
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.orange)
                }
            }

            Section {
                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()
                        if showSavedConfirmation {
                            Label(String(localized: "Guardado"), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text(String(localized: "Guardar cambios"))
                        }
                        Spacer()
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear { hydrate() }
    }

    private func hydrate() {
        name = issuer.name
        code = issuer.code
        ownerName = issuer.ownerName
        email = issuer.email
        phone = issuer.phone
        address = issuer.address
        taxId = issuer.taxId
        defaultNotes = issuer.defaultNotes
        verifactuEnabled = issuer.verifactuEnabled
    }

    private func save() {
        let success = viewModel.updateIssuer(
            issuer,
            name: name,
            code: code,
            ownerName: ownerName,
            email: email,
            phone: phone,
            address: address,
            taxId: taxId,
            logoData: issuer.logoData,
            defaultNotes: defaultNotes,
            verifactuEnabled: verifactuEnabled
        )

        if success {
            showSavedConfirmation = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                showSavedConfirmation = false
            }
        }
    }
}
