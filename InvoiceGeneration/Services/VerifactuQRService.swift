import Foundation
import CoreGraphics
import CoreImage

/// Generates QR codes for VeriFACTU invoice verification.
///
/// The QR encodes a URL pointing to AEAT's verification portal, allowing
/// recipients to validate the invoice against the tax authority's records.
enum VerifactuQRService {

    // MARK: - Constants

    /// Base URL for AEAT's VeriFACTU QR validation endpoint.
    /// Production: `https://www2.agenciatributaria.gob.es/wlpl/TIKE-CONT/ValidarQR`
    /// Pre-production: `https://prewww2.aeat.es/wlpl/TIKE-CONT/ValidarQR`
    private static let productionBaseUrl = "https://www2.agenciatributaria.gob.es/wlpl/TIKE-CONT/ValidarQR"
    private static let preProductionBaseUrl = "https://prewww2.aeat.es/wlpl/TIKE-CONT/ValidarQR"

    /// Set to `true` to use the pre-production (testing) endpoint.
    static var usePreProduction = true

    // MARK: - URL Generation

    /// Constructs the AEAT verification URL for a given invoice.
    ///
    /// - Parameters:
    ///   - issuerTaxId: NIF/CIF of the issuer
    ///   - invoiceNumber: Invoice number including series prefix
    ///   - issueDate: Invoice issue date
    ///   - totalAmount: Total invoice amount
    /// - Returns: The full verification URL string
    static func verificationUrl(
        issuerTaxId: String,
        invoiceNumber: String,
        issueDate: Date,
        totalAmount: Decimal
    ) -> String {
        let baseUrl = usePreProduction ? preProductionBaseUrl : productionBaseUrl
        let dateString = dateFormatter.string(from: issueDate)
        let amountString = String(format: "%.2f", NSDecimalNumber(decimal: totalAmount).doubleValue)

        var components = URLComponents(string: baseUrl)!
        components.queryItems = [
            URLQueryItem(name: "nif", value: issuerTaxId),
            URLQueryItem(name: "numserie", value: invoiceNumber),
            URLQueryItem(name: "fecha", value: dateString),
            URLQueryItem(name: "importe", value: amountString)
        ]

        return components.url?.absoluteString ?? baseUrl
    }

    // MARK: - QR Code Image Generation

    /// Generates a QR code CGImage for the given verification URL.
    ///
    /// - Parameters:
    ///   - url: The verification URL to encode
    ///   - size: Desired output size in points (the image will be square)
    /// - Returns: A `CGImage` containing the QR code, or nil on failure
    static func generateQRImage(for url: String, size: CGFloat = 150) -> CGImage? {
        guard let data = url.data(using: .utf8) else { return nil }

        let context = CIContext()
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        return context.createCGImage(scaledImage, from: scaledImage.extent)
    }

    /// Generates a QR code image directly from invoice data.
    ///
    /// - Parameters:
    ///   - issuerTaxId: NIF/CIF of the issuer
    ///   - invoiceNumber: Invoice number including series prefix
    ///   - issueDate: Invoice issue date
    ///   - totalAmount: Total invoice amount
    ///   - size: Desired output size in points
    /// - Returns: A `CGImage` containing the QR code, or nil on failure
    static func generateQRImage(
        issuerTaxId: String,
        invoiceNumber: String,
        issueDate: Date,
        totalAmount: Decimal,
        size: CGFloat = 150
    ) -> CGImage? {
        let url = verificationUrl(
            issuerTaxId: issuerTaxId,
            invoiceNumber: invoiceNumber,
            issueDate: issueDate,
            totalAmount: totalAmount
        )
        return generateQRImage(for: url, size: size)
    }

    // MARK: - Private

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: "Europe/Madrid")
        return formatter
    }()
}
