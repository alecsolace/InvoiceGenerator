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
