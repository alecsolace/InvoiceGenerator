import Foundation
import SwiftData

/// Reusable monthly invoice preset tied to a client and issuer.
@Model
final class InvoiceTemplate {
    var id: UUID
    var name: String

    var client: Client?

    var issuer: Issuer?

    // Snapshot fields keep the template usable even when related entities change.
    var clientName: String
    var clientEmail: String
    var clientIdentificationNumber: String
    var clientAddress: String
    var dueDays: Int
    var ivaPercentage: Decimal
    var irpfPercentage: Decimal
    var notes: String

    @Relationship(deleteRule: .cascade, inverse: \InvoiceTemplateItem.template)
    var items: [InvoiceTemplateItem]

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        client: Client? = nil,
        issuer: Issuer? = nil,
        clientName: String = "",
        clientEmail: String = "",
        clientIdentificationNumber: String = "",
        clientAddress: String = "",
        dueDays: Int = 30,
        ivaPercentage: Decimal = 0,
        irpfPercentage: Decimal = 0,
        notes: String = "",
        items: [InvoiceTemplateItem] = []
    ) {
        self.id = id
        self.name = name
        self.client = client
        self.issuer = issuer
        self.clientName = clientName
        self.clientEmail = clientEmail
        self.clientIdentificationNumber = clientIdentificationNumber
        self.clientAddress = clientAddress
        self.dueDays = max(dueDays, 0)
        self.ivaPercentage = ivaPercentage
        self.irpfPercentage = irpfPercentage
        self.notes = notes
        self.items = items
        self.createdAt = Date()
        self.updatedAt = Date()

        if let client {
            captureClientSnapshot(from: client)
        }
    }

    func captureClientSnapshot(from client: Client) {
        clientName = client.name
        clientEmail = client.email
        clientIdentificationNumber = client.identificationNumber
        clientAddress = client.address
    }

    func updateTimestamp() {
        updatedAt = Date()
    }
}

@Model
final class InvoiceTemplateItem {
    var id: UUID
    var itemDescription: String
    var quantity: Int
    var unitPrice: Decimal
    var sortOrder: Int

    var template: InvoiceTemplate?

    init(
        id: UUID = UUID(),
        description: String,
        quantity: Int,
        unitPrice: Decimal,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.itemDescription = description
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.sortOrder = sortOrder
    }

    var total: Decimal {
        Decimal(quantity) * unitPrice
    }
}
