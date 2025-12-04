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
                Section("Company Information") {
                    TextField("Company Name", text: $companyName)
                    
                    TextField("Owner Name", text: $ownerName)
                    
                    TextField("Tax ID", text: $taxId)
                }
                
                Section("Contact Information") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    
                    TextField("Address", text: $address, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button(action: saveProfile) {
                        HStack {
                            Spacer()
                            Text("Save Profile")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(companyName.isEmpty)
                }
            }
            .navigationTitle("Company Profile")
            .alert("Profile Saved", isPresented: $showingSaveConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your company profile has been saved successfully.")
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
