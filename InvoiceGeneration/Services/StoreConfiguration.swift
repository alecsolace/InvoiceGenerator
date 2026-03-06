import Foundation

enum StoreConfigurationError: LocalizedError, Equatable {
    case missingValue(String)
    case invalidProductIdentifier(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let key):
            return "Missing StoreKit configuration value for \(key)."
        case .invalidProductIdentifier(let identifier):
            return "Invalid StoreKit product identifier: \(identifier)."
        }
    }
}

struct StoreConfiguration: Equatable {
    static let monthlyProductIDKey = "StoreKitProMonthlyProductID"
    static let yearlyProductIDKey = "StoreKitProYearlyProductID"
    static let subscriptionGroupIDKey = "StoreKitSubscriptionGroupID"

    let monthlyProductID: String
    let yearlyProductID: String
    let subscriptionGroupID: String?

    var productIDs: [String] {
        [monthlyProductID, yearlyProductID]
    }

    static let testing = StoreConfiguration(
        monthlyProductID: "pro_monthly",
        yearlyProductID: "pro_yearly",
        subscriptionGroupID: nil
    )

    static func load(bundle: Bundle = .main) throws -> StoreConfiguration {
        try StoreConfiguration(
            monthlyProductID: requiredValue(for: monthlyProductIDKey, in: bundle),
            yearlyProductID: requiredValue(for: yearlyProductIDKey, in: bundle),
            subscriptionGroupID: optionalValue(for: subscriptionGroupIDKey, in: bundle)
        ).validated()
    }

    func validated() throws -> StoreConfiguration {
        for identifier in productIDs {
            if identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw StoreConfigurationError.invalidProductIdentifier(identifier)
            }

            if identifier.contains(where: \.isWhitespace) {
                throw StoreConfigurationError.invalidProductIdentifier(identifier)
            }
        }

        return self
    }

    private static func requiredValue(for key: String, in bundle: Bundle) throws -> String {
        guard let value = optionalValue(for: key, in: bundle) else {
            throw StoreConfigurationError.missingValue(key)
        }
        return value
    }

    private static func optionalValue(for key: String, in bundle: Bundle) -> String? {
        guard let rawValue = bundle.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
