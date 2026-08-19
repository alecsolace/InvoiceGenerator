import PDFKit
import SwiftUI

// MARK: - Accessibility

/// Accessibility identifiers for every surface in the "view the invoice PDF"
/// flow. `PDFViewerUITests` drives the flow through these rather than through
/// localized titles, so the tests keep working when the copy changes.
///
/// The UI test target can't link the app module, so it repeats these literals —
/// keep the two lists in sync when editing either side.
enum PDFPreviewAccessibility {
    static let viewer = "pdf-viewer"
    static let closeButton = "pdf-preview-close"
    static let shareButton = "pdf-preview-share"
    static let invoiceDetailMenu = "invoice-detail-more"
    static let invoiceDetailViewPDF = "invoice-detail-view-pdf"
    static let invoiceDetailSharePDF = "invoice-detail-share-pdf"
}

/// Identifiable payload for a full-screen PDF preview. Driving a `fullScreenCover`
/// off an `item:` binding (rather than a `Bool` alongside a separately-set
/// document) guarantees the cover can never present with empty content — the
/// previous `isPresented:` + `if let` shape could momentarily present a blank,
/// unrecoverable full-screen cover if the two state writes landed in separate
/// view updates (as happened when triggered from a toolbar `Menu` action).
struct PDFPreviewItem: Identifiable {
    let id = UUID()
    let document: PDFDocument
    /// Non-nil when the preview should offer a share action (e.g. the invoice
    /// detail "Ver PDF" flow); nil for previews that don't (e.g. the inline
    /// preview card's full-screen tap-to-expand, which has its own share button).
    let shareURL: URL?
    let title: String
}

/// Identifiable payload for a share sheet, for the same reason as `PDFPreviewItem`.
struct PDFShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// Shared PDFKit host used by every PDF preview surface in the app. Takes a
/// `PDFDocument` that has already been validated as non-empty by the caller
/// (see `InvoicePDFService`), so this view never has to represent a "no PDF"
/// state itself.
struct PDFKitView: View {
    let document: PDFDocument

    var body: some View {
        #if canImport(UIKit)
        PDFKitRepresentable(document: document)
        #elseif canImport(AppKit)
        PDFKitNSRepresentable(document: document)
        #else
        EmptyView()
        #endif
    }
}

#if canImport(UIKit)
/// Re-applies size-to-fit on every layout pass rather than once at assignment
/// time — `autoScales` alone only computes its scale against whatever frame
/// exists the moment the document is set, which is what produced the
/// mis-scaled portrait preview a prior fix attempted to patch with a
/// `DispatchQueue.main.async` hop instead of fixing the actual layout timing.
private final class SizeToFitPDFView: PDFView {
    override func layoutSubviews() {
        super.layoutSubviews()
        guard document != nil, bounds.width > 0, bounds.height > 0 else { return }
        scaleFactor = scaleFactorForSizeToFit
    }
}

private struct PDFKitRepresentable: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = SizeToFitPDFView()
        view.autoScales = true
        view.displayDirection = .vertical
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .systemBackground
        view.document = document
        view.accessibilityIdentifier = PDFPreviewAccessibility.viewer
        applyPageCount(document.pageCount, to: view)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document !== document {
            uiView.document = document
        }
        applyPageCount(document.pageCount, to: uiView)
    }

    /// Publishes the loaded page count as the host view's accessibility value so
    /// UI tests can tell "the viewer is on screen" apart from "the viewer is on
    /// screen showing nothing" — the blank-preview regression this flow keeps
    /// hitting. `PDFView` is a container rather than an accessibility element, so
    /// this value is never spoken by VoiceOver (PDFKit exposes the page contents
    /// themselves) and therefore isn't user-facing copy.
    private func applyPageCount(_ pageCount: Int, to view: PDFView) {
        view.accessibilityValue = String(pageCount)
    }
}
#elseif canImport(AppKit)
private struct PDFKitNSRepresentable: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayDirection = .vertical
        view.displayMode = .singlePageContinuous
        view.document = document
        view.setAccessibilityIdentifier(PDFPreviewAccessibility.viewer)
        view.setAccessibilityValue(String(document.pageCount))
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document !== document {
            nsView.document = document
        }
        nsView.setAccessibilityValue(String(document.pageCount))
    }
}
#endif

#if canImport(UIKit)
/// Shared full-screen PDF preview, used by both invoice detail screens' PDF
/// covers. `@Environment(\.dismiss)` is read here rather than by the presenting
/// view, so it resolves against this screen's own cover presentation instead of
/// popping whatever navigation stack the cover was presented from.
struct PDFPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    let item: PDFPreviewItem

    var body: some View {
        NavigationStack {
            PDFKitView(document: item.document)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Cerrar")) { dismiss() }
                            .accessibilityIdentifier(PDFPreviewAccessibility.closeButton)
                    }
                    if let shareURL = item.shareURL {
                        ToolbarItem(placement: .primaryAction) {
                            // ShareLink presents from within this screen's own hosting
                            // controller, so there's no dismiss-then-present race with
                            // the cover itself (a previous "dismiss cover, then present
                            // share sheet" sequence could lose the share sheet entirely
                            // if the cover was still animating out).
                            ShareLink(item: shareURL) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityIdentifier(PDFPreviewAccessibility.shareButton)
                        }
                    }
                }
        }
    }
}
#endif
