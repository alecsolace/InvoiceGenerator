import SwiftData
import SwiftUI

/// iPhone-specific invoice creation view matching the Stitch "Nueva Factura - Verifactu" design.
///
/// This view wraps the existing `AddInvoiceView` form logic with iOS-specific design
/// chrome: status badge, VeriFACTU badge, and streamlined layout.
struct iOSNewInvoiceView: View {
    let viewModel: InvoiceViewModel
    let seed: InvoiceComposerSeed
    let onComplete: ((Invoice) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Issuer.name)]) private var issuers: [Issuer]

    init(
        viewModel: InvoiceViewModel,
        seed: InvoiceComposerSeed = .quick,
        onComplete: ((Invoice) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.seed = seed
        self.onComplete = onComplete
    }

    var body: some View {
        AddInvoiceView(viewModel: viewModel, seed: seed) { created in
            onComplete?(created)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            statusBar
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            draftBadge

            Spacer()

            if isVerifactuEnabled {
                verifactuBadge
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.appBackground)
    }

    private var draftBadge: some View {
        Text(String(localized: "Borrador"))
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.gray.opacity(0.12), in: Capsule())
            .foregroundStyle(.gray)
    }

    private var verifactuBadge: some View {
        Label(String(localized: "VeriFactu Ready"), systemImage: "checkmark.seal.fill")
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.green.opacity(0.12), in: Capsule())
            .foregroundStyle(.green)
    }

    private var isVerifactuEnabled: Bool {
        issuers.contains(where: { $0.verifactuEnabled })
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Invoice.self, InvoiceItem.self, CompanyProfile.self,
        Client.self, Issuer.self, InvoiceTemplate.self, InvoiceTemplateItem.self,
        TaxBreakdown.self, VerifactuRecord.self,
        configurations: config
    )
    let vm = InvoiceViewModel(modelContext: container.mainContext)
    return iOSNewInvoiceView(viewModel: vm, seed: .quick)
        .modelContainer(container)
        .environmentObject(try! SubscriptionService(storeConfiguration: .testing, startTasks: false))
}
