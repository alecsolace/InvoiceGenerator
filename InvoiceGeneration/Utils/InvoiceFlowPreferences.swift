import Foundation

enum QuickInvoiceAfterSaveAction: String, CaseIterable, Identifiable {
    case close
    case openDetail
    case generatePDF

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .close:
            return "Volver"
        case .openDetail:
            return "Abrir detalle"
        case .generatePDF:
            return "Generar PDF"
        }
    }
}

enum InvoiceFlowPreferences {
    static let defaultDueDaysKey = "quickInvoice.defaultDueDays"
    static let afterSaveActionKey = "quickInvoice.afterSaveAction"
    static let skipOnboardingForUITestsKey = "uiTests.skipOnboarding"

    static let defaultDueDays = 30
    static let defaultAfterSaveAction = QuickInvoiceAfterSaveAction.close.rawValue
}
