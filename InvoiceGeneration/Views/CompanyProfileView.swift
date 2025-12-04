import SwiftUI
import SwiftData

/// View for managing company profile
struct CompanyProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: CompanyProfileViewModel?
    
    @State private var companyName = ""
    @State private var ownerName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var taxId = ""
    @State private var showingSaveConfirmation = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.CompanyProfile.companyName, text: $companyName)

                    TextField(L10n.CompanyProfile.ownerName, text: $ownerName)

                    TextField(L10n.CompanyProfile.taxId, text: $taxId)
                } header: {
                    Text(L10n.CompanyProfile.companyInformation)
                }

                Section {
                    TextField(L10n.InvoiceForm.email, text: $email)
                    #if iOS
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    #endif
                    TextField(L10n.CompanyProfile.phone, text: $phone)
                    #if iOS
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    #endif
                    TextField(L10n.InvoiceForm.address, text: $address, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text(L10n.CompanyProfile.contactInformation)
                }

                Section {
                    Button(action: saveProfile) {
                        HStack {
                            Spacer()
                            Text(L10n.CompanyProfile.saveProfile)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(companyName.isEmpty)
                }
            }
            .navigationTitle(L10n.CompanyProfile.title)
            .alert(L10n.CompanyProfile.profileSavedTitle, isPresented: $showingSaveConfirmation) {
                Button(L10n.Common.ok, role: .cancel) {}
            } message: {
                Text(L10n.CompanyProfile.profileSavedMessage)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = CompanyProfileViewModel(modelContext: modelContext)
                loadProfile()
            }
        }
    }
    
    private func loadProfile() {
        guard let profile = viewModel?.profile else { return }
        
        companyName = profile.companyName
        ownerName = profile.ownerName
        email = profile.email
        phone = profile.phone
        address = profile.address
        taxId = profile.taxId
    }
    
    private func saveProfile() {
        viewModel?.saveProfile(
            companyName: companyName,
            ownerName: ownerName,
            email: email,
            phone: phone,
            address: address,
            taxId: taxId
        )
        showingSaveConfirmation = true
    }
}

#Preview {
    CompanyProfileView()
        .modelContainer(for: [Invoice.self, InvoiceItem.self, CompanyProfile.self])
}
