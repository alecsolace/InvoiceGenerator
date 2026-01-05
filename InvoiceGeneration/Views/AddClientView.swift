import SwiftUI
import SwiftData

/// View for creating a new client
struct AddClientView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ClientViewModel

    var onSave: ((Client) -> Void)?

    @State private var name = ""
    @State private var email = ""
    @State private var address = ""
    @State private var identificationNumber = ""
    @State private var accentColor = Color(hex: Client.defaultAccentHex) ?? .blue

    var body: some View {
        NavigationStack {
            Form {
                Section("Client Details") {
                    TextField("Name", text: $name)

                    TextField("Email", text: $email)
#if os(iOS)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
#endif
                    TextField(
                        String(localized: "Identification Number", comment: "Label for client identification number field"),
                        text: $identificationNumber
                    )

                    TextField("Address", text: $address, axis: .vertical)
                        .lineLimit(3...6)

                    ColorPicker("Accent Color", selection: $accentColor, supportsOpacity: false)
                }
            }
            .navigationTitle("New Client")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveClient() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func saveClient() {
        let accentHex = accentColor.hexString ?? Client.defaultAccentHex
        guard let client = viewModel.createClient(
            name: name,
            email: email,
            address: address,
            identificationNumber: identificationNumber,
            accentColorHex: accentHex
        ) else {
            return
        }

        onSave?(client)
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self,
        configurations: config
    )

    let viewModel = ClientViewModel(modelContext: container.mainContext)

    return AddClientView(viewModel: viewModel)
}
