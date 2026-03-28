import Foundation
import SwiftData
import SwiftUI
import CoreGraphics

/// Client model persisted with SwiftData
@Model
final class Client {
    var id: UUID = UUID()
    var name: String = ""
    var email: String = ""
    var address: String = ""
    var identificationNumber: String = ""
    var accentColorHex: String = Client.defaultAccentHex
    /// When 0, the app-wide quick invoice default is used.
    var defaultDueDays: Int = 0
    var defaultIVAPercentage: Decimal?
    var defaultIRPFPercentage: Decimal?
    var defaultNotes: String = ""
    /// Custom invoice code prefix for this client. Empty string means fall back to the issuer code.
    var invoiceCode: String = ""
    /// Next sequence number to use when generating invoice numbers for this client.
    var nextInvoiceSequence: Int = 1
    var preferredTemplateID: UUID?

    /// ISO 3166-1 alpha-2 country code (e.g. "ES", "FR", "US"). Defaults to Spain.
    var countryCode: String = "ES"

    /// Client location classification for tax purposes (national, intra-EU, extra-EU)
    var locationType: ClientLocationType = ClientLocationType.national

    @Relationship(deleteRule: .nullify)
    var invoices: [Invoice]?

    @Relationship(deleteRule: .nullify)
    var templates: [InvoiceTemplate]?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    static let defaultAccentHex = "#1F5FB8"

    init(
        id: UUID = UUID(),
        name: String,
        email: String = "",
        address: String = "",
        identificationNumber: String = "",
        accentColorHex: String = Client.defaultAccentHex,
        defaultDueDays: Int = 0,
        defaultIVAPercentage: Decimal? = nil,
        defaultIRPFPercentage: Decimal? = nil,
        defaultNotes: String = "",
        invoiceCode: String = "",
        nextInvoiceSequence: Int = 1,
        preferredTemplateID: UUID? = nil,
        countryCode: String = "ES",
        locationType: ClientLocationType = .national
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.address = address
        self.identificationNumber = identificationNumber
        self.accentColorHex = accentColorHex
        self.defaultDueDays = max(defaultDueDays, 0)
        self.defaultIVAPercentage = defaultIVAPercentage
        self.defaultIRPFPercentage = defaultIRPFPercentage
        self.defaultNotes = defaultNotes
        self.invoiceCode = invoiceCode
        self.nextInvoiceSequence = max(nextInvoiceSequence, 1)
        self.preferredTemplateID = preferredTemplateID
        self.countryCode = countryCode
        self.locationType = locationType
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func updateTimestamp() {
        updatedAt = Date()
    }

    var accentColor: Color {
        Color(hex: accentColorHex) ?? Color(hex: Client.defaultAccentHex) ?? .blue
    }

    private static let fallbackAccentColor: CGColor = {
        Color(hex: Client.defaultAccentHex)?.cgColorRepresentation ?? CGColor(gray: 0.12, alpha: 1)
    }()

    var accentCGColor: CGColor {
        CGColor.fromHex(accentColorHex, defaultColor: Client.fallbackAccentColor)
    }
}
