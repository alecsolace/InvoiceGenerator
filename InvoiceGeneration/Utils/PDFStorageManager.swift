import Foundation
#if os(macOS)
import AppKit
#endif

/// Handles where generated PDFs are stored depending on platform and user preference.
enum PDFStorageManager {
    private static let macDirectoryKey = "macPDFSavePath"

    /// Returns the URL where a PDF with the provided file name should be saved.
    static func targetURL(for fileName: String) -> URL? {
        #if os(macOS)
        let folderURL = macSaveDirectory() ?? defaultDocumentsDirectory()
        return folderURL?.appendingPathComponent("\(fileName).pdf")
        #else
        return applicationSupportDirectory()?.appendingPathComponent("\(fileName).pdf")
        #endif
    }

    /// Returns the stable cache URL for an invoice's generated PDF.
    static func cacheURL(for invoice: Invoice) -> URL? {
        #if os(macOS)
        // macOS's target directory is the user's own chosen save folder (see
        // `macSaveDirectory`/`setMacDirectory`), so the file itself is a user-visible
        // artifact — keep it under its display name there, as before.
        return targetURL(for: exportFileName(for: invoice))
        #else
        // iOS's target directory is an internal Application Support cache the user
        // never sees directly, so key it by the invoice's unique id. Invoice numbers
        // are only unique per issuer-client pair (see InvoiceNumberingService), so two
        // different invoices sharing the same display number would otherwise silently
        // overwrite each other's cached PDF.
        return targetURL(for: invoice.id.uuidString)
        #endif
    }

    /// The human-readable file name used when handing a PDF off to share/export UI.
    /// This is the single source of truth for that name — do not reconstruct it elsewhere.
    static func exportFileName(for invoice: Invoice) -> String {
        String(format: NSLocalizedString("Factura_%@", comment: "Saved invoice PDF file name format"), invoice.invoiceNumber)
    }

    /// Returns a URL for the cached PDF under its human-readable export name, so share
    /// sheets and mail composers show a friendly file name instead of the UUID used for
    /// iOS's internal on-disk cache. When the cache is already stored under that name
    /// (macOS), the original file is reused rather than making a redundant copy.
    static func exportURL(copyingFrom cachedURL: URL, for invoice: Invoice) -> URL? {
        let desiredFileName = "\(exportFileName(for: invoice)).pdf"
        if cachedURL.lastPathComponent == desiredFileName {
            return cachedURL
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(desiredFileName)
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: cachedURL, to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    /// One-shot cleanup of legacy `Factura_<number>.pdf` cache files that predate the
    /// per-invoice UUID cache scheme. Those names collided across issuer-client pairs
    /// that reused the same invoice number, so they are no longer read; this just
    /// reclaims the disk space. Safe to call repeatedly.
    static func removeLegacyInvoiceNumberCacheFiles() {
        #if os(macOS)
        guard let folderURL = macSaveDirectory() ?? defaultDocumentsDirectory() else { return }
        #else
        guard let folderURL = applicationSupportDirectory() else { return }
        #endif
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folderURL, includingPropertiesForKeys: nil
        ) else { return }

        for url in contents {
            let name = url.deletingPathExtension().lastPathComponent
            guard url.pathExtension.lowercased() == "pdf", name.hasPrefix("Factura_") else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    #if os(macOS)
    /// Updates the preferred macOS directory path.
    static func setMacDirectory(path: String) {
        UserDefaults.standard.set(path, forKey: macDirectoryKey)
    }
    
    /// Clears the custom macOS directory so the default Documents folder is used.
    static func resetMacDirectory() {
        UserDefaults.standard.removeObject(forKey: macDirectoryKey)
    }
    
    /// Returns the currently configured macOS path or nil if using defaults.
    static var macDirectoryPath: String? {
        UserDefaults.standard.string(forKey: macDirectoryKey)
    }
    
    private static func macSaveDirectory() -> URL? {
        guard let path = macDirectoryPath, !path.isEmpty else {
            return defaultDocumentsDirectory()
        }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        ensureDirectoryExists(at: url)
        return url
    }
    
    private static func defaultDocumentsDirectory() -> URL? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if let url {
            ensureDirectoryExists(at: url)
        }
        return url
    }
    #else
    private static func applicationSupportDirectory() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = base.appendingPathComponent("Invoices", isDirectory: true)
        ensureDirectoryExists(at: folder)
        return folder
    }
    #endif
    
    private static func ensureDirectoryExists(at url: URL) {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        if !exists || !isDirectory.boolValue {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
