import Foundation

/// Generates XML documents conforming to the AEAT SuministroLR specification
/// for VeriFACTU invoice registry submissions.
///
/// Supports two record types:
/// - **Alta** (registration): Registers a new invoice with AEAT
/// - **Anulación** (cancellation): Annuls a previously registered invoice
enum VerifactuXMLService {

    // MARK: - Constants

    /// AEAT SuministroLR XML namespace
    private static let sifNamespace = "https://www2.agenciatributaria.gob.es/static_files/common/internet/dep/aplicaciones/es/aeat/tike/cont/ws/SusistroLR.xsd"
    private static let sifPrefix = "sif"
    private static let soapNamespace = "http://schemas.xmlsoap.org/soap/envelope/"

    /// Software identification — the app producing these records
    private static let softwareName = "InvoiceGenerator"
    private static let softwareVersion = "1.0"
    private static let softwareNIF = ""  // Set to developer's NIF when registering software with AEAT

    // MARK: - Alta (Registration) XML

    /// Generates the XML document for registering an invoice (alta) with AEAT.
    ///
    /// - Parameters:
    ///   - record: The VeriFACTU record to submit
    ///   - invoice: The associated invoice with full data
    ///   - issuer: The issuer profile
    /// - Returns: A UTF-8 encoded XML string
    static func generateAltaXML(
        record: VerifactuRecord,
        invoice: Invoice,
        issuer: Issuer
    ) -> String {
        var xml = xmlHeader()
        xml += openSoapEnvelope()
        xml += openSoapBody()
        xml += "  <\(sifPrefix):SuministroLRFacturasEmitidas>\n"

        // Cabecera (header)
        xml += generateCabecera(issuer: issuer)

        // Registro LR Factura Emitida
        xml += "    <\(sifPrefix):RegistroLRFacturasEmitidas>\n"
        xml += generatePeriodoLiquidacion(date: invoice.issueDate)
        xml += generateIDFactura(record: record)
        xml += generateFacturaExpedida(record: record, invoice: invoice)
        xml += generateHuella(record: record)
        xml += "    </\(sifPrefix):RegistroLRFacturasEmitidas>\n"

        xml += "  </\(sifPrefix):SuministroLRFacturasEmitidas>\n"
        xml += closeSoapBody()
        xml += closeSoapEnvelope()

        return xml
    }

    // MARK: - Anulación (Cancellation) XML

    /// Generates the XML document for cancelling a previously registered invoice (anulación).
    static func generateAnulacionXML(
        record: VerifactuRecord,
        issuer: Issuer
    ) -> String {
        var xml = xmlHeader()
        xml += openSoapEnvelope()
        xml += openSoapBody()
        xml += "  <\(sifPrefix):BajaLRFacturasEmitidas>\n"

        xml += generateCabecera(issuer: issuer)

        xml += "    <\(sifPrefix):RegistroLRBajaExpedidas>\n"
        xml += generateIDFactura(record: record)
        xml += generateHuella(record: record)
        xml += "    </\(sifPrefix):RegistroLRBajaExpedidas>\n"

        xml += "  </\(sifPrefix):BajaLRFacturasEmitidas>\n"
        xml += closeSoapBody()
        xml += closeSoapEnvelope()

        return xml
    }

    // MARK: - Batch Export

    /// Generates XML for multiple records in a single SuministroLR document.
    static func generateBatchAltaXML(
        records: [(record: VerifactuRecord, invoice: Invoice)],
        issuer: Issuer
    ) -> String {
        guard let first = records.first else { return "" }

        var xml = xmlHeader()
        xml += openSoapEnvelope()
        xml += openSoapBody()
        xml += "  <\(sifPrefix):SuministroLRFacturasEmitidas>\n"
        xml += generateCabecera(issuer: issuer)

        for entry in records {
            xml += "    <\(sifPrefix):RegistroLRFacturasEmitidas>\n"
            xml += generatePeriodoLiquidacion(date: entry.invoice.issueDate)
            xml += generateIDFactura(record: entry.record)
            xml += generateFacturaExpedida(record: entry.record, invoice: entry.invoice)
            xml += generateHuella(record: entry.record)
            xml += "    </\(sifPrefix):RegistroLRFacturasEmitidas>\n"
        }

        xml += "  </\(sifPrefix):SuministroLRFacturasEmitidas>\n"
        xml += closeSoapBody()
        xml += closeSoapEnvelope()

        return xml
    }

    // MARK: - XML Export to File

    /// Writes XML content to a temporary file and returns its URL for sharing.
    static func exportToFile(xml: String, fileName: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileUrl = tempDir.appendingPathComponent("\(fileName).xml")

        do {
            try xml.write(to: fileUrl, atomically: true, encoding: .utf8)
            return fileUrl
        } catch {
            return nil
        }
    }

    // MARK: - Private: XML Structure Builders

    private static func xmlHeader() -> String {
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    }

    private static func openSoapEnvelope() -> String {
        "<soapenv:Envelope xmlns:soapenv=\"\(soapNamespace)\" xmlns:\(sifPrefix)=\"\(sifNamespace)\">\n"
    }

    private static func closeSoapEnvelope() -> String {
        "</soapenv:Envelope>\n"
    }

    private static func openSoapBody() -> String {
        "  <soapenv:Body>\n"
    }

    private static func closeSoapBody() -> String {
        "  </soapenv:Body>\n"
    }

    private static func generateCabecera(issuer: Issuer) -> String {
        var xml = "    <\(sifPrefix):Cabecera>\n"
        xml += "      <\(sifPrefix):IDVersionSif>1.0</\(sifPrefix):IDVersionSif>\n"
        xml += "      <\(sifPrefix):ObligadoEmision>\n"
        xml += "        <\(sifPrefix):NombreRazon>\(escapeXML(issuer.name))</\(sifPrefix):NombreRazon>\n"
        xml += "        <\(sifPrefix):NIF>\(escapeXML(issuer.taxId))</\(sifPrefix):NIF>\n"
        xml += "      </\(sifPrefix):ObligadoEmision>\n"
        xml += "    </\(sifPrefix):Cabecera>\n"
        return xml
    }

    private static func generatePeriodoLiquidacion(date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        var xml = "      <\(sifPrefix):PeriodoLiquidacion>\n"
        xml += "        <\(sifPrefix):Ejercicio>\(year)</\(sifPrefix):Ejercicio>\n"
        xml += "        <\(sifPrefix):Periodo>\(String(format: "%02d", month))</\(sifPrefix):Periodo>\n"
        xml += "      </\(sifPrefix):PeriodoLiquidacion>\n"
        return xml
    }

    private static func generateIDFactura(record: VerifactuRecord) -> String {
        var xml = "      <\(sifPrefix):IDFactura>\n"
        xml += "        <\(sifPrefix):IDEmisorFactura>\n"
        xml += "          <\(sifPrefix):NIF>\(escapeXML(record.issuerTaxId))</\(sifPrefix):NIF>\n"
        xml += "        </\(sifPrefix):IDEmisorFactura>\n"
        xml += "        <\(sifPrefix):NumSerieFactura>\(escapeXML(record.invoiceNumber))</\(sifPrefix):NumSerieFactura>\n"
        xml += "        <\(sifPrefix):FechaExpedicionFactura>\(dateString(record.issueDate))</\(sifPrefix):FechaExpedicionFactura>\n"
        xml += "      </\(sifPrefix):IDFactura>\n"
        return xml
    }

    private static func generateFacturaExpedida(record: VerifactuRecord, invoice: Invoice) -> String {
        var xml = "      <\(sifPrefix):FacturaExpedida>\n"
        xml += "        <\(sifPrefix):TipoFactura>\(record.invoiceType.rawValue)</\(sifPrefix):TipoFactura>\n"

        // Rectificativa fields
        if record.invoiceType.isRectificativa {
            if let method = invoice.correctionMethod {
                xml += "        <\(sifPrefix):TipoRectificativa>\(method.rawValue)</\(sifPrefix):TipoRectificativa>\n"
            }
            if !invoice.rectifiedInvoiceNumber.isEmpty {
                xml += "        <\(sifPrefix):FacturasRectificadas>\n"
                xml += "          <\(sifPrefix):IDFacturaRectificada>\n"
                xml += "            <\(sifPrefix):NumSerieFactura>\(escapeXML(invoice.rectifiedInvoiceNumber))</\(sifPrefix):NumSerieFactura>\n"
                if let rectDate = invoice.rectifiedInvoiceDate {
                    xml += "            <\(sifPrefix):FechaExpedicionFactura>\(dateString(rectDate))</\(sifPrefix):FechaExpedicionFactura>\n"
                }
                xml += "          </\(sifPrefix):IDFacturaRectificada>\n"
                xml += "        </\(sifPrefix):FacturasRectificadas>\n"
            }
        }

        xml += "        <\(sifPrefix):ClaveRegimenEspecialOTrascendencia>\(record.taxRegimeKey.rawValue)</\(sifPrefix):ClaveRegimenEspecialOTrascendencia>\n"
        xml += "        <\(sifPrefix):ImporteTotal>\(decimalString(record.totalAmount))</\(sifPrefix):ImporteTotal>\n"

        // Descripcion de la operación
        let description = invoice.operationDescription.isEmpty
            ? String(localized: "Invoice services", comment: "Default operation description for XML")
            : invoice.operationDescription
        xml += "        <\(sifPrefix):DescripcionOperacion>\(escapeXML(description))</\(sifPrefix):DescripcionOperacion>\n"

        // Destinatario (recipient)
        xml += generateDestinatario(invoice: invoice)

        // Desglose (tax breakdown)
        xml += generateDesglose(invoice: invoice)

        // Software information
        xml += generateSistemaInformatico()

        xml += "      </\(sifPrefix):FacturaExpedida>\n"
        return xml
    }

    private static func generateDestinatario(invoice: Invoice) -> String {
        let clientId = invoice.clientIdentificationNumber
        let clientName = invoice.clientName

        guard !clientName.isEmpty else { return "" }

        var xml = "        <\(sifPrefix):Contraparte>\n"
        xml += "          <\(sifPrefix):NombreRazon>\(escapeXML(clientName))</\(sifPrefix):NombreRazon>\n"

        if !clientId.isEmpty {
            xml += "          <\(sifPrefix):NIF>\(escapeXML(clientId))</\(sifPrefix):NIF>\n"
        }

        xml += "        </\(sifPrefix):Contraparte>\n"
        return xml
    }

    private static func generateDesglose(invoice: Invoice) -> String {
        var xml = "        <\(sifPrefix):TipoDesglose>\n"
        xml += "          <\(sifPrefix):DesgloseFactura>\n"
        xml += "            <\(sifPrefix):Sujeta>\n"
        xml += "              <\(sifPrefix):NoExenta>\n"
        xml += "                <\(sifPrefix):TipoNoExenta>S1</\(sifPrefix):TipoNoExenta>\n"
        xml += "                <\(sifPrefix):DesgloseIVA>\n"

        let breakdowns = invoice.taxBreakdowns ?? []

        if !breakdowns.isEmpty {
            // Multi-rate IVA
            for breakdown in breakdowns.sorted(by: { $0.taxRate > $1.taxRate }) {
                xml += "                  <\(sifPrefix):DetalleIVA>\n"
                xml += "                    <\(sifPrefix):TipoImpositivo>\(decimalString(breakdown.taxRate))</\(sifPrefix):TipoImpositivo>\n"
                xml += "                    <\(sifPrefix):BaseImponible>\(decimalString(breakdown.taxBase))</\(sifPrefix):BaseImponible>\n"
                xml += "                    <\(sifPrefix):CuotaRepercutida>\(decimalString(breakdown.taxAmount))</\(sifPrefix):CuotaRepercutida>\n"
                if breakdown.surchargeRate > 0 {
                    xml += "                    <\(sifPrefix):TipoRecargoEquivalencia>\(decimalString(breakdown.surchargeRate))</\(sifPrefix):TipoRecargoEquivalencia>\n"
                    xml += "                    <\(sifPrefix):CuotaRecargoEquivalencia>\(decimalString(breakdown.surchargeAmount))</\(sifPrefix):CuotaRecargoEquivalencia>\n"
                }
                xml += "                  </\(sifPrefix):DetalleIVA>\n"
            }
        } else {
            // Simple single-rate IVA
            xml += "                  <\(sifPrefix):DetalleIVA>\n"
            xml += "                    <\(sifPrefix):TipoImpositivo>\(decimalString(invoice.ivaPercentage))</\(sifPrefix):TipoImpositivo>\n"
            xml += "                    <\(sifPrefix):BaseImponible>\(decimalString(invoice.itemsSubtotal))</\(sifPrefix):BaseImponible>\n"
            xml += "                    <\(sifPrefix):CuotaRepercutida>\(decimalString(invoice.ivaAmount))</\(sifPrefix):CuotaRepercutida>\n"
            xml += "                  </\(sifPrefix):DetalleIVA>\n"
        }

        xml += "                </\(sifPrefix):DesgloseIVA>\n"
        xml += "              </\(sifPrefix):NoExenta>\n"
        xml += "            </\(sifPrefix):Sujeta>\n"
        xml += "          </\(sifPrefix):DesgloseFactura>\n"
        xml += "        </\(sifPrefix):TipoDesglose>\n"
        return xml
    }

    private static func generateHuella(record: VerifactuRecord) -> String {
        var xml = "      <\(sifPrefix):Huella>\n"
        xml += "        <\(sifPrefix):Huella>\(record.recordHash)</\(sifPrefix):Huella>\n"
        xml += "        <\(sifPrefix):FechaHoraHusoGenRegistro>\(timestampString(record.recordTimestamp))</\(sifPrefix):FechaHoraHusoGenRegistro>\n"
        xml += "        <\(sifPrefix):HuellaAnterior>\(record.previousHash)</\(sifPrefix):HuellaAnterior>\n"
        xml += "        <\(sifPrefix):NumRegistro>\(record.sequenceNumber)</\(sifPrefix):NumRegistro>\n"
        xml += "      </\(sifPrefix):Huella>\n"
        return xml
    }

    private static func generateSistemaInformatico() -> String {
        var xml = "        <\(sifPrefix):SistemaInformatico>\n"
        xml += "          <\(sifPrefix):NombreSistemaInformatico>\(escapeXML(softwareName))</\(sifPrefix):NombreSistemaInformatico>\n"
        xml += "          <\(sifPrefix):IdSistemaInformatico>01</\(sifPrefix):IdSistemaInformatico>\n"
        xml += "          <\(sifPrefix):Version>\(softwareVersion)</\(sifPrefix):Version>\n"
        xml += "          <\(sifPrefix):TipoUsoPosibleSoloVerifactu>S</\(sifPrefix):TipoUsoPosibleSoloVerifactu>\n"
        xml += "          <\(sifPrefix):TipoUsoPosibleMultiOT>N</\(sifPrefix):TipoUsoPosibleMultiOT>\n"
        xml += "          <\(sifPrefix):IndicadorMultiplesOT>N</\(sifPrefix):IndicadorMultiplesOT>\n"
        xml += "        </\(sifPrefix):SistemaInformatico>\n"
        return xml
    }

    // MARK: - Helpers

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func decimalString(_ value: Decimal) -> String {
        let handler = NSDecimalNumberHandler(
            roundingMode: .bankers,
            scale: 2,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        let rounded = NSDecimalNumber(decimal: value).rounding(accordingToBehavior: handler)
        return String(format: "%.2f", rounded.doubleValue)
    }

    private static func dateString(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private static func timestampString(_ date: Date) -> String {
        timestampFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: "Europe/Madrid")
        return formatter
    }()

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: "Europe/Madrid")
        return formatter
    }()
}
