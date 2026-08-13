import Foundation
import PDFKit
import SwiftData

/// Single entry point for "give me this invoice's PDF" — used by every view/share
/// call site so they can no longer drift out of sync with each other (each used to
/// reimplement its own disk-check/generate/save logic).
///
/// Also the only place that decides whether a cached PDF is still valid: the cache
/// is keyed by `invoice.pdfLastGeneratedAt` versus `invoice.updatedAt`, so editing
/// an invoice and reopening its PDF always shows the current data instead of a
/// stale render.
enum InvoicePDFService {

    /// A prepared PDF, guaranteed renderable — `document` is never empty.
    struct PreparedPDF {
        let document: PDFDocument
        let url: URL
    }

    enum PDFError: LocalizedError {
        case generationFailed
        case saveFailed

        var errorDescription: String? {
            UserFacingError.message(for: .pdfGeneration)
        }
    }

    /// Returns the invoice's PDF, regenerating it when missing, unreadable, or
    /// older than the invoice's last edit. Regeneration persists the new
    /// `pdfLastGeneratedAt` timestamp via `context` when one is supplied.
    static func preparePDF(for invoice: Invoice, context: ModelContext?) throws -> PreparedPDF {
        guard let cacheURL = PDFStorageManager.cacheURL(for: invoice) else {
            return try regenerate(for: invoice, context: context)
        }

        if isCacheFresh(for: invoice, at: cacheURL),
           let cached = PDFDocument(url: cacheURL),
           cached.pageCount > 0 {
            return PreparedPDF(document: cached, url: cacheURL)
        }

        return try regenerate(for: invoice, context: context)
    }

    // MARK: - Private

    private static func isCacheFresh(for invoice: Invoice, at url: URL) -> Bool {
        guard let generatedAt = invoice.pdfLastGeneratedAt,
              FileManager.default.fileExists(atPath: url.path) else {
            return false
        }
        return generatedAt >= invoice.updatedAt
    }

    private static func regenerate(for invoice: Invoice, context: ModelContext?) throws -> PreparedPDF {
        guard let document = PDFGeneratorService.generateInvoicePDF(invoice: invoice) else {
            throw PDFError.generationFailed
        }
        guard let cacheURL = PDFStorageManager.cacheURL(for: invoice),
              let savedURL = PDFGeneratorService.savePDF(document, fileName: cacheURL.deletingPathExtension().lastPathComponent) else {
            throw PDFError.saveFailed
        }

        invoice.pdfLastGeneratedAt = Date()
        if let context {
            try? context.save()
        }

        return PreparedPDF(document: document, url: savedURL)
    }
}
