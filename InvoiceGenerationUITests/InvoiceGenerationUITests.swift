import XCTest

final class InvoiceGenerationUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingCanFinishMinimalSetup() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_USE_IN_MEMORY_STORE"]
        app.launch()

        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 5))
        app.buttons["Skip"].tap()

        let companyName = app.textFields["Company Name"]
        XCTAssertTrue(companyName.waitForExistence(timeout: 5))
        companyName.tap()
        companyName.typeText("Acme Studio")

        app.buttons["Finish Setup"].tap()

        XCTAssertTrue(app.tabBars.buttons["Inicio"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeFlowCreatesInvoiceFromFrequentClient() throws {
        let app = launchSeededApp()

        XCTAssertTrue(app.buttons["Facturar"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Facturar"].firstMatch.tap()

        let primary = app.buttons["invoice-composer-primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 5))
        primary.tap()
        primary.tap()

        app.tabBars.buttons["Facturas"].tap()
        XCTAssertTrue(app.staticTexts["ACM-0003"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testClientFlowCreatesInvoiceFromPreferredTemplate() throws {
        let app = launchSeededApp()

        app.tabBars.buttons["Clientes"].tap()
        XCTAssertTrue(app.buttons["Facturar"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Facturar"].firstMatch.tap()

        let primary = app.buttons["invoice-composer-primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 5))
        primary.tap()
        primary.tap()

        app.tabBars.buttons["Facturas"].tap()
        XCTAssertTrue(app.staticTexts["ACM-0003"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDuplicateInvoiceFromDetailCreatesNextMonthInvoice() throws {
        let app = launchSeededApp()

        app.tabBars.buttons["Facturas"].tap()
        XCTAssertTrue(app.staticTexts["ACM-0002"].waitForExistence(timeout: 5))
        app.staticTexts["ACM-0002"].tap()

        let moreButton = app.buttons["Mas"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 5))
        moreButton.tap()
        app.buttons["Duplicar este mes"].tap()

        let primary = app.buttons["invoice-composer-primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 5))
        primary.tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["ACM-0003"].waitForExistence(timeout: 5))
    }

    private func launchSeededApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "UITEST_USE_IN_MEMORY_STORE",
            "UITEST_SKIP_ONBOARDING",
            "UITEST_SEED_SAMPLE_DATA"
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Inicio"].waitForExistence(timeout: 5))
        return app
    }
}
