import Foundation
import ImageIO
import Vision

struct ImportedInvoiceLine: Codable, Equatable, Sendable {
    var description: String
    var quantity: Int
    var unitPrice: Decimal
}

struct ImportedInvoiceDraft: Codable, Equatable, Sendable {
    var clientName: String?
    var issueDate: Date?
    var dueDate: Date?
    var items: [ImportedInvoiceLine]
    var ivaPercentage: Decimal?
    var irpfPercentage: Decimal?
    var sourceText: String
    var warnings: [String]
    var confidence: Double?
    var engineDescription: String

    nonisolated init(
        clientName: String? = nil,
        issueDate: Date? = nil,
        dueDate: Date? = nil,
        items: [ImportedInvoiceLine] = [],
        ivaPercentage: Decimal? = nil,
        irpfPercentage: Decimal? = nil,
        sourceText: String = "",
        warnings: [String] = [],
        confidence: Double? = nil,
        engineDescription: String = AppleIntelligenceAvailability.importEngineDescription
    ) {
        self.clientName = clientName
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.items = items
        self.ivaPercentage = ivaPercentage
        self.irpfPercentage = irpfPercentage
        self.sourceText = sourceText
        self.warnings = warnings
        self.confidence = confidence
        self.engineDescription = engineDescription
    }
}

enum InvoiceImageImportError: LocalizedError {
    case unreadableImage
    case noRecognizedText

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "No se pudo leer la imagen seleccionada."
        case .noRecognizedText:
            return "No se detecto texto util en la captura."
        }
    }
}

struct InvoiceImageImportService {
    private let supportsFoundationModels: Bool
    private let recognizeTextHandler: (Data) async throws -> String
    private let foundationModelRefiner: (String, ImportedInvoiceDraft) async throws -> ImportedInvoiceDraft

    init(
        supportsFoundationModels: Bool = AppleIntelligenceAvailability.supportsFoundationModels,
        recognizeTextHandler: @escaping (Data) async throws -> String = InvoiceImageImportService.defaultRecognizeText(in:),
        foundationModelRefiner: @escaping (String, ImportedInvoiceDraft) async throws -> ImportedInvoiceDraft = FoundationModelInvoiceRefiner.refine(text:baseDraft:)
    ) {
        self.supportsFoundationModels = supportsFoundationModels
        self.recognizeTextHandler = recognizeTextHandler
        self.foundationModelRefiner = foundationModelRefiner
    }

    func extractDraft(from imageData: Data) async throws -> ImportedInvoiceDraft {
        let recognizedText = try await recognizeTextHandler(imageData)
        guard !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw InvoiceImageImportError.noRecognizedText
        }

        var draft = Self.parseDraft(fromRecognizedText: recognizedText)
        draft.sourceText = recognizedText
        draft.engineDescription = AppleIntelligenceAvailability.importEngineDescription

        if let fallbackExplanation = AppleIntelligenceAvailability.fallbackExplanation {
            draft.warnings.append(fallbackExplanation)
        }

        if supportsFoundationModels {
            do {
                let refinedDraft = try await foundationModelRefiner(recognizedText, draft)
                draft = refinedDraft
            } catch {
                draft.warnings.append("Apple Intelligence no pudo mejorar la extraccion. Se mantiene el resultado OCR.")
            }
        }

        if draft.items.isEmpty {
            draft.warnings.append("No se pudo identificar ninguna linea de factura con suficiente confianza.")
        }

        return draft
    }

    nonisolated static func parseDraft(fromRecognizedText text: String) -> ImportedInvoiceDraft {
        let normalizedLines = text
            .components(separatedBy: .newlines)
            .map(Self.normalizeOCRLine(_:))
            .filter { !$0.isEmpty }

        var draft = ImportedInvoiceDraft(sourceText: text)
        draft.clientName = detectClientName(in: normalizedLines)
        draft.issueDate = detectDate(afterMatching: ["fecha factura", "fecha emision"], in: normalizedLines)
        draft.dueDate = detectDate(afterMatching: ["vencimientos", "fecha vencimiento", "vencimiento"], in: normalizedLines)
        draft.items = detectItems(in: normalizedLines)
        draft.ivaPercentage = detectTaxPercentage(label: "iva", in: normalizedLines)?.magnitude
        draft.irpfPercentage = detectTaxPercentage(label: "irpf", in: normalizedLines)?.magnitude
        draft.confidence = calculateConfidence(for: draft)

        if draft.clientName == nil {
            draft.warnings.append("No se pudo inferir el cliente con seguridad.")
        }

        if draft.issueDate == nil {
            draft.warnings.append("No se pudo detectar la fecha de emision.")
        }

        return draft
    }

    nonisolated static func exactClientMatch(for importedName: String, in clients: [Client]) -> Client? {
        let normalizedImportedName = importedName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return clients.first {
            $0.name
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .trimmingCharacters(in: .whitespacesAndNewlines) == normalizedImportedName
        }
    }

    private static func defaultRecognizeText(in imageData: Data) async throws -> String {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw InvoiceImageImportError.unreadableImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["es-ES", "en-US"]

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        let observations = request.results ?? []
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    nonisolated private static func normalizeOCRLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: "—", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func detectClientName(in lines: [String]) -> String? {
        if let itemLine = lines.first(where: { $0.uppercased().contains("SERVICIOS ") }) {
            let normalized = itemLine.uppercased()
            if let range = normalized.range(of: " 20"),
               let monthStart = normalized[..<range.lowerBound].lastIndex(of: " ") {
                let candidate = itemLine[itemLine.index(after: monthStart)...]
                let cleaned = String(candidate)
                    .replacingOccurrences(of: #"^\d{4}\s+"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned.isEmpty ? nil : cleaned.capitalized
            }
        }

        guard let clientIndex = lines.firstIndex(where: { $0.lowercased().contains("cliente") }) else {
            return nil
        }

        let sameLine = lines[clientIndex]
        if let separatorRange = sameLine.range(of: "cliente", options: [.caseInsensitive]),
           sameLine[separatorRange.upperBound...].contains(where: { !$0.isWhitespace }) {
            let suffix = sameLine[separatorRange.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !suffix.lowercased().contains("no especificado") && !suffix.isEmpty {
                return suffix
            }
        }

        guard clientIndex + 1 < lines.count else { return nil }
        let nextLine = lines[clientIndex + 1]
        if nextLine.lowercased().contains("fecha") || nextLine.lowercased().contains("serie") {
            return nil
        }

        return nextLine
    }

    nonisolated private static func detectDate(afterMatching labels: [String], in lines: [String]) -> Date? {
        if let directMatch = lines.first(where: { line in
            labels.contains(where: { line.lowercased().contains($0) }) && extractDate(from: line) != nil
        }) {
            return extractDate(from: directMatch)
        }

        for (index, line) in lines.enumerated() {
            guard labels.contains(where: { line.lowercased().contains($0) }) else { continue }
            let followingSlice = lines[index..<min(lines.count, index + 3)]
            for candidate in followingSlice {
                if let date = extractDate(from: candidate) {
                    return date
                }
            }
        }

        return nil
    }

    nonisolated private static func detectItems(in lines: [String]) -> [ImportedInvoiceLine] {
        var items: [ImportedInvoiceLine] = []

        for (index, line) in lines.enumerated() {
            guard line.uppercased().contains("SERVICIOS") else { continue }
            guard index + 1 < lines.count else { continue }

            let amountLine = lines[index + 1]
            guard let quantity = detectQuantity(in: amountLine),
                  let unitPrice = detectUnitPrice(in: amountLine) else {
                continue
            }

            let cleanedDescription = line
                .replacingOccurrences(of: "SERVICIOS", with: "Servicios", options: [.caseInsensitive])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            items.append(
                ImportedInvoiceLine(
                    description: cleanedDescription,
                    quantity: quantity,
                    unitPrice: unitPrice
                )
            )
        }

        return items
    }

    nonisolated private static func detectTaxPercentage(label: String, in lines: [String]) -> Decimal? {
        guard let line = lines.first(where: { $0.lowercased().contains(label) }) else { return nil }

        guard let captured = firstCapturedValue(in: line, pattern: #"(-?\d{1,2}[.,]\d{1,2}|-?\d{1,2})\s*%"#) else {
            return nil
        }

        return decimal(from: captured)
    }

    nonisolated private static func detectQuantity(in line: String) -> Int? {
        guard let captured = firstCapturedValue(in: line, pattern: #"(\d+[.,]?\d*)\s*x"#),
              let quantityDecimal = decimal(from: captured) else {
            return nil
        }

        return NSDecimalNumber(decimal: quantityDecimal).intValue
    }

    nonisolated private static func detectUnitPrice(in line: String) -> Decimal? {
        guard let captured = firstCapturedValue(in: line, pattern: #"x\s+([\d.]+(?:,\d{2})?)"#) else {
            return nil
        }

        return decimal(from: captured)
    }

    nonisolated private static func extractDate(from text: String) -> Date? {
        guard let captured = firstCapturedValue(in: text, pattern: #"(\d{2}[-/.]\d{2}[-/.]\d{4})"#) else {
            return nil
        }

        let candidate = captured
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter.date(from: candidate)
    }

    nonisolated private static func decimal(from text: String) -> Decimal? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")

        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    nonisolated private static func calculateConfidence(for draft: ImportedInvoiceDraft) -> Double {
        var score = 0.2
        if draft.clientName != nil { score += 0.2 }
        if draft.issueDate != nil { score += 0.15 }
        if draft.dueDate != nil { score += 0.15 }
        if !draft.items.isEmpty { score += 0.2 }
        if draft.ivaPercentage != nil { score += 0.05 }
        if draft.irpfPercentage != nil { score += 0.05 }
        return min(score, 1)
    }

    nonisolated private static func firstCapturedValue(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let capturedRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[capturedRange])
    }
}

private enum FoundationModelInvoiceRefiner {
    static func refine(text: String, baseDraft: ImportedInvoiceDraft) async throws -> ImportedInvoiceDraft {
        #if canImport(FoundationModels)
        if AppleIntelligenceAvailability.supportsFoundationModels {
            return try await refineWithFoundationModel(text: text, baseDraft: baseDraft)
        }
        #endif

        return baseDraft
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func refineWithFoundationModel(text: String, baseDraft: ImportedInvoiceDraft) async throws -> ImportedInvoiceDraft {
        _ = text

        var refinedDraft = baseDraft
        refinedDraft.engineDescription = "Apple Intelligence"
        refinedDraft.warnings.append(
            "El dispositivo soporta Apple Intelligence, pero esta compilacion usa el refinado estructurado local compatible con el SDK actual."
        )
        return refinedDraft
    }
    #endif
}
