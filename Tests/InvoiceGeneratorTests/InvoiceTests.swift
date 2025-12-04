import XCTest
import SwiftData
@testable import InvoiceGenerator

/// Tests for Invoice model
final class InvoiceTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: Invoice.self, InvoiceItem.self, CompanyProfile.self,
            configurations: config
        )
        modelContext = modelContainer.mainContext
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
    }
    
    func testInvoiceCreation() throws {
        let invoice = Invoice(
            invoiceNumber: "INV-001",
            clientName: "Test Client"
        )
        
        XCTAssertEqual(invoice.invoiceNumber, "INV-001")
        XCTAssertEqual(invoice.clientName, "Test Client")
        XCTAssertEqual(invoice.status, .draft)
        XCTAssertEqual(invoice.totalAmount, 0)
    }
    
    func testInvoiceCalculateTotal() throws {
        let invoice = Invoice(
            invoiceNumber: "INV-001",
            clientName: "Test Client"
        )
        
        let item1 = InvoiceItem(description: "Item 1", quantity: 2, unitPrice: 10.00)
        let item2 = InvoiceItem(description: "Item 2", quantity: 1, unitPrice: 25.00)
        
        invoice.items = [item1, item2]
        invoice.calculateTotal()
        
        XCTAssertEqual(invoice.totalAmount, 45.00)
    }
    
    func testInvoiceItemTotalCalculation() throws {
        let item = InvoiceItem(description: "Test Item", quantity: 3, unitPrice: 15.50)
        
        XCTAssertEqual(item.total, 46.50)
    }
    
    func testInvoiceNumberGeneration() throws {
        let invoiceNumber = String.generateInvoiceNumber()
        
        XCTAssertTrue(invoiceNumber.hasPrefix("INV-"))
        XCTAssertTrue(invoiceNumber.count > 10)
    }
}
