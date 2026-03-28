import Foundation

// MARK: - Invoice Type (Tipo de Factura)

/// Classification of invoice types per RD 1619/2012 and VeriFACTU specification.
enum InvoiceType: String, Codable, CaseIterable, Identifiable {
    /// Factura completa (Art. 6 RD 1619/2012)
    case f1 = "F1"
    /// Factura simplificada (Art. 7 RD 1619/2012)
    case f2 = "F2"
    /// Factura emitida como sustitutiva de simplificada
    case f3 = "F3"
    /// Factura rectificativa por diferencias (Art. 80.1-2 LIVA)
    case r1 = "R1"
    /// Factura rectificativa por artículo 80.3 LIVA
    case r2 = "R2"
    /// Factura rectificativa en concurso de acreedores (Art. 80.4 LIVA)
    case r3 = "R3"
    /// Factura rectificativa resto (otros supuestos)
    case r4 = "R4"
    /// Factura rectificativa en facturas simplificadas
    case r5 = "R5"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .f1: return String(localized: "F1 - Full Invoice", comment: "Invoice type F1")
        case .f2: return String(localized: "F2 - Simplified Invoice", comment: "Invoice type F2")
        case .f3: return String(localized: "F3 - Replacement for Simplified", comment: "Invoice type F3")
        case .r1: return String(localized: "R1 - Corrective (Differences)", comment: "Invoice type R1")
        case .r2: return String(localized: "R2 - Corrective (Art. 80.3)", comment: "Invoice type R2")
        case .r3: return String(localized: "R3 - Corrective (Insolvency)", comment: "Invoice type R3")
        case .r4: return String(localized: "R4 - Corrective (Other)", comment: "Invoice type R4")
        case .r5: return String(localized: "R5 - Corrective (Simplified)", comment: "Invoice type R5")
        }
    }

    var isRectificativa: Bool {
        switch self {
        case .r1, .r2, .r3, .r4, .r5: return true
        default: return false
        }
    }
}

// MARK: - Tax Regime Key (Clave de Régimen Fiscal)

/// Tax regime classification per AEAT VeriFACTU specification.
enum TaxRegimeKey: String, Codable, CaseIterable, Identifiable {
    /// Operación en régimen general
    case general = "01"
    /// Exportación
    case export = "02"
    /// Operaciones a las que se aplique el régimen especial de bienes usados
    case usedGoods = "03"
    /// Régimen especial de inversión del sujeto pasivo
    case reverseCharge = "04"
    /// Régimen especial de agencias de viajes
    case travelAgencies = "05"
    /// Régimen especial de grupo de entidades en IVA
    case entityGroup = "06"
    /// Régimen especial del criterio de caja
    case cashBasis = "07"
    /// Operaciones sujetas al IPSI/IGIC
    case ipsiIgic = "08"
    /// Adquisiciones intracomunitarias de bienes
    case intraCommunityAcquisitions = "09"
    /// Facturación de prestaciones de servicios intracomunitarios
    case intraCommunityServices = "10"
    /// Cobros por cuenta de terceros
    case thirdPartyCollections = "11"
    /// Operaciones de arrendamiento de local de negocio
    case businessRental = "12"
    /// Factura con varios destinatarios
    case multipleRecipients = "14"
    /// Subvenciones y pagos de AAPP
    case publicSubsidies = "15"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .general: return String(localized: "01 - General Regime", comment: "Tax regime general")
        case .export: return String(localized: "02 - Export", comment: "Tax regime export")
        case .usedGoods: return String(localized: "03 - Used Goods", comment: "Tax regime used goods")
        case .reverseCharge: return String(localized: "04 - Reverse Charge", comment: "Tax regime reverse charge")
        case .travelAgencies: return String(localized: "05 - Travel Agencies", comment: "Tax regime travel agencies")
        case .entityGroup: return String(localized: "06 - Entity Group", comment: "Tax regime entity group")
        case .cashBasis: return String(localized: "07 - Cash Basis", comment: "Tax regime cash basis")
        case .ipsiIgic: return String(localized: "08 - IPSI/IGIC", comment: "Tax regime IPSI/IGIC")
        case .intraCommunityAcquisitions: return String(localized: "09 - Intra-EU Acquisitions", comment: "Tax regime intra-EU acquisitions")
        case .intraCommunityServices: return String(localized: "10 - Intra-EU Services", comment: "Tax regime intra-EU services")
        case .thirdPartyCollections: return String(localized: "11 - Third Party Collections", comment: "Tax regime third party")
        case .businessRental: return String(localized: "12 - Business Rental", comment: "Tax regime business rental")
        case .multipleRecipients: return String(localized: "14 - Multiple Recipients", comment: "Tax regime multiple recipients")
        case .publicSubsidies: return String(localized: "15 - Public Subsidies", comment: "Tax regime public subsidies")
        }
    }
}

// MARK: - Standard VAT Rates

/// Common Spanish VAT rates for quick selection in the UI.
enum StandardVATRate: Decimal, CaseIterable, Identifiable {
    case general = 21
    case reduced = 10
    case superReduced = 4
    case exempt = 0

    var id: Decimal { rawValue }

    var localizedTitle: String {
        switch self {
        case .general: return String(localized: "General (21%)", comment: "VAT rate general")
        case .reduced: return String(localized: "Reduced (10%)", comment: "VAT rate reduced")
        case .superReduced: return String(localized: "Super-reduced (4%)", comment: "VAT rate super-reduced")
        case .exempt: return String(localized: "Exempt (0%)", comment: "VAT rate exempt")
        }
    }
}

// MARK: - VeriFACTU Record Status

/// Tracks the lifecycle of a VeriFACTU registry record submission to AEAT.
enum VerifactuRecordStatus: String, Codable, CaseIterable, Identifiable {
    /// Record generated locally but not yet submitted
    case pending = "Pending"
    /// Record submitted to AEAT, awaiting response
    case submitted = "Submitted"
    /// Record accepted by AEAT
    case accepted = "Accepted"
    /// Record rejected by AEAT
    case rejected = "Rejected"
    /// Cancellation record sent
    case cancelled = "Cancelled"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .pending: return String(localized: "Pending", comment: "Verifactu status pending")
        case .submitted: return String(localized: "Submitted", comment: "Verifactu status submitted")
        case .accepted: return String(localized: "Accepted", comment: "Verifactu status accepted")
        case .rejected: return String(localized: "Rejected", comment: "Verifactu status rejected")
        case .cancelled: return String(localized: "Cancelled", comment: "Verifactu status cancelled")
        }
    }
}

// MARK: - Client Location Type

/// Classification of client location for tax purposes.
enum ClientLocationType: String, Codable, CaseIterable, Identifiable {
    case national = "National"
    case intraEU = "IntraEU"
    case extraEU = "ExtraEU"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .national: return String(localized: "National (Spain)", comment: "Client location national")
        case .intraEU: return String(localized: "Intra-EU", comment: "Client location intra-EU")
        case .extraEU: return String(localized: "Extra-EU", comment: "Client location extra-EU")
        }
    }
}

// MARK: - Correction Method

/// Method used for corrective invoices (rectificativas).
enum CorrectionMethod: String, Codable, CaseIterable, Identifiable {
    /// Rectificación por diferencias
    case differences = "I"
    /// Rectificación por sustitución
    case substitution = "S"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .differences: return String(localized: "By Differences", comment: "Correction method differences")
        case .substitution: return String(localized: "By Substitution", comment: "Correction method substitution")
        }
    }
}
