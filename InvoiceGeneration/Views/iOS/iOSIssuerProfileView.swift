import SwiftData
import SwiftUI

/// iPhone-specific issuer profile / "Mis Datos" view matching the Stitch design.
struct iOSIssuerProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionService: SubscriptionService

    @State private var viewModel: IssuerViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if subscriptionService.isPro {
                    proIssuerList
                } else {
                    freeIssuerForm
                }
            }
            .navigationTitle(subscriptionService.isPro
                ? String(localized: "Emisores")
                : String(localized: "Mis Datos"))
        }
        .onAppear {
            if viewModel == nil {
                viewModel = IssuerViewModel(modelContext: modelContext)
            }
        }
    }

    // MARK: - Free Tier: Single Issuer Form

    @ViewBuilder
    private var freeIssuerForm: some View {
        if let viewModel, let issuer = viewModel.issuers.first {
            iOSIssuerFormView(issuer: issuer, viewModel: viewModel)
        } else if let viewModel {
            // No issuer yet — show creation prompt
            VStack(spacing: 20) {
                Image(systemName: "building.2")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text(String(localized: "Configura tu perfil de emisor"))
                    .font(.headline)

                Text(String(localized: "Tu nombre, CIF y datos de contacto apareceran en cada factura."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    viewModel.createIssuer(name: String(localized: "Mi empresa"))
                } label: {
                    Label(String(localized: "Crear perfil"), systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(32)
        } else {
            ProgressView()
        }
    }

    // MARK: - Pro Tier: Issuer List

    @ViewBuilder
    private var proIssuerList: some View {
        if let viewModel {
            IssuerListView()
        } else {
            ProgressView()
        }
    }
}

// MARK: - Issuer Form (iOS-styled)

private struct iOSIssuerFormView: View {
    @Bindable var issuer: Issuer
    let viewModel: IssuerViewModel

    @State private var name: String = ""
    @State private var ownerName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var taxId: String = ""
    @State private var verifactuEnabled: Bool = false

    var body: some View {
        Form {
            logoSection

            Section(String(localized: "Datos de la empresa")) {
                TextField(String(localized: "Nombre de la empresa"), text: $name)
                TextField(String(localized: "Nombre del titular"), text: $ownerName)
            }

            Section(String(localized: "Datos fiscales")) {
                TextField("NIF/CIF", text: $taxId)
                    .textContentType(.organizationName)
                TextField(String(localized: "Direccion fiscal"), text: $address, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section(String(localized: "Contacto")) {
                TextField(String(localized: "Email"), text: $email)
                    .textContentType(.emailAddress)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    #endif
                TextField(String(localized: "Telefono"), text: $phone)
                    .textContentType(.telephoneNumber)
                    #if os(iOS)
                    .keyboardType(.phonePad)
                    #endif
            }

            Section(String(localized: "Cumplimiento normativo")) {
                Toggle(isOn: $verifactuEnabled) {
                    Label(String(localized: "Activar VeriFactu"), systemImage: "checkmark.shield")
                }

                if verifactuEnabled {
                    Text(String(localized: "Genera registros encadenados con hash SHA-256 y codigos QR segun el RD 1007/2023"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if issuer.verifactuSequence > 0 {
                        HStack {
                            Text(String(localized: "Secuencia"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("#\(issuer.verifactuSequence)")
                                .monospaced()
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "Guardar")) {
                    saveIssuer()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            loadIssuerData()
        }
    }

    // MARK: - Logo

    private var logoSection: some View {
        Section {
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, height: 80)

                    if issuer.logoData != nil {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "camera")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Data Binding

    private func loadIssuerData() {
        name = issuer.name
        ownerName = issuer.ownerName
        email = issuer.email
        phone = issuer.phone
        address = issuer.address
        taxId = issuer.taxId
        verifactuEnabled = issuer.verifactuEnabled
    }

    private func saveIssuer() {
        viewModel.updateIssuer(
            issuer,
            name: name,
            ownerName: ownerName,
            email: email,
            phone: phone,
            address: address,
            taxId: taxId,
            logoData: issuer.logoData,
            verifactuEnabled: verifactuEnabled
        )
    }
}

#Preview {
    iOSIssuerProfileView()
        .modelContainer(PersistenceController.preview)
        .environmentObject(try! SubscriptionService(storeConfiguration: .testing, startTasks: false))
}
