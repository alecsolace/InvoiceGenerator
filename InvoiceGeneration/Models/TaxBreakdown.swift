import Foundation
import SwiftData

/// Represents a single tax rate line in the invoice's tax breakdown (desglose de IVA).
/// An invoice may have multiple breakdowns when items carry different VAT rates.
@Model
final class TaxBreakdown {
    var id: UUID = UUID()

    /// Taxable base amount (base imponible) for this rate group
    var taxBase: Decimal = 0

    /// VAT rate applied (tipo impositivo): 21, 10, 4, or 0
    var taxRate: Decimal = 0

    /// VAT amount (cuota repercutida): taxBase * taxRate / 100
    var taxAmount: Decimal = 0

    /// Equivalence surcharge rate (recargo de equivalencia): 5.2, 1.4, 0.5, or 0
    var surchargeRate: Decimal = 0

    /// Equivalence surcharge amount: taxBase * surchargeRate / 100
    var surchargeAmount: Decimal = 0

    @Relationship(inverse: \Invoice.taxBreakdowns)
    var invoice: Invoice?

    // MARK: - Init

    init(
        id: UUID = UUID(),
        taxBase: Decimal,
        taxRate: Decimal,
        taxAmount: Decimal? = nil,
        surchargeRate: Decimal = 0,
        surchargeAmount: Decimal? = nil
    ) {
        self.id = id
        self.taxBase = taxBase
        self.taxRate = taxRate
        self.taxAmount = taxAmount ?? (taxBase * taxRate / Decimal(100))
        self.surchargeRate = surchargeRate
        self.surchargeAmount = surchargeAmount ?? (taxBase * surchargeRate / Decimal(100))
    }

    // MARK: - Public Methods

    func recalculate() {
        taxAmount = (taxBase * taxRate) / Decimal(100)
        surchargeAmount = (taxBase * surchargeRate) / Decimal(100)
    }

    /// Total tax contribution of this breakdown line (IVA + surcharge)
    var totalTax: Decimal {
        taxAmount + surchargeAmount
    }

    /// Grand total for this breakdown line (base + taxes)
    var lineTotal: Decimal {
        taxBase + taxAmount + surchargeAmount
    }
}
