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

        let startButton = app.buttons["onboarding-start-button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let companyName = app.textFields["onboarding-company-name-field"]
        XCTAssertTrue(companyName.waitForExistence(timeout: 5))
        companyName.tap()
        companyName.typeText("Acme Studio")

        app.buttons["onboarding-finish-button"].tap()

        XCTAssertTrue(app.tabBars.buttons["Inicio"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOnboardingProfileStepKeepsLowerFieldsAccessible() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_USE_IN_MEMORY_STORE"]
        app.launch()

        let startButton = app.buttons["onboarding-start-button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let addressField = app.textFields["onboarding-address-field"]
        XCTAssertTrue(addressField.waitForExistence(timeout: 5))
        scrollToElement(addressField, in: app)
        XCTAssertTrue(addressField.isHittable)
        XCTAssertTrue(app.buttons["onboarding-finish-button"].isHittable)
        addressField.tap()
        addressField.typeText("Calle Mayor 1")

        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 1) {
            doneButton.tap()
        }

        let taxIdField = app.textFields["onboarding-tax-id-field"]
        XCTAssertTrue(taxIdField.waitForExistence(timeout: 5))
        scrollToElement(taxIdField, in: app, direction: .down)
        XCTAssertTrue(taxIdField.isHittable)
        taxIdField.tap()
        taxIdField.typeText("B12345678")
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

    private enum ScrollDirection {
        case up
        case down
    }

    private func scrollToElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        direction: ScrollDirection = .up,
        maxAttempts: Int = 6
    ) {
        guard element.exists else { return }

        var attempts = 0
        while !element.isHittable && attempts < maxAttempts {
            switch direction {
            case .up:
                app.swipeUp()
            case .down:
                app.swipeDown()
            }
            attempts += 1
        }
    }
}
