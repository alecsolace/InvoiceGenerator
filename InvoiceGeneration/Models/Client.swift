import Foundation
import SwiftData
import SwiftUI
import CoreGraphics

/// Client model persisted with SwiftData
@Model
final class Client {
    var id: UUID
    var name: String
    var email: String
    var address: String
    var accentColorHex: String

    @Relationship(deleteRule: .nullify)
    var invoices: [Invoice]?

    var createdAt: Date
    var updatedAt: Date

    static let defaultAccentHex = "#1F5FB8"

    init(
        id: UUID = UUID(),
        name: String,
        email: String = "",
        address: String = "",
        accentColorHex: String = Client.defaultAccentHex
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.address = address
        self.accentColorHex = accentColorHex
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func updateTimestamp() {
        updatedAt = Date()
    }

    var accentColor: Color {
        Color(hex: accentColorHex) ?? Color(hex: Client.defaultAccentHex) ?? .blue
    }

    var accentCGColor: CGColor {
        CGColor.fromHex(accentColorHex, defaultColor: CGColor(accentColor: Client.defaultAccentHex))
    }
}

private extension CGColor {
    init(accentColor hex: String) {
        self = CGColor.fromHex(hex, defaultColor: CGColor(gray: 0.12, alpha: 1))
    }
}
