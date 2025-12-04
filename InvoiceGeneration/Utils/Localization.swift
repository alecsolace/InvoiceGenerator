import Foundation
import SwiftUI

// MARK: - Localization Helpers

enum L10n {
    enum Common {
        static let add = LocalizedStringKey("action_add")
        static let cancel = LocalizedStringKey("action_cancel")
        static let create = LocalizedStringKey("action_create")
        static let delete = LocalizedStringKey("action_delete")
        static let deleteInvoice = LocalizedStringKey("action_delete_invoice")
        static let done = LocalizedStringKey("action_done")
        static let edit = LocalizedStringKey("action_edit")
        static let filter = LocalizedStringKey("action_filter")
        static let more = LocalizedStringKey("action_more")
        static let ok = LocalizedStringKey("action_ok")
        static let save = LocalizedStringKey("action_save")
    }

    enum Tabs {
        static let invoices = LocalizedStringKey("tab_invoices")
        static let profile = LocalizedStringKey("tab_profile")
    }

    enum InvoiceList {
        static let loading = LocalizedStringKey("invoice_list_loading")
        static let title = LocalizedStringKey("invoices_title")
        static let searchPrompt = LocalizedStringKey("search_invoices_prompt")
        static let emptyTitle = LocalizedStringKey("invoice_list_empty_title")
        static let emptyMessage = LocalizedStringKey("invoice_list_empty_message")
        static let createInvoice = LocalizedStringKey("invoice_list_create_invoice")
        static let addInvoice = LocalizedStringKey("invoice_list_add_invoice")
        static let allInvoices = LocalizedStringKey("invoice_list_all_invoices")
    }

    enum InvoiceForm {
        static let invoiceDetails = LocalizedStringKey("invoice_details_section")
        static let invoiceNumber = LocalizedStringKey("invoice_number_field")
        static let issueDate = LocalizedStringKey("issue_date_field")
        static let dueDate = LocalizedStringKey("due_date_field")
        static let clientInformation = LocalizedStringKey("client_information_section")
        static let clientName = LocalizedStringKey("client_name_field")
        static let email = LocalizedStringKey("email_field")
        static let address = LocalizedStringKey("address_field")
        static let newInvoiceTitle = LocalizedStringKey("new_invoice_title")
        static let editInvoiceTitle = LocalizedStringKey("edit_invoice_title")
    }

    enum InvoiceDetail {
        static let title = LocalizedStringKey("invoice_detail_title")
        static let information = LocalizedStringKey("invoice_information_section")
        static let status = LocalizedStringKey("status_label")
        static let items = LocalizedStringKey("items_section")
        static let total = LocalizedStringKey("total_label")
        static let notes = LocalizedStringKey("notes_section")
        static let generatePDF = LocalizedStringKey("generate_pdf_action")
    }

    enum InvoiceItemForm {
        static let itemDetails = LocalizedStringKey("item_details_section")
        static let description = LocalizedStringKey("description_field")
        static let unitPrice = LocalizedStringKey("unit_price_field")
        static let addItemTitle = LocalizedStringKey("add_item_title")
    }

    enum CompanyProfile {
        static let title = LocalizedStringKey("company_profile_title")
        static let companyInformation = LocalizedStringKey("company_information_section")
        static let companyName = LocalizedStringKey("company_name_field")
        static let ownerName = LocalizedStringKey("owner_name_field")
        static let taxId = LocalizedStringKey("tax_id_field")
        static let contactInformation = LocalizedStringKey("contact_information_section")
        static let phone = LocalizedStringKey("phone_field")
        static let saveProfile = LocalizedStringKey("save_profile_button")
        static let profileSavedTitle = LocalizedStringKey("profile_saved_title")
        static let profileSavedMessage = LocalizedStringKey("profile_saved_message")
    }

    enum PDF {
        static func title(_ invoiceNumber: String) -> String {
            String(
                localized: "pdf_title",
                defaultValue: "Invoice %@",
                comment: "Title for generated PDF",
                arguments: invoiceNumber
            )
        }

        static func fileName(_ invoiceNumber: String) -> String {
            String(
                localized: "invoice_file_name_format",
                defaultValue: "Invoice_%@",
                comment: "Filename for generated invoice PDF",
                arguments: invoiceNumber
            )
        }

        static let heading = String(localized: "pdf_heading", defaultValue: "INVOICE")
        static let invoiceNumber = String(localized: "pdf_invoice_number_label", defaultValue: "Invoice #:")
        static let issueDate = String(localized: "pdf_issue_date_label", defaultValue: "Issue Date:")
        static let dueDate = String(localized: "pdf_due_date_label", defaultValue: "Due Date:")
        static let status = String(localized: "pdf_status_label", defaultValue: "Status:")
        static let billTo = String(localized: "pdf_bill_to_label", defaultValue: "BILL TO:")
        static let description = String(localized: "pdf_description_header", defaultValue: "Description")
        static let quantity = String(localized: "pdf_quantity_header", defaultValue: "Qty")
        static let price = String(localized: "pdf_price_header", defaultValue: "Price")
        static let total = String(localized: "pdf_total_header", defaultValue: "Total")
        static let totalAmount = String(localized: "pdf_total_amount_label", defaultValue: "TOTAL:")
        static let notes = String(localized: "pdf_notes_label", defaultValue: "Notes:")
        static let authorFallback = String(localized: "pdf_author_fallback", defaultValue: "Invoice Generator")
    }

    enum Messages {
        static func quantity(_ quantity: Int) -> String {
            String(
                localized: "quantity_format",
                defaultValue: "Quantity: %d",
                comment: "Quantity label with current value",
                arguments: quantity
            )
        }

        static func itemQuantityPrice(quantity: Int, unitPrice: String) -> String {
            String(
                localized: "item_quantity_price_format",
                defaultValue: "%d × %@",
                comment: "Line item quantity and unit price",
                arguments: quantity,
                unitPrice
            )
        }
    }
}

extension InvoiceStatus {
    var localizedName: String {
        switch self {
        case .draft:
            String(localized: "status_draft", defaultValue: "Draft")
        case .sent:
            String(localized: "status_sent", defaultValue: "Sent")
        case .paid:
            String(localized: "status_paid", defaultValue: "Paid")
        case .overdue:
            String(localized: "status_overdue", defaultValue: "Overdue")
        case .cancelled:
            String(localized: "status_cancelled", defaultValue: "Cancelled")
        }
    }
}
