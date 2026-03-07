import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleIntelligenceAvailability {
    nonisolated static var supportsFoundationModels: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif

        return false
    }

    nonisolated static var importEngineDescription: String {
        supportsFoundationModels ? "Apple Intelligence" : "OCR local"
    }

    nonisolated static var fallbackExplanation: String? {
        supportsFoundationModels ? nil : "Apple Intelligence no esta disponible en este dispositivo. Se usara OCR local con parsing heuristico."
    }
}
