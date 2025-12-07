import Foundation
import SwiftData

/// Main Invoice model with SwiftData support
@Model
final class Invoice {
    var id: UUID
    var invoiceNumber: String
    var clientName: String
    var clientEmail: String
    var clientAddress: String
    @Relationship(inverse: \Client.invoices)
    var client: Client?
    var issueDate: Date
    var dueDate: Date
    var status: InvoiceStatus
    var notes: String
    var totalAmount: Decimal
    
    @Relationship(deleteRule: .cascade, inverse: \InvoiceItem.invoice)
    var items: [InvoiceItem]
    
    var createdAt: Date
    var updatedAt: Date
    var pdfLastGeneratedAt: Date?
    
    init(
        id: UUID = UUID(),
        invoiceNumber: String,
        clientName: String,
        clientEmail: String = "",
        clientAddress: String = "",
        client: Client? = nil,
        issueDate: Date = Date(),
        dueDate: Date = Date().addingTimeInterval(30 * 24 * 60 * 60),
        status: InvoiceStatus = .draft,
        notes: String = "",
        items: [InvoiceItem] = []
    ) {
        self.id = id
        self.invoiceNumber = invoiceNumber
        self.clientName = clientName
        self.clientEmail = clientEmail
        self.clientAddress = clientAddress
        self.client = client
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.status = status
        self.notes = notes
        self.items = items
        self.totalAmount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.pdfLastGeneratedAt = nil

        calculateTotal()
    }
    
    func calculateTotal() {
        totalAmount = items.reduce(0) { $0 + $1.total }
    }
    
    func updateTimestamp() {
        updatedAt = Date()
    }
}

/// Invoice status enumeration
enum InvoiceStatus: String, Codable, CaseIterable {
    case draft = "Draft"
    case sent = "Sent"
    case paid = "Paid"
    case overdue = "Overdue"
    case cancelled = "Cancelled"
}

extension InvoiceStatus {
    /// Localized title for display purposes
    var localizedTitle: String {
        NSLocalizedString(rawValue, comment: "Invoice status label")
    }
}

extension Invoice {
    /// Flag indicating if we previously generated a PDF for this invoice
    var hasGeneratedPDF: Bool { pdfLastGeneratedAt != nil }
}

/// Individual line item in an invoice
@Model
final class InvoiceItem {
    var id: UUID
    var itemDescription: String
    var quantity: Int
    var unitPrice: Decimal
    var total: Decimal
    
    var invoice: Invoice?
    
    init(
        id: UUID = UUID(),
        description: String,
        quantity: Int,
        unitPrice: Decimal
    ) {
        self.id = id
        self.itemDescription = description
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.total = Decimal(quantity) * unitPrice
    }
    
    func updateTotal() {
        total = Decimal(quantity) * unitPrice
    }
}
