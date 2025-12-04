import Foundation
import PDFKit
import CoreGraphics
import CoreText

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
        let pdfMetaData: [CFString: Any] = [
            kCGPDFContextCreator: "InvoiceGenerator",
            kCGPDFContextAuthor: companyProfile?.companyName ?? L10n.PDF.authorFallback,
            kCGPDFContextTitle: L10n.PDF.title(invoice.invoiceNumber)
        ]
        
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        guard
            let consumer = CGDataConsumer(data: data as CFMutableData),
            let context = CGContext(
                consumer: consumer,
                mediaBox: &mediaBox,
                pdfMetaData as CFDictionary
            )
        else {
            return nil
        }
        
        context.beginPDFPage(nil)
        context.saveGState()
        context.translateBy(x: 0, y: pageHeight)
        context.scaleBy(x: 1, y: -1)
        context.textMatrix = .identity
        
        var yPosition: CGFloat = 50
        let pageRect = mediaBox
        
        if let companyProfile = companyProfile {
            yPosition = drawCompanyHeader(
                companyProfile: companyProfile,
                in: context,
                pageRect: pageRect,
                startY: yPosition
            )
        }
        
        yPosition += 30
        
        yPosition = drawInvoiceDetails(
            invoice: invoice,
            in: context,
            pageRect: pageRect,
            startY: yPosition
        )
        
        yPosition += 30
        
        yPosition = drawClientInfo(
            invoice: invoice,
            in: context,
            pageRect: pageRect,
            startY: yPosition
        )
        
        yPosition += 30
        
        yPosition = drawItemsTable(
            invoice: invoice,
            in: context,
            pageRect: pageRect,
            startY: yPosition
        )
        
        yPosition += 20
        
        yPosition = drawTotal(
            invoice: invoice,
            in: context,
            pageRect: pageRect,
            startY: yPosition
        )
        
        if !invoice.notes.isEmpty {
            yPosition += 30
            _ = drawNotes(
                invoice: invoice,
                in: context,
                pageRect: pageRect,
                startY: yPosition
            )
        }
        
        context.restoreGState()
        context.endPDFPage()
        context.closePDF()
        
        return PDFDocument(data: data as Data)
    }
    
    // MARK: - Private Drawing Methods
    
    private static func drawCompanyHeader(
        companyProfile: CompanyProfile,
        in context: CGContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        var yPosition = startY
        
        drawText(
            companyProfile.companyName,
            style: .bold(size: 24),
            at: CGPoint(x: 50, y: yPosition),
            in: context
        )
        yPosition += 30
        
        if !companyProfile.address.isEmpty {
            drawText(
                companyProfile.address,
                style: .body,
                at: CGPoint(x: 50, y: yPosition),
                in: context
            )
            yPosition += 15
        }
        
        if !companyProfile.email.isEmpty {
            drawText(
                companyProfile.email,
                style: .body,
                at: CGPoint(x: 50, y: yPosition),
                in: context
            )
            yPosition += 15
        }
        
        if !companyProfile.phone.isEmpty {
            drawText(
                companyProfile.phone,
                style: .body,
                at: CGPoint(x: 50, y: yPosition),
                in: context
            )
            yPosition += 15
        }
        
        return yPosition
    }
    
    private static func drawInvoiceDetails(
        invoice: Invoice,
        in context: CGContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        var yPosition = startY
        
        drawText(
            L10n.PDF.heading,
            style: .bold(size: 32),
            at: CGPoint(x: 50, y: yPosition),
            in: context
        )
        yPosition += 45
        let labelStyle = PDFTextStyle(font: PDFFont.bold(12), color: PDFColor.darkGray)
        let valueStyle = PDFTextStyle(font: PDFFont.regular(12), color: PDFColor.black)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        // Invoice number
        drawText(
            L10n.PDF.invoiceNumber,
            style: labelStyle,
            at: CGPoint(x: 50, y: yPosition),
            in: context
        )
        drawText(
            invoice.invoiceNumber,
            style: valueStyle,
            at: CGPoint(x: 150, y: yPosition),
            in: context
        )
        yPosition += 20
        
        // Issue date
        drawText(
            L10n.PDF.issueDate,
            style: labelStyle,
            at: CGPoint(x: 50, y: yPosition),
            in: context
        )
        drawText(
            formatter.string(from: invoice.issueDate),
            style: valueStyle,
            at: CGPoint(x: 150, y: yPosition),
            in: context
        )
        yPosition += 20
        
        // Due date
        drawText(
            L10n.PDF.dueDate,
            style: labelStyle,
            at: CGPoint(x: 50, y: yPosition),
            in: context
        )
        drawText(
            formatter.string(from: invoice.dueDate),
            style: valueStyle,
            at: CGPoint(x: 150, y: yPosition),
            in: context
        )
        yPosition += 20
        
        // Status
        drawText(
            L10n.PDF.status,
            style: labelStyle,
            at: CGPoint(x: 50, y: yPosition),
            in: context
        )
        drawText(
            invoice.status.localizedName,
            style: valueStyle,
            at: CGPoint(x: 150, y: yPosition),
            in: context
        )
        yPosition += 20
        
        return yPosition
    }
    
    private static func drawClientInfo(
        invoice: Invoice,
        in context: CGContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        var yPosition = startY
        
        drawText(
            L10n.PDF.billTo,
            style: .bold(size: 14),
            at: CGPoint(x: 50, y: yPosition),
            in: context
        )
        yPosition += 25
        
        let infoStyle = PDFTextStyle(font: PDFFont.regular(12), color: PDFColor.black)
        
        drawText(
            invoice.clientName,
            style: infoStyle,
            at: CGPoint(x: 50, y: yPosition),
            in: context
        )
        yPosition += 18
        
        if !invoice.clientEmail.isEmpty {
            drawText(
                invoice.clientEmail,
                style: infoStyle,
                at: CGPoint(x: 50, y: yPosition),
                in: context
            )
            yPosition += 18
        }
        
        if !invoice.clientAddress.isEmpty {
            drawText(
                invoice.clientAddress,
                style: infoStyle,
                at: CGPoint(x: 50, y: yPosition),
                in: context
            )
            yPosition += 18
        }
        
        return yPosition
    }
    
    private static func drawItemsTable(
        invoice: Invoice,
        in context: CGContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        var yPosition = startY
        let headerStyle = PDFTextStyle(font: PDFFont.bold(12), color: PDFColor.white)
        let cellStyle = PDFTextStyle(font: PDFFont.regular(11), color: PDFColor.black)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        
        // Draw table header
        let headerRect = CGRect(x: 50, y: yPosition, width: pageRect.width - 100, height: 30)
        context.setFillColor(PDFColor.tableHeader)
        context.fill(headerRect)
        
        drawText(L10n.PDF.description, style: headerStyle, at: CGPoint(x: 60, y: yPosition + 8), in: context)
        drawText(L10n.PDF.quantity, style: headerStyle, at: CGPoint(x: 350, y: yPosition + 8), in: context)
        drawText(L10n.PDF.price, style: headerStyle, at: CGPoint(x: 410, y: yPosition + 8), in: context)
        drawText(L10n.PDF.total, style: headerStyle, at: CGPoint(x: 480, y: yPosition + 8), in: context)
        
        yPosition += 35
        
        // Draw items
        for item in invoice.items {
            drawText(
                item.itemDescription,
                style: cellStyle,
                at: CGPoint(x: 60, y: yPosition),
                in: context
            )
            
            drawText(
                "\(item.quantity)",
                style: cellStyle,
                at: CGPoint(x: 350, y: yPosition),
                in: context
            )
            
            let price = formatter.string(from: item.unitPrice as NSDecimalNumber) ??
                (formatter.string(from: 0) ?? "")
            drawText(
                price,
                style: cellStyle,
                at: CGPoint(x: 410, y: yPosition),
                in: context
            )
            
            let total = formatter.string(from: item.total as NSDecimalNumber) ??
                (formatter.string(from: 0) ?? "")
            drawText(
                total,
                style: cellStyle,
                at: CGPoint(x: 480, y: yPosition),
                in: context
            )
            
            yPosition += 25
            
            // Draw separator line
            context.setStrokeColor(PDFColor.lightGray)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: 50, y: yPosition))
            context.addLine(to: CGPoint(x: pageRect.width - 50, y: yPosition))
            context.strokePath()
            
            yPosition += 5
        }
        
        return yPosition
    }
    
    private static func drawTotal(
        invoice: Invoice,
        in context: CGContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        let yPosition = startY
        
        let totalStyle = PDFTextStyle(font: PDFFont.bold(16), color: PDFColor.black)
        drawText(L10n.PDF.totalAmount, style: totalStyle, at: CGPoint(x: 350, y: yPosition), in: context)
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        
        let totalAmount = formatter.string(from: invoice.totalAmount as NSDecimalNumber) ??
            (formatter.string(from: 0) ?? "")
        drawText(totalAmount, style: totalStyle, at: CGPoint(x: 450, y: yPosition), in: context)
        
        return yPosition + 25
    }
    
    private static func drawNotes(
        invoice: Invoice,
        in context: CGContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        var yPosition = startY
        
        drawText(L10n.PDF.notes, style: .bold(size: 12), at: CGPoint(x: 50, y: yPosition), in: context)
        yPosition += 20
        
        let notesRect = CGRect(x: 50, y: yPosition, width: pageRect.width - 100, height: 100)
        drawMultilineText(
            invoice.notes,
            style: PDFTextStyle(font: PDFFont.regular(11), color: PDFColor.darkGray),
            in: notesRect,
            context: context
        )
        
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

// MARK: - Drawing Helpers

private enum PDFFont {
    static func regular(_ size: CGFloat) -> CTFont {
        CTFontCreateWithName("Helvetica" as CFString, size, nil)
    }
    
    static func bold(_ size: CGFloat) -> CTFont {
        CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    }
}

private struct PDFTextStyle {
    let font: CTFont
    let color: CGColor
    
    static let body = PDFTextStyle(font: PDFFont.regular(12), color: PDFColor.darkGray)
    
    static func bold(size: CGFloat) -> PDFTextStyle {
        PDFTextStyle(font: PDFFont.bold(size), color: PDFColor.black)
    }
    
    var attributes: [NSAttributedString.Key: Any] {
        [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
        ]
    }
    
    var lineHeight: CGFloat {
        CGFloat(CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font))
    }
    
    var baselineOffset: CGFloat {
        CGFloat(CTFontGetAscent(font))
    }
}

private enum PDFColor {
    static let black = CGColor(gray: 0, alpha: 1)
    static let white = CGColor(gray: 1, alpha: 1)
    static let darkGray = CGColor(gray: 0.25, alpha: 1)
    static let lightGray = CGColor(gray: 0.9, alpha: 1)
    static let tableHeader = CGColor(gray: 0.2, alpha: 1)
}

@discardableResult
private func drawText(
    _ text: String,
    style: PDFTextStyle,
    at point: CGPoint,
    in context: CGContext
) -> CGFloat {
    let attributedString = NSAttributedString(string: text, attributes: style.attributes)
    let line = CTLineCreateWithAttributedString(attributedString)
    
    context.saveGState()
    let position = CGPoint(x: point.x, y: point.y + style.baselineOffset)
    context.textPosition = position
    CTLineDraw(line, context)
    context.restoreGState()
    
    return style.lineHeight
}

private func drawMultilineText(
    _ text: String,
    style: PDFTextStyle,
    in rect: CGRect,
    context: CGContext
) {
    let attributedString = NSAttributedString(string: text, attributes: style.attributes)
    let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
    let path = CGMutablePath()
    path.addRect(rect)
    let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributedString.length), path, nil)
    
    context.saveGState()
    CTFrameDraw(frame, context)
    context.restoreGState()
}
