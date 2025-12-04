import XCTest
import SwiftData
@testable import InvoiceGenerator

/// Tests for InvoiceViewModel
final class InvoiceViewModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var viewModel: InvoiceViewModel!
    
    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: Invoice.self, InvoiceItem.self, CompanyProfile.self,
            configurations: config
        )
        modelContext = modelContainer.mainContext
        viewModel = InvoiceViewModel(modelContext: modelContext)
    }
    
    override func tearDown() async throws {
        // Objects will be automatically deallocated by ARC
    }
    
    func testCreateInvoice() throws {
        viewModel.createInvoice(
            invoiceNumber: "INV-TEST-001",
            clientName: "Test Client",
            clientEmail: "test@example.com"
        )
        
        XCTAssertEqual(viewModel.invoices.count, 1)
        XCTAssertEqual(viewModel.invoices.first?.invoiceNumber, "INV-TEST-001")
        XCTAssertEqual(viewModel.invoices.first?.clientName, "Test Client")
    }
    
    func testAddItemToInvoice() throws {
        viewModel.createInvoice(
            invoiceNumber: "INV-TEST-002",
            clientName: "Test Client"
        )
        
        guard let invoice = viewModel.invoices.first else {
            XCTFail("Invoice not created")
            return
        }
        
        viewModel.addItem(
            to: invoice,
            description: "Test Item",
            quantity: 2,
            unitPrice: 50.00
        )
        
        XCTAssertEqual(invoice.items.count, 1)
        XCTAssertEqual(invoice.totalAmount, 100.00)
    }
    
    func testUpdateInvoiceStatus() throws {
        viewModel.createInvoice(
            invoiceNumber: "INV-TEST-003",
            clientName: "Test Client"
        )
        
        guard let invoice = viewModel.invoices.first else {
            XCTFail("Invoice not created")
            return
        }
        
        viewModel.updateStatus(invoice, status: .paid)
        
        XCTAssertEqual(invoice.status, .paid)
    }
    
    func testDeleteInvoice() throws {
        viewModel.createInvoice(
            invoiceNumber: "INV-TEST-004",
            clientName: "Test Client"
        )
        
        XCTAssertEqual(viewModel.invoices.count, 1)
        
        guard let invoice = viewModel.invoices.first else {
            XCTFail("Invoice not created")
            return
        }
        
        viewModel.deleteInvoice(invoice)
        
        XCTAssertEqual(viewModel.invoices.count, 0)
    }
}
