import Foundation
import SwiftData

/// Company or user profile information
@Model
final class CompanyProfile {
    var id: UUID
    var companyName: String
    var ownerName: String
    var email: String
    var phone: String
    var address: String
    var taxId: String
    var logoData: Data?
    
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        companyName: String,
        ownerName: String = "",
        email: String = "",
        phone: String = "",
        address: String = "",
        taxId: String = "",
        logoData: Data? = nil
    ) {
        self.id = id
        self.companyName = companyName
        self.ownerName = ownerName
        self.email = email
        self.phone = phone
        self.address = address
        self.taxId = taxId
        self.logoData = logoData
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func updateTimestamp() {
        updatedAt = Date()
    }
}
