import Foundation
import PDFKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Service for generating PDF invoices using PDFKit
final class PDFGeneratorService {
    
    // MARK: - Constants
    
    /// A4 page dimensions in points (210mm x 297mm)
    private static let pageWidth: CGFloat = 595
    private static let pageHeight: CGFloat = 842
    
    /// Generate a PDF document for an invoice
    static func generateInvoicePDF(
        invoice: Invoice,
        companyProfile: CompanyProfile?
    ) -> PDFDocument? {
        let pdfMetaData = [
            kCGPDFContextCreator: "InvoiceGenerator",
            kCGPDFContextAuthor: companyProfile?.companyName ?? "Invoice Generator",
            kCGPDFContextTitle: "Invoice \(invoice.invoiceNumber)"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 50
            
            // Draw company header
            if let companyProfile = companyProfile {
                yPosition = drawCompanyHeader(
                    companyProfile: companyProfile,
                    in: context,
                    pageRect: pageRect,
                    startY: yPosition
                )
            }
            
            yPosition += 30
            
            // Draw invoice details
            yPosition = drawInvoiceDetails(
                invoice: invoice,
                in: context,
                pageRect: pageRect,
                startY: yPosition
            )
            
            yPosition += 30
            
            // Draw client information
            yPosition = drawClientInfo(
                invoice: invoice,
                in: context,
                pageRect: pageRect,
                startY: yPosition
            )
            
            yPosition += 30
            
            // Draw items table
            yPosition = drawItemsTable(
                invoice: invoice,
                in: context,
                pageRect: pageRect,
                startY: yPosition
            )
            
            yPosition += 20
            
            // Draw total
            yPosition = drawTotal(
                invoice: invoice,
                in: context,
                pageRect: pageRect,
                startY: yPosition
            )
            
            // Draw notes if any
            if !invoice.notes.isEmpty {
                yPosition += 30
                _ = drawNotes(
                    invoice: invoice,
                    in: context,
                    pageRect: pageRect,
                    startY: yPosition
                )
            }
        }
        
        return PDFDocument(data: data)
    }
    
    // MARK: - Private Drawing Methods
    
    private static func drawCompanyHeader(
        companyProfile: CompanyProfile,
        in context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        var yPosition = startY
        
        let companyNameFont = UIFont.boldSystemFont(ofSize: 24)
        let companyNameAttributes: [NSAttributedString.Key: Any] = [
            .font: companyNameFont,
            .foregroundColor: UIColor.black
        ]
        
        let companyName = companyProfile.companyName as NSString
        companyName.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: companyNameAttributes)
        yPosition += 30
        
        let infoFont = UIFont.systemFont(ofSize: 12)
        let infoAttributes: [NSAttributedString.Key: Any] = [
            .font: infoFont,
            .foregroundColor: UIColor.darkGray
        ]
        
        if !companyProfile.address.isEmpty {
            let address = companyProfile.address as NSString
            address.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: infoAttributes)
            yPosition += 15
        }
        
        if !companyProfile.email.isEmpty {
            let email = companyProfile.email as NSString
            email.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: infoAttributes)
            yPosition += 15
        }
        
        if !companyProfile.phone.isEmpty {
            let phone = companyProfile.phone as NSString
            phone.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: infoAttributes)
            yPosition += 15
        }
        
        return yPosition
    }
    
    private static func drawInvoiceDetails(
        invoice: Invoice,
        in context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        var yPosition = startY
        
        let titleFont = UIFont.boldSystemFont(ofSize: 32)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        
        let title = "INVOICE" as NSString
        title.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: titleAttributes)
        yPosition += 45
        
        let labelFont = UIFont.boldSystemFont(ofSize: 12)
        let valueFont = UIFont.systemFont(ofSize: 12)
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.darkGray
        ]
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: UIColor.black
        ]
        
        // Invoice number
        let invoiceNumberLabel = "Invoice #:" as NSString
        invoiceNumberLabel.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: labelAttributes)
        let invoiceNumber = invoice.invoiceNumber as NSString
        invoiceNumber.draw(at: CGPoint(x: 150, y: yPosition), withAttributes: valueAttributes)
        yPosition += 20
        
        // Issue date
        let issueDateLabel = "Issue Date:" as NSString
        issueDateLabel.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: labelAttributes)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let issueDate = dateFormatter.string(from: invoice.issueDate) as NSString
        issueDate.draw(at: CGPoint(x: 150, y: yPosition), withAttributes: valueAttributes)
        yPosition += 20
        
        // Due date
        let dueDateLabel = "Due Date:" as NSString
        dueDateLabel.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: labelAttributes)
        let dueDate = dateFormatter.string(from: invoice.dueDate) as NSString
        dueDate.draw(at: CGPoint(x: 150, y: yPosition), withAttributes: valueAttributes)
        yPosition += 20
        
        // Status
        let statusLabel = "Status:" as NSString
        statusLabel.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: labelAttributes)
        let status = invoice.status.rawValue as NSString
        status.draw(at: CGPoint(x: 150, y: yPosition), withAttributes: valueAttributes)
        yPosition += 20
        
        return yPosition
    }
    
    private static func drawClientInfo(
        invoice: Invoice,
        in context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        var yPosition = startY
        
        let headerFont = UIFont.boldSystemFont(ofSize: 14)
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: UIColor.black
        ]
        
        let header = "BILL TO:" as NSString
        header.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: headerAttributes)
        yPosition += 25
        
        let infoFont = UIFont.systemFont(ofSize: 12)
        let infoAttributes: [NSAttributedString.Key: Any] = [
            .font: infoFont,
            .foregroundColor: UIColor.black
        ]
        
        let clientName = invoice.clientName as NSString
        clientName.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: infoAttributes)
        yPosition += 18
        
        if !invoice.clientEmail.isEmpty {
            let clientEmail = invoice.clientEmail as NSString
            clientEmail.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: infoAttributes)
            yPosition += 18
        }
        
        if !invoice.clientAddress.isEmpty {
            let clientAddress = invoice.clientAddress as NSString
            clientAddress.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: infoAttributes)
            yPosition += 18
        }
        
        return yPosition
    }
    
    private static func drawItemsTable(
        invoice: Invoice,
        in context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        var yPosition = startY
        
        let headerFont = UIFont.boldSystemFont(ofSize: 12)
        let cellFont = UIFont.systemFont(ofSize: 11)
        
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: UIColor.white
        ]
        
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: cellFont,
            .foregroundColor: UIColor.black
        ]
        
        // Draw table header
        let headerRect = CGRect(x: 50, y: yPosition, width: pageRect.width - 100, height: 30)
        context.cgContext.setFillColor(UIColor.darkGray.cgColor)
        context.cgContext.fill(headerRect)
        
        let descriptionHeader = "Description" as NSString
        descriptionHeader.draw(at: CGPoint(x: 60, y: yPosition + 8), withAttributes: headerAttributes)
        
        let quantityHeader = "Qty" as NSString
        quantityHeader.draw(at: CGPoint(x: 350, y: yPosition + 8), withAttributes: headerAttributes)
        
        let priceHeader = "Price" as NSString
        priceHeader.draw(at: CGPoint(x: 410, y: yPosition + 8), withAttributes: headerAttributes)
        
        let totalHeader = "Total" as NSString
        totalHeader.draw(at: CGPoint(x: 480, y: yPosition + 8), withAttributes: headerAttributes)
        
        yPosition += 35
        
        // Draw items
        for item in invoice.items {
            let description = item.itemDescription as NSString
            description.draw(at: CGPoint(x: 60, y: yPosition), withAttributes: cellAttributes)
            
            let quantity = "\(item.quantity)" as NSString
            quantity.draw(at: CGPoint(x: 350, y: yPosition), withAttributes: cellAttributes)
            
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = Locale.current
            
            let price = formatter.string(from: item.unitPrice as NSDecimalNumber) ?? "$0.00"
            (price as NSString).draw(at: CGPoint(x: 410, y: yPosition), withAttributes: cellAttributes)
            
            let total = formatter.string(from: item.total as NSDecimalNumber) ?? "$0.00"
            (total as NSString).draw(at: CGPoint(x: 480, y: yPosition), withAttributes: cellAttributes)
            
            yPosition += 25
            
            // Draw separator line
            context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            context.cgContext.setLineWidth(0.5)
            context.cgContext.move(to: CGPoint(x: 50, y: yPosition))
            context.cgContext.addLine(to: CGPoint(x: pageRect.width - 50, y: yPosition))
            context.cgContext.strokePath()
            
            yPosition += 5
        }
        
        return yPosition
    }
    
    private static func drawTotal(
        invoice: Invoice,
        in context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        let yPosition = startY
        
        let totalFont = UIFont.boldSystemFont(ofSize: 16)
        let totalAttributes: [NSAttributedString.Key: Any] = [
            .font: totalFont,
            .foregroundColor: UIColor.black
        ]
        
        let totalLabel = "TOTAL:" as NSString
        totalLabel.draw(at: CGPoint(x: 350, y: yPosition), withAttributes: totalAttributes)
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        
        let totalAmount = formatter.string(from: invoice.totalAmount as NSDecimalNumber) ?? "$0.00"
        (totalAmount as NSString).draw(at: CGPoint(x: 450, y: yPosition), withAttributes: totalAttributes)
        
        return yPosition + 25
    }
    
    private static func drawNotes(
        invoice: Invoice,
        in context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        var yPosition = startY
        
        let headerFont = UIFont.boldSystemFont(ofSize: 12)
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: UIColor.black
        ]
        
        let notesHeader = "Notes:" as NSString
        notesHeader.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: headerAttributes)
        yPosition += 20
        
        let notesFont = UIFont.systemFont(ofSize: 11)
        let notesAttributes: [NSAttributedString.Key: Any] = [
            .font: notesFont,
            .foregroundColor: UIColor.darkGray
        ]
        
        let notesRect = CGRect(x: 50, y: yPosition, width: pageRect.width - 100, height: 100)
        let notes = invoice.notes as NSString
        notes.draw(in: notesRect, withAttributes: notesAttributes)
        
        return yPosition + 100
    }
    
    /// Save PDF to file
    static func savePDF(_ pdfDocument: PDFDocument, fileName: String) -> URL? {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileURL = documentDirectory.appendingPathComponent("\(fileName).pdf")
        
        if pdfDocument.write(to: fileURL) {
            return fileURL
        }
        
        return nil
    }
}
