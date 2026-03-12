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
    var preferredTemplateID: UUID?

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
        preferredTemplateID: UUID? = nil
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
        self.preferredTemplateID = preferredTemplateID
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
