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
    static func generateInvoicePDF(invoice: Invoice) -> PDFDocument? {
        let accentColor = CGColor.fromHex(
            invoice.client?.accentColorHex ?? Client.defaultAccentHex,
            defaultColor: PDFColor.accent
        )
        let palette = PDFPalette(accent: accentColor)

        let issuerDetails = issuerDetails(from: invoice)

        let pdfMetaData: [CFString: Any] = [
            kCGPDFContextCreator: "InvoiceGenerator",
            kCGPDFContextAuthor: issuerDetails.name.isEmpty ? localized("Invoice Generator", comment: "Default PDF author") : issuerDetails.name,
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
        // Place origin at top-left for easier layout; flip CoreText back upright.
        context.translateBy(x: 0, y: pageHeight)
        context.scaleBy(x: 1, y: -1)
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)

        var yPosition: CGFloat = 24
        let pageRect = mediaBox

        yPosition = drawCompanyHeader(
            invoice: invoice,
            issuerDetails: issuerDetails,
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
            yPosition = drawNotes(
                invoice: invoice,
                palette: palette,
                in: context,
                pageRect: pageRect,
                startY: yPosition
            )
        }

        // VeriFACTU QR code and legend (only for invoices with a verifactu record)
        if let verifactuRecord = invoice.verifactuRecord, !verifactuRecord.qrCodeUrl.isEmpty {
            yPosition += 20
            _ = drawVerifactuFooter(
                record: verifactuRecord,
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
        issuerDetails: PDFIssuerDetails,
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
        yPosition += titleStyle.lineHeight + 10

        let nameStyle = PDFTextStyle(font: PDFFont.bold(14), color: palette.textPrimary)
        let infoStyle = PDFTextStyle(font: PDFFont.regular(11), color: palette.textSecondary)
        let leftColumnWidth: CGFloat = 200
        let leftColumnX: CGFloat = 50
        var leftColumnY = yPosition

        if !issuerDetails.name.isEmpty {
            let blockHeight = drawMultilineText(
                issuerDetails.name,
                style: nameStyle,
                in: CGRect(x: leftColumnX, y: leftColumnY, width: leftColumnWidth, height: height(for: issuerDetails.name, style: nameStyle, width: leftColumnWidth)),
                context: context
            )
            leftColumnY += blockHeight + 8
        }

        for text in [issuerDetails.address, issuerDetails.email, issuerDetails.phone] where !text.isEmpty {
            let blockHeight = drawMultilineText(
                text,
                style: infoStyle,
                in: CGRect(x: leftColumnX, y: leftColumnY, width: leftColumnWidth, height: height(for: text, style: infoStyle, width: leftColumnWidth)),
                context: context
            )
            leftColumnY += blockHeight + 8
        }

        if !issuerDetails.taxId.isEmpty {
            let taxLabel = String(
                format: localized("Tax ID: %@", comment: "PDF issuer tax id label and value"),
                issuerDetails.taxId
            )
            let blockHeight = drawMultilineText(
                taxLabel,
                style: infoStyle,
                in: CGRect(x: leftColumnX, y: leftColumnY, width: leftColumnWidth, height: height(for: taxLabel, style: infoStyle, width: leftColumnWidth)),
                context: context
            )
            leftColumnY += blockHeight + 8
        }

        let detailBoxWidth: CGFloat = 280
        let detailBoxX = pageRect.width - detailBoxWidth - 50
        let labelStyle = PDFTextStyle(font: PDFFont.bold(11), color: palette.textSecondary)
        let valueStyle = PDFTextStyle(font: PDFFont.regular(12), color: palette.textPrimary)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        let rowLabelWidth: CGFloat = 130
        let rowValueWidth = detailBoxWidth - 32 - rowLabelWidth
        var detailRows: [(String, String)] = [
            (localized("Invoice Number", comment: "PDF invoice number label"), invoice.invoiceNumber),
            (localized("Invoice Date", comment: "PDF invoice date label"), formatter.string(from: invoice.issueDate)),
            (localized("Due Date", comment: "PDF due date label"), formatter.string(from: invoice.dueDate)),
            (localized("Status", comment: "PDF status label"), localized(invoice.status.rawValue, comment: "Localized invoice status"))
        ]

        // Add invoice type for VeriFACTU invoices
        if invoice.verifactuRecord != nil {
            detailRows.append((
                localized("Type", comment: "PDF invoice type label"),
                invoice.invoiceType.rawValue
            ))
        }

        var detailContentHeight: CGFloat = 12
        for row in detailRows {
            let labelHeight = height(for: row.0, style: labelStyle, width: rowLabelWidth)
            let valueHeight = height(for: row.1, style: valueStyle, width: rowValueWidth)
            detailContentHeight += max(labelHeight, valueHeight) + 10
        }
        detailContentHeight += 2

        let detailBoxRect = CGRect(x: detailBoxX, y: startY + 18, width: detailBoxWidth, height: detailContentHeight)
        context.setFillColor(palette.panelBackground)
        context.fill(detailBoxRect)

        var detailY = detailBoxRect.origin.y + 12
        for row in detailRows {
            let labelHeight = height(for: row.0, style: labelStyle, width: rowLabelWidth)
            let valueHeight = height(for: row.1, style: valueStyle, width: rowValueWidth)
            let rowHeight = max(labelHeight, valueHeight)

            _ = drawMultilineText(
                row.0,
                style: labelStyle,
                in: CGRect(x: detailBoxX + 12, y: detailY, width: rowLabelWidth, height: rowHeight),
                context: context
            )
            _ = drawMultilineText(
                row.1,
                style: valueStyle,
                in: CGRect(x: detailBoxX + 20 + rowLabelWidth, y: detailY, width: rowValueWidth, height: rowHeight),
                context: context
            )
            detailY += rowHeight + 10
        }

        return max(leftColumnY, detailBoxRect.maxY)
    }

    private static func drawClientInfo(
        invoice: Invoice,
        palette: PDFPalette,
        in context: CGContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        let idNumber = invoice.clientIdentificationNumber.isEmpty ? (invoice.client?.identificationNumber ?? "") : invoice.clientIdentificationNumber
        let rows = [
            (localized("Client", comment: "PDF client label"), invoice.clientName),
            invoice.clientEmail.isEmpty ? nil : (localized("Email", comment: "PDF client email label"), invoice.clientEmail),
            idNumber.isEmpty ? nil : (localized("Identification Number", comment: "PDF client identification label"), idNumber),
            invoice.clientAddress.isEmpty ? nil : (localized("Address", comment: "PDF client address label"), invoice.clientAddress)
        ].compactMap { $0 }

        let labelWidth: CGFloat = 150
        let containerWidth = pageRect.width - 100
        let valueWidth = containerWidth - 32 - labelWidth - 16
        let headerHeight = height(for: localized("BILL TO", comment: "PDF bill-to header"), style: PDFTextStyle(font: PDFFont.bold(13), color: palette.accent), width: containerWidth - 32)

        let rowsHeight = rows.reduce(CGFloat(0)) { partialResult, row in
            let labelHeight = height(for: row.0, style: PDFTextStyle(font: PDFFont.bold(11), color: palette.textSecondary), width: labelWidth)
            let valueHeight = height(for: row.1, style: PDFTextStyle(font: PDFFont.regular(12), color: palette.textPrimary), width: valueWidth)
            return partialResult + max(labelHeight, valueHeight) + 10
        }

        let containerHeight = max(150, 18 + headerHeight + 12 + rowsHeight + 12)
        let container = CGRect(x: 50, y: startY, width: pageRect.width - 100, height: containerHeight)
        context.setFillColor(palette.sectionBackground)
        context.fill(container)

        let headerStyle = PDFTextStyle(font: PDFFont.bold(13), color: palette.accent)
        let labelStyle = PDFTextStyle(font: PDFFont.bold(11), color: palette.textSecondary)
        let valueStyle = PDFTextStyle(font: PDFFont.regular(12), color: palette.textPrimary)

        let labelX = container.origin.x + 16
        let valueX = labelX + labelWidth + 16
        var yPosition = container.origin.y + 16
        let titleHeight = drawMultilineText(
            localized("BILL TO", comment: "PDF bill-to header"),
            style: headerStyle,
            in: CGRect(x: labelX, y: yPosition, width: container.width - 32, height: headerHeight),
            context: context
        )
        yPosition += titleHeight + 12

        for row in rows {
            let labelHeight = height(for: row.0, style: labelStyle, width: labelWidth)
            let valueHeight = height(for: row.1, style: valueStyle, width: valueWidth)
            let rowHeight = max(labelHeight, valueHeight)

            _ = drawMultilineText(
                row.0,
                style: labelStyle,
                in: CGRect(x: labelX, y: yPosition, width: labelWidth, height: rowHeight),
                context: context
            )
            _ = drawMultilineText(
                row.1,
                style: valueStyle,
                in: CGRect(x: valueX, y: yPosition, width: valueWidth, height: rowHeight),
                context: context
            )
            yPosition += rowHeight + 10
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
        let tableX: CGFloat = 50
        let tableWidth = pageRect.width - 100
        let descriptionWidth: CGFloat = 235
        let quantityWidth: CGFloat = 70
        let unitPriceWidth: CGFloat = 90
        let headerRect = CGRect(x: tableX, y: yPosition, width: tableWidth, height: 32)
        context.setFillColor(palette.accent)
        context.fill(headerRect)

        let descriptionX = tableX + 10
        let quantityX = descriptionX + descriptionWidth
        let unitPriceX = quantityX + quantityWidth
        let totalX = unitPriceX + unitPriceWidth
        let headerTextY = yPosition + 9

        drawText(localized("Description", comment: "PDF table header for description"), style: headerStyle, at: CGPoint(x: descriptionX, y: headerTextY), in: context)
        drawText(localized("Quantity", comment: "PDF table header for quantity"), style: headerStyle, at: CGPoint(x: quantityX, y: headerTextY), in: context)
        drawText(localized("Unit Price", comment: "PDF table header for unit price"), style: headerStyle, at: CGPoint(x: unitPriceX, y: headerTextY), in: context)
        drawText(localized("Total", comment: "PDF table header for total"), style: headerStyle, at: CGPoint(x: totalX, y: headerTextY), in: context)

        yPosition = headerRect.maxY + 6

        for (index, item) in (invoice.items ?? []).enumerated() {
            let descriptionHeight = height(for: item.itemDescription, style: cellStyle, width: descriptionWidth)
            let rowHeight = max(26, descriptionHeight + 8)
            if index.isMultiple(of: 2) {
                let rowRect = CGRect(x: tableX, y: yPosition, width: tableWidth, height: rowHeight)
                context.setFillColor(palette.rowBackground)
                context.fill(rowRect)
            }

            let textTop = yPosition + 4
            let descriptionRect = CGRect(
                x: descriptionX,
                y: textTop,
                width: descriptionWidth,
                height: rowHeight - 8
            )
            _ = drawMultilineText(item.itemDescription, style: cellStyle, in: descriptionRect, context: context)
            drawText("\(item.quantity)", style: cellStyle, at: CGPoint(x: quantityX, y: textTop), in: context)
            drawText(currencyString(for: item.unitPrice), style: cellStyle, at: CGPoint(x: unitPriceX, y: textTop), in: context)
            drawText(currencyString(for: item.total), style: cellStyle, at: CGPoint(x: totalX, y: textTop), in: context)

            yPosition += rowHeight
            context.setStrokeColor(palette.divider)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: tableX, y: yPosition))
            context.addLine(to: CGPoint(x: pageRect.width - 50, y: yPosition))
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
        let summaryWidth: CGFloat = 280
        let xOrigin = pageRect.width - summaryWidth - 50
        let rowSpacing: CGFloat = 22
        let topPadding: CGFloat = 12
        let dividerSpacing: CGFloat = 12

        let breakdowns = invoice.taxBreakdowns ?? []
        let useMultiRate = !breakdowns.isEmpty

        // Calculate dynamic height based on number of IVA rows
        let ivaRowCount = useMultiRate ? breakdowns.count : 1
        let hasIrpf = invoice.irpfPercentage > 0
        let hasSurcharge = useMultiRate && breakdowns.contains { $0.surchargeRate > 0 }
        let surchargeRowCount = hasSurcharge ? breakdowns.filter { $0.surchargeRate > 0 }.count : 0
        let extraRows = (hasIrpf ? 1 : 0) + surchargeRowCount
        let totalRows = 1 + ivaRowCount + extraRows // subtotal + IVA rows + extras
        let containerHeight = topPadding + (rowSpacing * CGFloat(totalRows)) + dividerSpacing + rowSpacing + topPadding

        let container = CGRect(x: xOrigin, y: startY, width: summaryWidth, height: containerHeight)
        context.setFillColor(palette.panelBackground)
        context.fill(container)

        let labelStyle = PDFTextStyle(font: PDFFont.bold(12), color: palette.textSecondary)
        let valueStyle = PDFTextStyle(font: PDFFont.regular(12), color: palette.textPrimary)
        let totalStyle = PDFTextStyle(font: PDFFont.bold(14), color: palette.accent)

        var yPosition = container.origin.y + topPadding

        // Subtotal
        drawText(localized("Subtotal", comment: "PDF subtotal label"), style: labelStyle, at: CGPoint(x: xOrigin + 16, y: yPosition), in: context)
        drawText(currencyString(for: invoice.itemsSubtotal), style: valueStyle, at: CGPoint(x: xOrigin + 180, y: yPosition), in: context)
        yPosition += rowSpacing

        if useMultiRate {
            // Multi-rate IVA breakdown
            for breakdown in breakdowns.sorted(by: { $0.taxRate > $1.taxRate }) {
                let ivaLabel = String(
                    format: localized("IVA (%@)", comment: "PDF IVA label with percentage"),
                    breakdown.taxRate.formattedAsPercent
                )
                drawText(ivaLabel, style: labelStyle, at: CGPoint(x: xOrigin + 16, y: yPosition), in: context)
                drawText(currencyString(for: breakdown.taxAmount), style: valueStyle, at: CGPoint(x: xOrigin + 180, y: yPosition), in: context)
                yPosition += rowSpacing

                // Surcharge if applicable
                if breakdown.surchargeRate > 0 {
                    let surchargeLabel = String(
                        format: localized("R.E. (%@)", comment: "PDF equivalence surcharge label"),
                        breakdown.surchargeRate.formattedAsPercent
                    )
                    drawText(surchargeLabel, style: labelStyle, at: CGPoint(x: xOrigin + 16, y: yPosition), in: context)
                    drawText(currencyString(for: breakdown.surchargeAmount), style: valueStyle, at: CGPoint(x: xOrigin + 180, y: yPosition), in: context)
                    yPosition += rowSpacing
                }
            }
        } else {
            // Single-rate IVA
            let ivaLabel = String(
                format: localized("IVA (%@)", comment: "PDF IVA label with percentage"),
                invoice.ivaPercentage.formattedAsPercent
            )
            drawText(ivaLabel, style: labelStyle, at: CGPoint(x: xOrigin + 16, y: yPosition), in: context)
            drawText(currencyString(for: invoice.ivaAmount), style: valueStyle, at: CGPoint(x: xOrigin + 180, y: yPosition), in: context)
            yPosition += rowSpacing
        }

        // IRPF (withholding)
        if hasIrpf {
            let irpfLabel = String(
                format: localized("IRPF (%@)", comment: "PDF IRPF label with percentage"),
                invoice.irpfPercentage.formattedAsPercent
            )
            drawText(irpfLabel, style: labelStyle, at: CGPoint(x: xOrigin + 16, y: yPosition), in: context)
            drawText(currencyString(for: -invoice.irpfAmount), style: valueStyle, at: CGPoint(x: xOrigin + 180, y: yPosition), in: context)
            yPosition += rowSpacing
        }

        // Divider
        context.setStrokeColor(palette.divider)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: xOrigin + 12, y: yPosition))
        context.addLine(to: CGPoint(x: xOrigin + summaryWidth - 12, y: yPosition))
        context.strokePath()

        yPosition += dividerSpacing

        // Total
        drawText(localized("TOTAL", comment: "PDF total label"), style: totalStyle, at: CGPoint(x: xOrigin + 16, y: yPosition), in: context)
        drawText(currencyString(for: invoice.totalAmount), style: totalStyle, at: CGPoint(x: xOrigin + 180, y: yPosition), in: context)

        return container.maxY
    }

    private static func drawNotes(
        invoice: Invoice,
        palette: PDFPalette,
        in context: CGContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        let bodyStyle = PDFTextStyle(font: PDFFont.regular(11), color: palette.textPrimary)
        let headerStyle = PDFTextStyle(font: PDFFont.bold(12), color: palette.accent)
        let bodyHeight = height(for: invoice.notes, style: bodyStyle, width: pageRect.width - 124)
        let container = CGRect(x: 50, y: startY, width: pageRect.width - 100, height: max(110, bodyHeight + 52))
        context.setFillColor(palette.sectionBackground)
        context.fill(container)

        drawText(localized("Notes", comment: "PDF notes header"), style: headerStyle, at: CGPoint(x: container.origin.x + 12, y: container.origin.y + 12), in: context)

        let notesRect = CGRect(
            x: container.origin.x + 12,
            y: container.origin.y + 28,
            width: container.width - 24,
            height: container.height - 40
        )
        _ = drawMultilineText(invoice.notes, style: bodyStyle, in: notesRect, context: context)

        return container.maxY
    }

    // MARK: - VeriFACTU Footer

    private static func drawVerifactuFooter(
        record: VerifactuRecord,
        palette: PDFPalette,
        in context: CGContext,
        pageRect: CGRect,
        startY: CGFloat
    ) -> CGFloat {
        var yPosition = startY
        let qrSize: CGFloat = 100
        let margin: CGFloat = 50
        let qrX = pageRect.width - margin - qrSize

        // Draw QR code
        if let qrImage = VerifactuQRService.generateQRImage(for: record.qrCodeUrl, size: qrSize) {
            let qrRect = CGRect(x: qrX, y: yPosition, width: qrSize, height: qrSize)

            context.saveGState()
            // Flip for image drawing (already in flipped coordinate system)
            context.translateBy(x: qrRect.origin.x, y: qrRect.origin.y + qrRect.height)
            context.scaleBy(x: 1, y: -1)
            context.draw(qrImage, in: CGRect(origin: .zero, size: qrRect.size))
            context.restoreGState()
        }

        // VeriFACTU legend text (left of QR)
        let legendWidth = qrX - margin - 20
        let legendStyle = PDFTextStyle(font: PDFFont.regular(8), color: palette.textSecondary)
        let boldLegendStyle = PDFTextStyle(font: PDFFont.bold(9), color: palette.textPrimary)

        drawText(
            localized("VeriFactu", comment: "PDF VeriFACTU label"),
            style: boldLegendStyle,
            at: CGPoint(x: margin, y: yPosition),
            in: context
        )
        yPosition += 14

        let legendText = localized(
            "Invoice verifiable at the AEAT electronic office",
            comment: "PDF VeriFACTU verification legend"
        )
        _ = drawMultilineText(
            legendText,
            style: legendStyle,
            in: CGRect(x: margin, y: yPosition, width: legendWidth, height: 30),
            context: context
        )
        yPosition += 16

        let hashLabel = String(
            format: localized("Hash: %@", comment: "PDF hash label"),
            String(record.recordHash.prefix(16)) + "..."
        )
        _ = drawMultilineText(
            hashLabel,
            style: legendStyle,
            in: CGRect(x: margin, y: yPosition, width: legendWidth, height: 14),
            context: context
        )
        yPosition += 14

        let typeLabel = String(
            format: localized("Type: %@ | Regime: %@", comment: "PDF invoice type and regime"),
            record.invoiceType.rawValue,
            record.taxRegimeKey.rawValue
        )
        _ = drawMultilineText(
            typeLabel,
            style: legendStyle,
            in: CGRect(x: margin, y: yPosition, width: legendWidth, height: 14),
            context: context
        )

        return max(yPosition + 14, startY + qrSize)
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

    static func issuerDetails(from invoice: Invoice) -> PDFIssuerDetails {
        let fallbackIssuer = invoice.issuer
        let name = invoice.issuerName.isEmpty ? (fallbackIssuer?.name ?? "") : invoice.issuerName
        let code = invoice.issuerCode.isEmpty ? (fallbackIssuer?.code ?? "") : invoice.issuerCode
        let ownerName = invoice.issuerOwnerName.isEmpty ? (fallbackIssuer?.ownerName ?? "") : invoice.issuerOwnerName
        let email = invoice.issuerEmail.isEmpty ? (fallbackIssuer?.email ?? "") : invoice.issuerEmail
        let phone = invoice.issuerPhone.isEmpty ? (fallbackIssuer?.phone ?? "") : invoice.issuerPhone
        let address = invoice.issuerAddress.isEmpty ? (fallbackIssuer?.address ?? "") : invoice.issuerAddress
        let taxId = invoice.issuerTaxId.isEmpty ? (fallbackIssuer?.taxId ?? "") : invoice.issuerTaxId

        if name.isEmpty {
            return PDFIssuerDetails(
                name: localized("Invoice Generator", comment: "Fallback issuer name"),
                code: code,
                ownerName: ownerName,
                email: email,
                phone: phone,
                address: address,
                taxId: taxId
            )
        }

        return PDFIssuerDetails(
            name: name,
            code: code,
            ownerName: ownerName,
            email: email,
            phone: phone,
            address: address,
            taxId: taxId
        )
    }
}

private struct PDFIssuerDetails {
    let name: String
    let code: String
    let ownerName: String
    let email: String
    let phone: String
    let address: String
    let taxId: String
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
) -> CGFloat {
    let normalizedText = normalizedPDFText(text)
    let actualHeight = height(for: normalizedText, style: style, width: rect.width)
    let drawingRect = CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: max(rect.height, actualHeight))
    let attributedString = NSAttributedString(string: normalizedText, attributes: style.attributes)
    let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
    let path = CGMutablePath()
    path.addRect(drawingRect)
    let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributedString.length), path, nil)

    CTFrameDraw(frame, context)

    return actualHeight
}

private func height(for text: String, style: PDFTextStyle, width: CGFloat) -> CGFloat {
    let attributedString = NSAttributedString(string: normalizedPDFText(text), attributes: style.attributes)
    let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
    let constraintSize = CGSize(width: width, height: .greatestFiniteMagnitude)
    let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
        framesetter,
        CFRange(location: 0, length: attributedString.length),
        nil,
        constraintSize,
        nil
    )
    return ceil(suggestedSize.height)
}

private func normalizedPDFText(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
}

private func currencyString(for value: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale.current
    return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
}
