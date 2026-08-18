import XCTest

/// Regression coverage for the invoice PDF viewer flow, which has broken twice
/// on device without any test catching it first:
/// - `c199da2` "Fix landscape rotation reset and add portrait PDF access on iPhone"
/// - issue #51, where "Ver PDF" from invoice detail rendered a blank,
///   unresponsive full-screen cover in portrait
///
/// Every assertion here is aimed at one of those two failure shapes: the viewer
/// must actually carry pages (not just present an empty cover), it must stay put
/// and stay laid out across a rotation round trip, it must be dismissable, and
/// it must be able to hand the PDF off to the share sheet.
final class PDFViewerUITests: XCTestCase {

    /// Mirrors `PDFPreviewAccessibility` in the app target. The UI test target
    /// can't link the app module, so these literals are repeated here — keep the
    /// two lists in sync.
    private enum ID {
        static let viewer = "pdf-viewer"
        static let closeButton = "pdf-preview-close"
        static let shareButton = "pdf-preview-share"
        static let invoiceDetailMenu = "invoice-detail-more"
        static let invoiceDetailViewPDF = "invoice-detail-view-pdf"
        static let invoiceDetailSharePDF = "invoice-detail-share-pdf"
    }

    /// The draft invoice seeded by `UITEST_SEED_SAMPLE_DATA`.
    private let seededInvoiceNumber = "1042"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
    }

    // MARK: - Tests

    /// The core issue #51 regression: opening the PDF in portrait must show a
    /// document with pages, and the nav bar must be able to dismiss it again.
    @MainActor
    func testViewPDFFromInvoiceDetailRendersContentInPortrait() throws {
        let app = launchSeededApp()
        openInvoiceDetail(in: app)
        openPDFViewer(in: app)

        let viewer = pdfViewer(in: app)
        XCTAssertTrue(
            viewer.waitForExistence(timeout: 15),
            "The PDF viewer never appeared after choosing 'Ver PDF'."
        )
        assertViewerShowsPages(viewer, in: app)

        let closeButton = app.buttons[ID.closeButton]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "The PDF preview has no close button.")
        XCTAssertTrue(closeButton.isHittable, "The PDF preview's close button is not tappable.")
        closeButton.tap()

        XCTAssertTrue(
            closeButton.waitForNonExistence(timeout: 5),
            "The PDF preview stayed on screen after tapping close."
        )
        XCTAssertTrue(
            app.buttons[ID.invoiceDetailMenu].waitForExistence(timeout: 5),
            "Dismissing the PDF preview did not return to the invoice detail screen."
        )
    }

    #if os(iOS)
    /// Regression target of `c199da2`: rotating while the PDF is open must
    /// relayout the viewer in place, not tear the flow down or leave a blank
    /// cover behind.
    @MainActor
    func testPDFViewerSurvivesRotationToLandscapeAndBack() throws {
        let app = launchSeededApp()
        openInvoiceDetail(in: app)
        openPDFViewer(in: app)

        let viewer = pdfViewer(in: app)
        XCTAssertTrue(viewer.waitForExistence(timeout: 15), "The PDF viewer never appeared.")
        let portraitFrame = viewer.frame
        XCTAssertGreaterThan(
            portraitFrame.height,
            portraitFrame.width,
            "Expected a portrait-shaped viewer before rotating."
        )

        XCUIDevice.shared.orientation = .landscapeLeft
        assertViewerStillUsable(viewer, in: app, orientation: "landscape")
        let landscapeFrame = viewer.frame
        XCTAssertGreaterThan(
            landscapeFrame.width,
            landscapeFrame.height,
            "The PDF viewer did not relayout for landscape."
        )

        XCUIDevice.shared.orientation = .portrait
        assertViewerStillUsable(viewer, in: app, orientation: "portrait")
        XCTAssertGreaterThan(
            viewer.frame.height,
            viewer.frame.width,
            "The PDF viewer did not relayout back to portrait."
        )

        app.buttons[ID.closeButton].tap()
        XCTAssertTrue(
            app.buttons[ID.invoiceDetailMenu].waitForExistence(timeout: 5),
            "After a rotation round trip the PDF preview no longer dismisses back to invoice detail."
        )
    }
    #endif

    /// The preview's own share affordance must reach the system share sheet —
    /// this is the path that previously lost the sheet to a dismiss/present race.
    @MainActor
    func testPDFViewerSharesTheOpenDocument() throws {
        let app = launchSeededApp()
        openInvoiceDetail(in: app)
        openPDFViewer(in: app)

        XCTAssertTrue(pdfViewer(in: app).waitForExistence(timeout: 15), "The PDF viewer never appeared.")

        let shareButton = app.buttons[ID.shareButton]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 5), "The PDF preview has no share button.")
        shareButton.tap()

        XCTAssertTrue(
            waitForShareSheet(in: app),
            "Sharing from the PDF preview did not present the system share sheet."
        )
        dismissShareSheet(in: app)
    }

    /// "Compartir PDF" straight from invoice detail exports without opening the
    /// viewer first.
    @MainActor
    func testSharePDFFromInvoiceDetailPresentsShareSheet() throws {
        let app = launchSeededApp()
        openInvoiceDetail(in: app)

        app.buttons[ID.invoiceDetailMenu].tap()
        let shareAction = app.buttons[ID.invoiceDetailSharePDF]
        XCTAssertTrue(shareAction.waitForExistence(timeout: 5), "Invoice detail has no 'Compartir PDF' action.")
        shareAction.tap()

        XCTAssertTrue(
            waitForShareSheet(in: app),
            "'Compartir PDF' did not present the system share sheet."
        )
        dismissShareSheet(in: app)
    }

    // MARK: - Flow helpers

    private func launchSeededApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "UITEST_USE_IN_MEMORY_STORE",
            "UITEST_SKIP_ONBOARDING",
            "UITEST_SEED_SAMPLE_DATA"
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Inicio"].waitForExistence(timeout: 10))
        return app
    }

    private func openInvoiceDetail(in app: XCUIApplication) {
        app.tabBars.buttons["Facturas"].tap()

        let invoiceRow = app.staticTexts[seededInvoiceNumber]
        XCTAssertTrue(invoiceRow.waitForExistence(timeout: 10), "The seeded invoice never appeared in the list.")
        invoiceRow.tap()

        XCTAssertTrue(
            app.buttons[ID.invoiceDetailMenu].waitForExistence(timeout: 10),
            "The invoice detail screen never appeared."
        )
    }

    private func openPDFViewer(in app: XCUIApplication) {
        app.buttons[ID.invoiceDetailMenu].tap()

        let viewAction = app.buttons[ID.invoiceDetailViewPDF]
        XCTAssertTrue(viewAction.waitForExistence(timeout: 5), "Invoice detail has no 'Ver PDF' action.")
        viewAction.tap()
    }

    /// The PDFKit host is a plain container view, so it surfaces as an "other"
    /// element rather than a typed one — match on identifier alone.
    private func pdfViewer(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: ID.viewer).firstMatch
    }

    // MARK: - Assertion helpers

    /// A blank preview is the exact failure mode of issue #51, and it looks
    /// identical to a healthy one if you only assert that the cover exists. The
    /// viewer publishes its loaded page count as its accessibility value, so
    /// assert on that as well as on the laid-out frame.
    private func assertViewerShowsPages(
        _ viewer: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let pageCount = Int(viewer.value as? String ?? "")
        XCTAssertNotNil(pageCount, "The PDF viewer did not report a page count.", file: file, line: line)
        XCTAssertGreaterThan(
            pageCount ?? 0,
            0,
            "The PDF viewer is showing a document with no pages — a blank preview.",
            file: file,
            line: line
        )

        let window = app.windows.firstMatch.frame
        let frame = viewer.frame
        XCTAssertGreaterThan(
            frame.width,
            window.width * 0.8,
            "The PDF viewer is not filling the width of the screen.",
            file: file,
            line: line
        )
        XCTAssertGreaterThan(
            frame.height,
            window.height * 0.5,
            "The PDF viewer is not filling the height of the screen.",
            file: file,
            line: line
        )
    }

    /// After a rotation the viewer must still be present, still carry pages, and
    /// still respond to input — "blank and unresponsive" is the shape both past
    /// regressions took.
    private func assertViewerStillUsable(
        _ viewer: XCUIElement,
        in app: XCUIApplication,
        orientation: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let closeButton = app.buttons[ID.closeButton]
        XCTAssertTrue(
            closeButton.waitForExistence(timeout: 5),
            "The PDF preview lost its close button in \(orientation).",
            file: file,
            line: line
        )
        XCTAssertTrue(
            closeButton.isHittable,
            "The PDF preview became unresponsive in \(orientation).",
            file: file,
            line: line
        )
        XCTAssertTrue(viewer.exists, "The PDF viewer disappeared in \(orientation).", file: file, line: line)
        assertViewerShowsPages(viewer, in: app, file: file, line: line)
    }

    // MARK: - Share sheet helpers

    /// `UIActivityViewController` doesn't expose a single stable identifier
    /// across OS versions, so accept any of the markers it is known to publish.
    private func shareSheetMarkers(in app: XCUIApplication) -> [XCUIElement] {
        [
            app.otherElements["ActivityListView"],
            app.otherElements["UIActivityContentView"],
            app.collectionViews["ActivityListView"],
            app.sheets.firstMatch
        ]
    }

    private func waitForShareSheet(in app: XCUIApplication, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if shareSheetMarkers(in: app).contains(where: { $0.exists }) {
                return true
            }
            _ = app.otherElements["ActivityListView"].waitForExistence(timeout: 0.5)
        }
        return false
    }

    /// Best effort — the app is torn down at the end of the test either way, but
    /// leaving the sheet up makes failure screenshots harder to read.
    private func dismissShareSheet(in app: XCUIApplication) {
        for title in ["Close", "Cerrar", "Cancel", "Cancelar"] {
            let button = app.buttons[title]
            if button.exists, button.isHittable {
                button.tap()
                return
            }
        }
        #if os(iOS)
        app.swipeDown()
        #endif
    }
}
