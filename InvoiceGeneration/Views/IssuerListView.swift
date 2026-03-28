import SwiftUI
import SwiftData

struct IssuerListView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: IssuerViewModel?
    @State private var editorState: IssuerEditorState?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading {
                    ProgressView("Loading emitters...")
                } else if viewModel.issuers.isEmpty {
                    EmptyStateView(
                        icon: "building.2.crop.circle",
                        title: String(localized: "Sin emisores"),
                        message: String(localized: "Crea un emisor para emitir facturas y llevar el historial por remitente."),
                        buttonTitle: String(localized: "Crear emisor"),
                        action: { editorState = .create }
                    )
                } else {
                    issuerList(viewModel)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "Emisores"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorState = .create
                } label: {
                    Label(String(localized: "Añadir emisor"), systemImage: "plus")
                }
            }
        }
        .sheet(item: $editorState) { state in
            if let viewModel {
                IssuerEditorView(mode: state, viewModel: viewModel)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = IssuerViewModel(modelContext: modelContext)
            } else {
                viewModel?.fetchIssuers()
            }
        }
    }

    // MARK: - Issuer List

    private func issuerList(_ viewModel: IssuerViewModel) -> some View {
        List {
            ForEach(viewModel.issuers) { issuer in
                issuerRow(issuer, viewModel: viewModel)
            }
        }
    }

    private func issuerRow(_ issuer: Issuer, viewModel: IssuerViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(issuer.name)
                    .font(.headline)
                Spacer()
                Text(issuer.code)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1), in: Capsule())
                    .foregroundStyle(.blue)
            }

            if !issuer.email.isEmpty {
                Label(issuer.email, systemImage: "envelope")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !issuer.taxId.isEmpty {
                Label(issuer.taxId, systemImage: "number")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if issuer.verifactuEnabled {
                Label(String(localized: "VeriFactu", comment: "Verifactu badge"), systemImage: "checkmark.shield")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
        .platformRowActions(
            onEdit: { editorState = .edit(issuer) },
            onDelete: { _ = viewModel.deleteIssuer(issuer) }
        )
    }
}

// MARK: - Editor State

private enum IssuerEditorState: Identifiable {
    case create
    case edit(Issuer)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let issuer):
            return issuer.id.uuidString
        }
    }
}

// MARK: - Issuer Editor

private struct IssuerEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: IssuerEditorState
    @Bindable var viewModel: IssuerViewModel

    @State private var name = ""
    @State private var code = ""
    @State private var ownerName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var taxId = ""
    @State private var defaultNotes = ""
    @State private var verifactuEnabled = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
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

                    if verifactuEnabled {
                        Text(String(localized: "Invoices from this emitter will generate hash-chained records and QR codes for AEAT verification.", comment: "Verifactu description"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancelar")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Guardar")) {
                        persist()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear(perform: hydrateIfNeeded)
    }

    private var title: String {
        switch mode {
        case .create:
            return String(localized: "Nuevo emisor")
        case .edit:
            return String(localized: "Editar emisor")
        }
    }

    private func hydrateIfNeeded() {
        guard case .edit(let issuer) = mode else { return }
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

    private func persist() {
        switch mode {
        case .create:
            guard viewModel.createIssuer(
                name: name,
                code: code,
                ownerName: ownerName,
                email: email,
                phone: phone,
                address: address,
                taxId: taxId,
                defaultNotes: defaultNotes,
                verifactuEnabled: verifactuEnabled
            ) != nil else {
                errorMessage = viewModel.errorMessage
                return
            }
            dismiss()

        case .edit(let issuer):
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
            guard success else {
                errorMessage = viewModel.errorMessage
                return
            }
            dismiss()
        }
    }
}

// MARK: - Platform Row Actions

private extension View {
    @ViewBuilder
    func platformRowActions(
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        #if os(iOS)
        self.swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onEdit) {
                Label(String(localized: "Editar"), systemImage: "pencil")
            }

            Button(role: .destructive, action: onDelete) {
                Label(String(localized: "Eliminar"), systemImage: "trash")
            }
        }
        #else
        self.contextMenu {
            Button(action: onEdit) {
                Label(String(localized: "Editar"), systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label(String(localized: "Eliminar"), systemImage: "trash")
            }
        }
        #endif
    }
}

#Preview {
    NavigationStack {
        IssuerListView()
    }
    .modelContainer(for: [Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self, Issuer.self])
}
