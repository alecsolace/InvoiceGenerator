import Foundation

/// Maps internal errors to localized, user-friendly messages.
///
/// Surfacing `error.localizedDescription` directly leaks technical, often
/// English-only text to users. These helpers translate known operations into
/// clear localized messages, falling back to a generic message for anything
/// unexpected.
enum UserFacingError {

    /// The data operation that failed, used to pick an appropriate message.
    enum Operation {
        case load
        case save
        case sync
        case delete
        case imageImport
        case purchase
    }

    /// Returns a localized, user-friendly message for the given operation.
    ///
    /// If the underlying error already provides a localized description via
    /// `LocalizedError` (e.g. a domain error with curated copy), that message is
    /// preferred. Otherwise a per-operation localized message is returned.
    static func message(for operation: Operation, error: Error? = nil) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription, !localized.isEmpty {
            return localized
        }

        switch operation {
        case .load:
            return String(localized: "We couldn't load your data. Please try again.")
        case .save:
            return String(localized: "We couldn't save your changes. Please try again.")
        case .sync:
            return String(localized: "We couldn't sync with iCloud. Your changes are saved on this device.")
        case .delete:
            return String(localized: "We couldn't delete this item. Please try again.")
        case .imageImport:
            return String(localized: "We couldn't read the selected image. Please try a clearer photo.")
        case .purchase:
            return String(localized: "We couldn't complete your purchase. Please try again.")
        }
    }
}
