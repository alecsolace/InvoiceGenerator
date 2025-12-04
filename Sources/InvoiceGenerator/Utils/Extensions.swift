import Foundation

/// Extension for decimal formatting
extension Decimal {
    var formattedAsCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: self as NSDecimalNumber) ?? "$0.00"
    }
}

/// Extension for date formatting
extension Date {
    var shortFormat: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: self)
    }
    
    var mediumFormat: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
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
