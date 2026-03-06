import Foundation
#if canImport(MessageUI)
import MessageUI
#endif
#if canImport(AppKit)
import AppKit
#endif

struct EmailDraft: Identifiable {
    let id = UUID()
    let recipients: [String]
    let subject: String
    let body: String
    let attachmentURL: URL
}

enum EmailService {
    static func makeDraft(invoice: Invoice, pdfURL: URL) -> EmailDraft {
        let recipients = invoice.clientEmail.isEmpty ? [] : [invoice.clientEmail]
        let subject = String(
            format: NSLocalizedString("Invoice %@", comment: "Email subject with invoice number"),
            invoice.invoiceNumber
        )
        let body = String(
            format: NSLocalizedString(
                "Hello,\n\nPlease find attached invoice %@.\n\nThank you.",
                comment: "Default email body when sending invoice"
            ),
            invoice.invoiceNumber
        )

        return EmailDraft(
            recipients: recipients,
            subject: subject,
            body: body,
            attachmentURL: pdfURL
        )
    }

    #if canImport(MessageUI)
    static var canComposeOnIOS: Bool {
        MFMailComposeViewController.canSendMail()
    }
    #endif

    #if canImport(AppKit)
    @discardableResult
    static func composeOnMac(_ draft: EmailDraft) -> Bool {
        guard let service = NSSharingService(named: .composeEmail) else {
            return false
        }

        service.recipients = draft.recipients
        service.subject = draft.subject
        service.perform(withItems: [draft.body, draft.attachmentURL])
        return true
    }
    #endif
}
