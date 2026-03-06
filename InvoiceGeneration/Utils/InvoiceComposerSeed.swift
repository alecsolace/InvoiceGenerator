import Foundation

enum InvoiceComposerSeed: Identifiable {
    case quick
    case client(Client)
    case template(InvoiceTemplate)
    case duplicate(Invoice)

    var id: String {
        switch self {
        case .quick:
            return "quick"
        case .client(let client):
            return "client-\(client.id.uuidString)"
        case .template(let template):
            return "template-\(template.id.uuidString)"
        case .duplicate(let invoice):
            return "duplicate-\(invoice.id.uuidString)"
        }
    }

    var startsOnAmountsStep: Bool {
        if case .duplicate = self {
            return true
        }
        return false
    }
}
