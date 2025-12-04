import Foundation
import SwiftData
import Observation

/// ViewModel for managing company profile using MVVM pattern
@Observable
final class CompanyProfileViewModel {
    private var modelContext: ModelContext
    
    var profile: CompanyProfile?
    var isLoading = false
    var errorMessage: String?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchProfile()
    }
    
    /// Fetch company profile
    func fetchProfile() {
        isLoading = true
        errorMessage = nil
        
        do {
            let descriptor = FetchDescriptor<CompanyProfile>()
            let profiles = try modelContext.fetch(descriptor)
            profile = profiles.first
        } catch {
            errorMessage = String(
                localized: "profile_fetch_error",
                defaultValue: "Failed to fetch profile: %@",
                comment: "Error shown when company profile cannot be loaded",
                arguments: error.localizedDescription
            )
        }
        
        isLoading = false
    }
    
    /// Create or update company profile
    func saveProfile(
        companyName: String,
        ownerName: String = "",
        email: String = "",
        phone: String = "",
        address: String = "",
        taxId: String = "",
        logoData: Data? = nil
    ) {
        if let existingProfile = profile {
            // Update existing profile
            existingProfile.companyName = companyName
            existingProfile.ownerName = ownerName
            existingProfile.email = email
            existingProfile.phone = phone
            existingProfile.address = address
            existingProfile.taxId = taxId
            if let logoData = logoData {
                existingProfile.logoData = logoData
            }
            existingProfile.updateTimestamp()
        } else {
            // Create new profile
            let newProfile = CompanyProfile(
                companyName: companyName,
                ownerName: ownerName,
                email: email,
                phone: phone,
                address: address,
                taxId: taxId,
                logoData: logoData
            )
            modelContext.insert(newProfile)
            profile = newProfile
        }
        
        saveContext()
    }
    
    /// Update logo
    func updateLogo(_ logoData: Data?) {
        guard let profile = profile else { return }
        profile.logoData = logoData
        profile.updateTimestamp()
        saveContext()
    }
    
    // MARK: - Private Methods
    
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = String(
                localized: "profile_save_error",
                defaultValue: "Failed to save profile: %@",
                comment: "Error shown when saving the company profile fails",
                arguments: error.localizedDescription
            )
        }
    }
}
