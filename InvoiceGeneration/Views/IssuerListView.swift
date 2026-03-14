import SwiftUI
import SwiftData

struct IssuerListView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(IssuerSelectionStore.appStorageKey) private var selectedIssuerStorage = IssuerSelectionStore.allIssuersToken

    @State private var viewModel: IssuerViewModel?
    @State private var editorState: IssuerEditorState?
    @State private var showDeleteBlockedAlert = false
    @State private var deleteBlockedMessage = ""

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    if viewModel.isLoading {
                        ProgressView("Loading emitters...")
                    } else if viewModel.issuers.isEmpty {
                        emptyState
                    } else {
                        issuerList(viewModel)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Emitters")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorState = .create
                    } label: {
                        Label("Add Emitter", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editorState) { state in
                if let viewModel {
                    IssuerEditorView(
                        mode: state,
                        viewModel: viewModel,
                        onSaved: { issuer in
                            selectedIssuerStorage = IssuerSelectionStore.storageValue(from: issuer.id)
                        }
                    )
                }
            }
            .alert("Cannot Delete Emitter", isPresented: $showDeleteBlockedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteBlockedMessage)
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 58))
                .foregroundStyle(.secondary)

            Text("No Emitters")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create an emitter to issue invoices and track history by sender.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                editorState = .create
            } label: {
                Label("Create Emitter", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func issuerList(_ viewModel: IssuerViewModel) -> some View {
        List {
            activeContextBanner(viewModel)

            ForEach(viewModel.issuers) { issuer in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(issuer.name)
                            .font(.headline)
                        Spacer()
                        if isActive(issuer) {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    Text("Code: \(issuer.code)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

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
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedIssuerStorage = IssuerSelectionStore.storageValue(from: issuer.id)
                }
                .platformRowActions(
                    onSetActive: {
                        selectedIssuerStorage = IssuerSelectionStore.storageValue(from: issuer.id)
                    },
                    onEdit: {
                        editorState = .edit(issuer)
                    },
                    onDelete: {
                        if !viewModel.deleteIssuer(issuer), let error = viewModel.errorMessage {
                            deleteBlockedMessage = error
                            showDeleteBlockedAlert = true
                        }

                        if selectedIssuerStorage == issuer.id.uuidString {
                            selectedIssuerStorage = IssuerSelectionStore.allIssuersToken
                        }
                    }
                )
            }
        }
    }

    private func activeContextBanner(_ viewModel: IssuerViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active emitter context")
                .font(.headline)

            if let selectedID = IssuerSelectionStore.issuerID(from: selectedIssuerStorage),
               let issuer = viewModel.issuers.first(where: { $0.id == selectedID }) {
                Text("\(issuer.name) (\(issuer.code)) is selected globally for dashboards and invoice creation.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("All emitters are selected in global context.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Use All Emitters") {
                selectedIssuerStorage = IssuerSelectionStore.allIssuersToken
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 6)
    }

    private func isActive(_ issuer: Issuer) -> Bool {
        IssuerSelectionStore.issuerID(from: selectedIssuerStorage) == issuer.id
    }
}

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

private struct IssuerEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: IssuerEditorState
    @Bindable var viewModel: IssuerViewModel
    let onSaved: (Issuer) -> Void

    @State private var name = ""
    @State private var code = ""
    @State private var ownerName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var taxId = ""
    @State private var defaultNotes = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Emitter") {
                    TextField("Name", text: $name)
                    TextField("Code", text: $code)
#if os(iOS)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
#endif
                }

                Section("Contact") {
                    TextField("Owner Name", text: $ownerName)
                    TextField("Email", text: $email)
#if os(iOS)
                        .keyboardType(.emailAddress)
#endif
                    TextField("Phone", text: $phone)
                    TextField("Tax ID", text: $taxId)
                    TextField("Address", text: $address, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Invoice Defaults") {
                    TextField("Default Notes", text: $defaultNotes, axis: .vertical)
                        .lineLimit(3...5)
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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
            return "New Emitter"
        case .edit:
            return "Edit Emitter"
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
    }

    private func persist() {
        switch mode {
        case .create:
            guard let issuer = viewModel.createIssuer(
                name: name,
                code: code,
                ownerName: ownerName,
                email: email,
                phone: phone,
                address: address,
                taxId: taxId,
                defaultNotes: defaultNotes
            ) else {
                errorMessage = viewModel.errorMessage
                return
            }
            onSaved(issuer)
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
                defaultNotes: defaultNotes
            )
            guard success else {
                errorMessage = viewModel.errorMessage
                return
            }
            onSaved(issuer)
            dismiss()
        }
    }
}

private extension View {
    @ViewBuilder
    func platformRowActions(
        onSetActive: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        #if os(iOS)
        self.swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onSetActive) {
                Label("Set Active", systemImage: "checkmark.circle")
            }
            .tint(.green)

            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        #else
        self.contextMenu {
            Button(action: onSetActive) {
                Label("Set Active", systemImage: "checkmark.circle")
            }
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        #endif
    }
}

#Preview {
    IssuerListView()
        .modelContainer(for: [Invoice.self, InvoiceItem.self, CompanyProfile.self, Client.self, Issuer.self])
}
