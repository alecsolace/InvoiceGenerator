import Foundation

/// Extension for decimal formatting
extension Decimal {
    var formattedAsCurrency: String {
        Formatters.currency.string(from: self as NSDecimalNumber) ?? "$0.00"
    }

    var formattedAsPercent: String {
        let percentValue = self / Decimal(100)
        return Formatters.percent.string(from: percentValue as NSDecimalNumber) ?? "\(self)%"
    }
}

/// Extension for date formatting
extension Date {
    var shortFormat: String {
        Formatters.shortDate.string(from: self)
    }

    var mediumFormat: String {
        Formatters.mediumDate.string(from: self)
    }

    var monthYearFormat: String {
        Formatters.monthYear.string(from: self)
    }

    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    func addingMonths(_ value: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: value, to: self) ?? self
    }

    func addingDays(_ value: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: value, to: self) ?? self
    }
}

/// Extension for invoice number generation
extension String {
    static func generateInvoiceNumber() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMM"
        let datePrefix = dateFormatter.string(from: Date())
        let randomSuffix = Int.random(in: 1000...9999)
        return "INV-\(datePrefix)-\(randomSuffix)"
    }
}
