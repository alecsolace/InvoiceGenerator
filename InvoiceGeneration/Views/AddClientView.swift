import SwiftData
import SwiftUI

struct AddClientView: View {
    enum Mode {
        case create
        case edit(Client)

        var title: String {
            switch self {
            case .create:
                return "Nuevo cliente"
            case .edit:
                return "Editar cliente"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: ClientViewModel
    let mode: Mode
    var onSave: ((Client) -> Void)?

    @Query(sort: [SortDescriptor(\InvoiceTemplate.updatedAt, order: .reverse)]) private var templates: [InvoiceTemplate]

    @State private var name = ""
    @State private var email = ""
    @State private var address = ""
    @State private var identificationNumber = ""
    @State private var accentColor = Color(hex: Client.defaultAccentHex) ?? .blue
    @State private var defaultDueDays = "\(InvoiceFlowPreferences.defaultDueDays)"
    @State private var defaultIVAPercentage = ""
    @State private var defaultIRPFPercentage = ""
    @State private var defaultNotes = ""
    @State private var invoiceCode = ""
    @State private var preferredTemplateID: UUID?
    @State private var countryCode = "ES"
    @State private var locationType: ClientLocationType = .national
    @State private var hasHydrated = false

    init(
        viewModel: ClientViewModel,
        mode: Mode = .create,
        onSave: ((Client) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.mode = mode
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos del cliente") {
                    TextField("Nombre", text: $name)

                    TextField("Email", text: $email)
#if os(iOS)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
#endif

                    TextField("NIF/CIF", text: $identificationNumber)

                    TextField("Direccion", text: $address, axis: .vertical)
                        .lineLimit(3...6)

                    ColorPicker("Color", selection: $accentColor, supportsOpacity: false)

                    TextField(String(localized: "Country Code (ISO)", comment: "Country code field"), text: $countryCode)
#if os(iOS)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
#endif

                    Picker(String(localized: "Location Type", comment: "Client location type"), selection: $locationType) {
                        ForEach(ClientLocationType.allCases) { type in
                            Text(type.localizedTitle).tag(type)
                        }
                    }
                }

                Section("Defaults de facturacion") {
                    TextField("Vencimiento por defecto (dias)", text: $defaultDueDays)
#if os(iOS)
                        .keyboardType(.numberPad)
#endif

                    TextField("IVA % por defecto", text: $defaultIVAPercentage)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif

                    TextField("IRPF % por defecto", text: $defaultIRPFPercentage)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif

                    TextField("Notas por defecto", text: $defaultNotes, axis: .vertical)
                        .lineLimit(3...5)

                    TextField("Codigo de factura", text: $invoiceCode)
#if os(iOS)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
#endif
                }

                Section("Plantilla preferida") {
                    Picker("Plantilla", selection: $preferredTemplateID) {
                        Text("Sin plantilla")
                            .tag(UUID?.none)

                        ForEach(templates) { template in
                            Text(template.name)
                                .tag(Optional(template.id))
                        }
                    }
                }
            }
            .navigationTitle(mode.title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        persist()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear(perform: hydrateIfNeeded)
    }

    private func hydrateIfNeeded() {
        guard !hasHydrated else { return }
        hasHydrated = true

        guard case .edit(let client) = mode else { return }

        name = client.name
        email = client.email
        address = client.address
        identificationNumber = client.identificationNumber
        accentColor = client.accentColor
        defaultDueDays = "\(client.defaultDueDays > 0 ? client.defaultDueDays : InvoiceFlowPreferences.defaultDueDays)"

        if let defaultIVA = client.defaultIVAPercentage {
            defaultIVAPercentage = NSDecimalNumber(decimal: defaultIVA).stringValue
        }

        if let defaultIRPF = client.defaultIRPFPercentage {
            defaultIRPFPercentage = NSDecimalNumber(decimal: defaultIRPF).stringValue
        }

        defaultNotes = client.defaultNotes
        invoiceCode = client.invoiceCode
        preferredTemplateID = client.preferredTemplateID
        countryCode = client.countryCode
        locationType = client.locationType
    }

    private func persist() {
        let accentHex = accentColor.hexString ?? Client.defaultAccentHex
        let dueDaysValue = Int(defaultDueDays) ?? InvoiceFlowPreferences.defaultDueDays
        let ivaValue = Decimal(string: defaultIVAPercentage)
        let irpfValue = Decimal(string: defaultIRPFPercentage)

        switch mode {
        case .create:
            guard let client = viewModel.createClient(
                name: name,
                email: email,
                address: address,
                identificationNumber: identificationNumber,
                accentColorHex: accentHex,
                defaultDueDays: dueDaysValue,
                defaultIVAPercentage: ivaValue,
                defaultIRPFPercentage: irpfValue,
                defaultNotes: defaultNotes,
                invoiceCode: invoiceCode,
                preferredTemplateID: preferredTemplateID,
                countryCode: countryCode,
                locationType: locationType
            ) else {
                return
            }

            onSave?(client)
        case .edit(let client):
            guard viewModel.updateClient(
                client,
                name: name,
                email: email,
                address: address,
                identificationNumber: identificationNumber,
                accentColorHex: accentHex,
                defaultDueDays: dueDaysValue,
                defaultIVAPercentage: ivaValue,
                defaultIRPFPercentage: irpfValue,
                defaultNotes: defaultNotes,
                invoiceCode: invoiceCode,
                preferredTemplateID: preferredTemplateID,
                countryCode: countryCode,
                locationType: locationType
            ) else {
                return
            }

            onSave?(client)
        }

        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Invoice.self,
        InvoiceItem.self,
        CompanyProfile.self,
        Client.self,
        Issuer.self,
        InvoiceTemplate.self,
        InvoiceTemplateItem.self,
        configurations: config
    )

    let viewModel = ClientViewModel(modelContext: container.mainContext)

    return AddClientView(viewModel: viewModel)
        .modelContainer(container)
}
