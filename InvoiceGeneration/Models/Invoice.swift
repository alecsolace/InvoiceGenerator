import Foundation
import SwiftData

/// Main Invoice model with SwiftData support
@Model
final class Invoice {
    var id: UUID = UUID()
    var invoiceNumber: String = ""
    var clientName: String = ""
    var clientEmail: String = ""
    var clientIdentificationNumber: String = ""
    var clientAddress: String = ""

    // Snapshot of issuer information captured at creation time.
    var issuerName: String = ""
    var issuerCode: String = ""
    var issuerOwnerName: String = ""
    var issuerEmail: String = ""
    var issuerPhone: String = ""
    var issuerAddress: String = ""
    var issuerTaxId: String = ""

    @Relationship(inverse: \Client.invoices)
    var client: Client?

    @Relationship(inverse: \Issuer.invoices)
    var issuer: Issuer?

    var issueDate: Date = Date()
    var dueDate: Date = Date()
    var status: InvoiceStatus = InvoiceStatus.draft
    var notes: String = ""
    var totalAmount: Decimal = 0
    var ivaPercentage: Decimal = 0
    var irpfPercentage: Decimal = 0

    // MARK: - VeriFACTU / Tax Compliance Fields

    /// Invoice type classification per RD 1619/2012 (F1, F2, R1-R5)
    var invoiceType: InvoiceType = InvoiceType.f1

    /// Tax regime key per AEAT specification (01 = general, 02 = export, etc.)
    var taxRegimeKey: TaxRegimeKey = TaxRegimeKey.general

    /// For corrective invoices (R1-R5): the number of the invoice being corrected
    var rectifiedInvoiceNumber: String = ""

    /// For corrective invoices (R1-R5): the date of the invoice being corrected
    var rectifiedInvoiceDate: Date?

    /// Correction method for rectificativas (by differences or substitution)
    var correctionMethod: CorrectionMethod?

    /// Operation description for VeriFACTU record
    var operationDescription: String = ""

    @Relationship(deleteRule: .cascade, inverse: \InvoiceItem.invoice)
    var items: [InvoiceItem]?

    /// Multi-rate IVA breakdown (desglose). Used when items carry different VAT rates.
    @Relationship(deleteRule: .cascade)
    var taxBreakdowns: [TaxBreakdown]?

    /// Associated VeriFACTU registry record (nil for non-VeriFACTU issuers or drafts)
    var verifactuRecord: VerifactuRecord?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var pdfLastGeneratedAt: Date?

    init(
        id: UUID = UUID(),
        invoiceNumber: String,
        clientName: String,
        clientEmail: String = "",
        clientIdentificationNumber: String = "",
        clientAddress: String = "",
        client: Client? = nil,
        issuer: Issuer? = nil,
        issuerName: String = "",
        issuerCode: String = "",
        issuerOwnerName: String = "",
        issuerEmail: String = "",
        issuerPhone: String = "",
        issuerAddress: String = "",
        issuerTaxId: String = "",
        issueDate: Date = Date(),
        dueDate: Date = Date().addingTimeInterval(30 * 24 * 60 * 60),
        status: InvoiceStatus = .draft,
        notes: String = "",
        ivaPercentage: Decimal = 0,
        irpfPercentage: Decimal = 0,
        invoiceType: InvoiceType = .f1,
        taxRegimeKey: TaxRegimeKey = .general,
        rectifiedInvoiceNumber: String = "",
        rectifiedInvoiceDate: Date? = nil,
        correctionMethod: CorrectionMethod? = nil,
        operationDescription: String = "",
        items: [InvoiceItem] = [],
        taxBreakdowns: [TaxBreakdown] = []
    ) {
        self.id = id
        self.invoiceNumber = invoiceNumber
        self.clientName = clientName
        self.clientEmail = clientEmail
        self.clientIdentificationNumber = clientIdentificationNumber
        self.clientAddress = clientAddress
        self.client = client
        self.issuer = issuer
        self.issuerName = issuerName
        self.issuerCode = issuerCode
        self.issuerOwnerName = issuerOwnerName
        self.issuerEmail = issuerEmail
        self.issuerPhone = issuerPhone
        self.issuerAddress = issuerAddress
        self.issuerTaxId = issuerTaxId
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.status = status
        self.notes = notes
        self.ivaPercentage = ivaPercentage
        self.irpfPercentage = irpfPercentage
        self.invoiceType = invoiceType
        self.taxRegimeKey = taxRegimeKey
        self.rectifiedInvoiceNumber = rectifiedInvoiceNumber
        self.rectifiedInvoiceDate = rectifiedInvoiceDate
        self.correctionMethod = correctionMethod
        self.operationDescription = operationDescription
        self.items = items
        self.taxBreakdowns = taxBreakdowns
        self.verifactuRecord = nil
        self.totalAmount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.pdfLastGeneratedAt = nil

        if let issuer, issuerName.isEmpty {
            captureIssuerSnapshot(from: issuer)
        }

        calculateTotal()
    }

    func calculateTotal() {
        let subtotal = itemsSubtotal
        let breakdowns = taxBreakdowns ?? []

        if !breakdowns.isEmpty {
            // Multi-IVA mode: total from breakdowns
            let totalIva = breakdowns.reduce(Decimal(0)) { $0 + $1.taxAmount + $1.surchargeAmount }
            let irpfAmount = (subtotal * irpfPercentage) / Decimal(100)
            totalAmount = subtotal + totalIva - irpfAmount
        } else {
            // Simple mode: single IVA percentage on full subtotal
            let ivaAmount = (subtotal * ivaPercentage) / Decimal(100)
            let irpfAmount = (subtotal * irpfPercentage) / Decimal(100)
            totalAmount = subtotal + ivaAmount - irpfAmount
        }
    }

    /// Rebuilds tax breakdowns from individual item VAT rates.
    /// Groups items by their `vatRate` and creates one `TaxBreakdown` per group.
    func rebuildTaxBreakdowns() {
        let lineItems = items ?? []
        guard lineItems.contains(where: { $0.vatRate > 0 || $0.vatRate == 0 }) else { return }

        let grouped = Dictionary(grouping: lineItems) { $0.vatRate }
        var newBreakdowns: [TaxBreakdown] = []

        for (rate, items) in grouped.sorted(by: { $0.key > $1.key }) {
            let base = items.reduce(Decimal(0)) { $0 + $1.total }
            let breakdown = TaxBreakdown(taxBase: base, taxRate: rate)
            newBreakdowns.append(breakdown)
        }

        taxBreakdowns = newBreakdowns
    }

    func updateTimestamp() {
        updatedAt = Date()
    }

    func captureIssuerSnapshot(from issuer: Issuer) {
        issuerName = issuer.name
        issuerCode = issuer.code
        issuerOwnerName = issuer.ownerName
        issuerEmail = issuer.email
        issuerPhone = issuer.phone
        issuerAddress = issuer.address
        issuerTaxId = issuer.taxId
    }

    var itemsSubtotal: Decimal {
        (items ?? []).reduce(0) { $0 + $1.total }
    }

    var ivaAmount: Decimal {
        let breakdowns = taxBreakdowns ?? []
        if !breakdowns.isEmpty {
            return breakdowns.reduce(Decimal(0)) { $0 + $1.taxAmount }
        }
        return (itemsSubtotal * ivaPercentage) / Decimal(100)
    }

    var irpfAmount: Decimal {
        (itemsSubtotal * irpfPercentage) / Decimal(100)
    }

    /// Total surcharge amount from equivalence surcharges across all breakdowns
    var surchargeAmount: Decimal {
        (taxBreakdowns ?? []).reduce(Decimal(0)) { $0 + $1.surchargeAmount }
    }

    /// Total tax amount (IVA + surcharge) for VeriFACTU record
    var totalTaxAmount: Decimal {
        ivaAmount + surchargeAmount
    }

    /// Whether this invoice uses multi-rate IVA breakdowns
    var usesMultiRateIVA: Bool {
        let breakdowns = taxBreakdowns ?? []
        return !breakdowns.isEmpty
    }

    /// Whether this is a corrective (rectificativa) invoice
    var isRectificativa: Bool {
        invoiceType.isRectificativa
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
        switch self {
        case .draft:
            return "Borrador"
        case .sent:
            return "Enviada"
        case .paid:
            return "Cobrada"
        case .overdue:
            return "Vencida"
        case .cancelled:
            return "Cancelada"
        }
    }
}

extension Invoice {
    /// Flag indicating if we previously generated a PDF for this invoice
    var hasGeneratedPDF: Bool { pdfLastGeneratedAt != nil }
}

/// Individual line item in an invoice
@Model
final class InvoiceItem {
    var id: UUID = UUID()
    var itemDescription: String = ""
    var quantity: Int = 0
    var unitPrice: Decimal = 0
    var total: Decimal = 0

    /// VAT rate for this specific item (21, 10, 4, or 0). Used when multi-rate IVA is enabled.
    var vatRate: Decimal = 21

    var invoice: Invoice?

    init(
        id: UUID = UUID(),
        description: String,
        quantity: Int,
        unitPrice: Decimal,
        vatRate: Decimal = 21
    ) {
        self.id = id
        self.itemDescription = description
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.total = Decimal(quantity) * unitPrice
        self.vatRate = vatRate
    }

    func updateTotal() {
        total = Decimal(quantity) * unitPrice
    }
}
