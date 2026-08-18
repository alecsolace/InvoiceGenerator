import Foundation

/// Centralized, cached formatter instances.
///
/// `NumberFormatter` and `DateFormatter` are expensive to allocate, so creating
/// them inline (e.g. per cell render) hurts scroll performance. These shared
/// instances preserve the exact formatting/locale behavior used previously while
/// avoiding repeated allocation.
enum Formatters {

    // MARK: - Number Formatters

    /// Currency formatter pinned to Spanish/EUR formatting (comma decimal
    /// separator, € symbol), independent of the device's region setting.
    /// The app's fiscal documents (invoices, VeriFACTU) are always EUR, so
    /// following `Locale.current` here would render `$1,234.56`-style output
    /// on a non-Spanish-region device rather than `1.234,56 €`.
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "es_ES")
        formatter.currencyCode = "EUR"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// Percent formatter (0–2 fraction digits) following the current locale.
    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.locale = Locale.current
        return formatter
    }()

    /// Decimal formatter for editable prices: no grouping separator, 0–2 fraction digits.
    static let editablePrice: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.groupingSeparator = ""
        return formatter
    }()

    // MARK: - Date Formatters

    /// Short date style (e.g. `5/22/26`).
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    /// Medium date style (e.g. `May 22, 2026`).
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    /// Medium date with short time (e.g. `May 22, 2026 at 9:41 AM`).
    static let mediumDateShortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// Full month + year (e.g. `May 2026`).
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    /// Abbreviated month + year (e.g. `May 2026`).
    static let abbreviatedMonthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()
}
