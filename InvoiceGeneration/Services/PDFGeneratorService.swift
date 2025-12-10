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
        let accentColor = CGColor.fromHex(
            invoice.client?.accentColorHex ?? Client.defaultAccentHex,
            defaultColor: PDFColor.accent
        )
        let palette = PDFPalette(accent: accentColor)

        let pdfMetaData: [CFString: Any] = [
            kCGPDFContextCreator: "InvoiceGenerator",
            kCGPDFContextAuthor: companyProfile?.companyName ?? localized("Invoice Generator", comment: "Default PDF author"),
            kCGPDFContextTitle: String(
                format: localized("Invoice %@", comment: "PDF document title format"),
                invoice.invoiceNumber
            )
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
        
        var yPosition: CGFloat = 24
        let pageRect = mediaBox

        yPosition = drawCompanyHeader(
            invoice: invoice,
            companyProfile: companyProfile,
            palette: palette,
            in: context,
            pageRect: pageRect,
            startY: yPosition
        )

        yPosition += 18

        yPosition = drawClientInfo(
            invoice: invoice,
            palette: palette,
            in: context,
            pageRect: pageRect,
            startY: yPosition
        )

        yPosition += 20

        yPosition = drawItemsTable(
            invoice: invoice,
            palette: palette,
            in: context,
            pageRect: pageRect,
            startY: yPosition
        )

        yPosition += 16

        yPosition = drawTotal(
            invoice: invoice,
            palette: palette,
            in: context,
            pageRect: pageRect,
            startY: yPosition
        )

        if !invoice.notes.isEmpty {
            yPosition += 24
            _ = drawNotes(
                invoice: invoice,
                palette: palette,
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
        invoice: Invoice,
        companyProfile: CompanyProfile?,
        palette: PDFPalette,
        in context: CGContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        var yPosition = startY

        let accentBar = CGRect(x: 0, y: yPosition, width: pageRect.width, height: 10)
        context.setFillColor(palette.accent)
        context.fill(accentBar)
        yPosition += 26

        let titleStyle = PDFTextStyle(font: PDFFont.bold(22), color: palette.textPrimary)
        drawText(
            localized("INVOICE", comment: "PDF invoice title"),
            style: titleStyle,
            at: CGPoint(x: 50, y: yPosition),
            in: context
        )
        yPosition += 14

        if let companyProfile = companyProfile {
            let nameStyle = PDFTextStyle(font: PDFFont.bold(14), color: palette.textPrimary)
            let infoStyle = PDFTextStyle(font: PDFFont.regular(11), color: palette.textSecondary)

            drawText(companyProfile.companyName, style: nameStyle, at: CGPoint(x: 50, y: yPosition), in: context)
            yPosition += 16

            if !companyProfile.address.isEmpty {
                drawText(companyProfile.address, style: infoStyle, at: CGPoint(x: 50, y: yPosition), in: context)
                yPosition += 14
            }

            if !companyProfile.email.isEmpty {
                drawText(companyProfile.email, style: infoStyle, at: CGPoint(x: 50, y: yPosition), in: context)
                yPosition += 14
            }

            if !companyProfile.phone.isEmpty {
                drawText(companyProfile.phone, style: infoStyle, at: CGPoint(x: 50, y: yPosition), in: context)
                yPosition += 14
            }
        }

        let detailBoxWidth: CGFloat = 230
        let detailBoxHeight: CGFloat = 104
        let detailBoxX = pageRect.width - detailBoxWidth - 50
        let detailBoxRect = CGRect(x: detailBoxX, y: startY + 18, width: detailBoxWidth, height: detailBoxHeight)
        context.setFillColor(palette.panelBackground)
        context.fill(detailBoxRect)

        let labelStyle = PDFTextStyle(font: PDFFont.bold(11), color: palette.textSecondary)
        let valueStyle = PDFTextStyle(font: PDFFont.regular(12), color: palette.textPrimary)
        let formatter = DateFormatter()
        formatter.dateStyle = .short

        var detailY = detailBoxRect.origin.y + 12
        drawText(localized("Invoice Number", comment: "PDF invoice number label"), style: labelStyle, at: CGPoint(x: detailBoxX + 12, y: detailY), in: context)
        drawText(invoice.invoiceNumber, style: valueStyle, at: CGPoint(x: detailBoxX + 130, y: detailY), in: context)
        detailY += 22

        drawText(localized("Invoice Date", comment: "PDF invoice date label"), style: labelStyle, at: CGPoint(x: detailBoxX + 12, y: detailY), in: context)
        drawText(formatter.string(from: invoice.issueDate), style: valueStyle, at: CGPoint(x: detailBoxX + 130, y: detailY), in: context)
        detailY += 22

        drawText(localized("Due Date", comment: "PDF due date label"), style: labelStyle, at: CGPoint(x: detailBoxX + 12, y: detailY), in: context)
        drawText(formatter.string(from: invoice.dueDate), style: valueStyle, at: CGPoint(x: detailBoxX + 130, y: detailY), in: context)
        detailY += 22

        drawText(localized("Status", comment: "PDF status label"), style: labelStyle, at: CGPoint(x: detailBoxX + 12, y: detailY), in: context)
        drawText(localized(invoice.status.rawValue, comment: "Localized invoice status"), style: valueStyle, at: CGPoint(x: detailBoxX + 130, y: detailY), in: context)

        return max(yPosition, detailBoxRect.maxY)
    }

    private static func drawClientInfo(
        invoice: Invoice,
        palette: PDFPalette,
        in context: CGContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        let container = CGRect(x: 50, y: startY, width: pageRect.width - 100, height: 110)
        context.setFillColor(palette.sectionBackground)
        context.fill(container)

        let headerStyle = PDFTextStyle(font: PDFFont.bold(13), color: palette.accent)
        let labelStyle = PDFTextStyle(font: PDFFont.bold(11), color: palette.textSecondary)
        let valueStyle = PDFTextStyle(font: PDFFont.regular(12), color: palette.textPrimary)

        var yPosition = container.origin.y + 12
        drawText(localized("BILL TO", comment: "PDF bill-to header"), style: headerStyle, at: CGPoint(x: container.origin.x + 12, y: yPosition), in: context)
        yPosition += 18

        drawText(localized("Client", comment: "PDF client label"), style: labelStyle, at: CGPoint(x: container.origin.x + 12, y: yPosition), in: context)
        drawText(invoice.clientName, style: valueStyle, at: CGPoint(x: container.origin.x + 100, y: yPosition), in: context)
        yPosition += 18

        if !invoice.clientEmail.isEmpty {
            drawText(localized("Email", comment: "PDF client email label"), style: labelStyle, at: CGPoint(x: container.origin.x + 12, y: yPosition), in: context)
            drawText(invoice.clientEmail, style: valueStyle, at: CGPoint(x: container.origin.x + 100, y: yPosition), in: context)
            yPosition += 18
        }

        if !invoice.clientAddress.isEmpty {
            drawText(localized("Address", comment: "PDF client address label"), style: labelStyle, at: CGPoint(x: container.origin.x + 12, y: yPosition), in: context)
            drawText(invoice.clientAddress, style: valueStyle, at: CGPoint(x: container.origin.x + 100, y: yPosition), in: context)
        }

        return container.maxY
    }

    private static func drawItemsTable(
        invoice: Invoice,
        palette: PDFPalette,
        in context: CGContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        var yPosition = startY
        let headerStyle = PDFTextStyle(font: PDFFont.bold(12), color: PDFColor.white)
        let cellStyle = PDFTextStyle(font: PDFFont.regular(11), color: palette.textPrimary)

        let headerRect = CGRect(x: 50, y: yPosition, width: pageRect.width - 100, height: 32)
        context.setFillColor(palette.accent)
        context.fill(headerRect)

        let columnX: [CGFloat] = [60, 320, 400, 500]
        drawText(localized("Description", comment: "PDF table header for description"), style: headerStyle, at: CGPoint(x: columnX[0], y: yPosition + 9), in: context)
        drawText(localized("Quantity", comment: "PDF table header for quantity"), style: headerStyle, at: CGPoint(x: columnX[1], y: yPosition + 9), in: context)
        drawText(localized("Unit Price", comment: "PDF table header for unit price"), style: headerStyle, at: CGPoint(x: columnX[2], y: yPosition + 9), in: context)
        drawText(localized("Total", comment: "PDF table header for total"), style: headerStyle, at: CGPoint(x: columnX[3], y: yPosition + 9), in: context)

        yPosition += 38

        for (index, item) in invoice.items.enumerated() {
            if index.isMultiple(of: 2) {
                let rowRect = CGRect(x: 50, y: yPosition - 6, width: pageRect.width - 100, height: 26)
                context.setFillColor(palette.rowBackground)
                context.fill(rowRect)
            }

            drawText(item.itemDescription, style: cellStyle, at: CGPoint(x: columnX[0], y: yPosition), in: context)
            drawText("\(item.quantity)", style: cellStyle, at: CGPoint(x: columnX[1], y: yPosition), in: context)
            drawText(currencyString(for: item.unitPrice), style: cellStyle, at: CGPoint(x: columnX[2], y: yPosition), in: context)
            drawText(currencyString(for: item.total), style: cellStyle, at: CGPoint(x: columnX[3], y: yPosition), in: context)

            yPosition += 26
            context.setStrokeColor(palette.divider)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: 50, y: yPosition - 4))
            context.addLine(to: CGPoint(x: pageRect.width - 50, y: yPosition - 4))
            context.strokePath()
        }

        return yPosition
    }

    private static func drawTotal(
        invoice: Invoice,
        palette: PDFPalette,
        in context: CGContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        let summaryWidth: CGFloat = 250
        let xOrigin = pageRect.width - summaryWidth - 50
        let container = CGRect(x: xOrigin, y: startY, width: summaryWidth, height: 84)
        context.setFillColor(palette.panelBackground)
        context.fill(container)

        let labelStyle = PDFTextStyle(font: PDFFont.bold(12), color: palette.textSecondary)
        let valueStyle = PDFTextStyle(font: PDFFont.regular(12), color: palette.textPrimary)
        let totalStyle = PDFTextStyle(font: PDFFont.bold(14), color: palette.accent)

        var yPosition = container.origin.y + 12
        drawText(localized("Subtotal", comment: "PDF subtotal label"), style: labelStyle, at: CGPoint(x: xOrigin + 16, y: yPosition), in: context)
        drawText(currencyString(for: invoice.items.reduce(0) { $0 + $1.total }), style: valueStyle, at: CGPoint(x: xOrigin + 150, y: yPosition), in: context)
        yPosition += 22

        context.setStrokeColor(palette.divider)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: xOrigin + 12, y: yPosition))
        context.addLine(to: CGPoint(x: xOrigin + summaryWidth - 12, y: yPosition))
        context.strokePath()

        yPosition += 12

        drawText(localized("TOTAL", comment: "PDF total label"), style: totalStyle, at: CGPoint(x: xOrigin + 16, y: yPosition), in: context)
        drawText(currencyString(for: invoice.totalAmount), style: totalStyle, at: CGPoint(x: xOrigin + 150, y: yPosition), in: context)

        return container.maxY
    }

    private static func drawNotes(
        invoice: Invoice,
        palette: PDFPalette,
        in context: CGContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        let container = CGRect(x: 50, y: startY, width: pageRect.width - 100, height: 110)
        context.setFillColor(palette.sectionBackground)
        context.fill(container)

        let headerStyle = PDFTextStyle(font: PDFFont.bold(12), color: palette.accent)
        let bodyStyle = PDFTextStyle(font: PDFFont.regular(11), color: palette.textPrimary)

        drawText(localized("Notes", comment: "PDF notes header"), style: headerStyle, at: CGPoint(x: container.origin.x + 12, y: container.origin.y + 12), in: context)

        let notesRect = CGRect(
            x: container.origin.x + 12,
            y: container.origin.y + 28,
            width: container.width - 24,
            height: container.height - 40
        )
        drawMultilineText(invoice.notes, style: bodyStyle, in: notesRect, context: context)

        return container.maxY
    }
    
    /// Save PDF to file
    static func savePDF(_ pdfDocument: PDFDocument, fileName: String) -> URL? {
        guard let fileURL = PDFStorageManager.targetURL(for: fileName) else {
            return nil
        }
        
        if pdfDocument.write(to: fileURL) {
            return fileURL
        }
        
        return nil
    }
}

private extension PDFGeneratorService {
    static func localized(_ key: String, comment: String = "") -> String {
        NSLocalizedString(key, comment: comment)
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
    static let darkGray = CGColor(gray: 0.22, alpha: 1)
    static let lightGray = CGColor(gray: 0.9, alpha: 1)
    static let accent = CGColor(red: 0.12, green: 0.38, blue: 0.72, alpha: 1)
}

private struct PDFPalette {
    let accent: CGColor
    let accentLight: CGColor
    let textPrimary: CGColor
    let textSecondary: CGColor
    let panelBackground: CGColor
    let sectionBackground: CGColor
    let rowBackground: CGColor
    let divider: CGColor

    init(accent: CGColor) {
        self.accent = accent
        self.accentLight = accent.copy(alpha: 0.12) ?? accent
        self.textPrimary = CGColor(gray: 0.12, alpha: 1)
        self.textSecondary = CGColor(gray: 0.4, alpha: 1)
        self.panelBackground = CGColor(gray: 0.96, alpha: 1)
        self.sectionBackground = CGColor(gray: 0.97, alpha: 1)
        self.rowBackground = accent.copy(alpha: 0.06) ?? CGColor(gray: 0.94, alpha: 1)
        self.divider = CGColor(gray: 0.84, alpha: 1)
    }
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

private func currencyString(for value: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale.current
    return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
}
