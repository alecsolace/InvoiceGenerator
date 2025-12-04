# Architecture Documentation

## Overview

InvoiceGenerator follows the **MVVM (Model-View-ViewModel)** architectural pattern, which provides clear separation of concerns and makes the codebase more maintainable, testable, and scalable.

## MVVM Pattern

```
┌─────────────┐         ┌──────────────┐         ┌─────────┐
│    View     │ ◄────── │  ViewModel   │ ◄────── │  Model  │
│   (SwiftUI) │ ──────► │ (Observable) │ ──────► │(SwiftData)
└─────────────┘         └──────────────┘         └─────────┘
      │                        │                       │
      │                        │                       │
  UI Layer            Business Logic            Data Layer
```

### Model Layer

**Location:** `Sources/InvoiceGenerator/Models/`

The Model layer represents the data and business rules of the application.

#### Invoice.swift
```swift
@Model
final class Invoice {
    var id: UUID
    var invoiceNumber: String
    var clientName: String
    // ... other properties
    @Relationship(deleteRule: .cascade, inverse: \InvoiceItem.invoice)
    var items: [InvoiceItem]
}
```

**Responsibilities:**
- Define data structures with SwiftData
- Implement business logic (e.g., `calculateTotal()`)
- Define relationships between entities
- Validate data constraints

**Key Features:**
- Uses `@Model` macro for SwiftData persistence
- Automatic persistence and iCloud sync
- Type-safe relationships between entities
- Timestamps for tracking changes

#### CompanyProfile.swift
```swift
@Model
final class CompanyProfile {
    var companyName: String
    var email: String
    // ... other properties
}
```

**Purpose:** Store company/user information for PDF generation

### ViewModel Layer

**Location:** `Sources/InvoiceGenerator/ViewModels/`

ViewModels act as intermediaries between Views and Models, containing presentation logic and state management.

#### InvoiceViewModel.swift
```swift
@Observable
final class InvoiceViewModel {
    private var modelContext: ModelContext
    var invoices: [Invoice] = []
    var isLoading = false
    var errorMessage: String?
    
    func fetchInvoices() { ... }
    func createInvoice(...) { ... }
    func updateInvoice(...) { ... }
    func deleteInvoice(...) { ... }
}
```

**Responsibilities:**
- Manage UI state (`isLoading`, `errorMessage`)
- Fetch and transform data from SwiftData
- Handle user actions (create, update, delete)
- Implement search and filter logic
- Coordinate with services (PDF, CloudKit)

**Key Features:**
- Uses `@Observable` for automatic UI updates
- Encapsulates ModelContext operations
- Provides clean API for Views
- Error handling and validation

#### CompanyProfileViewModel.swift
```swift
@Observable
final class CompanyProfileViewModel {
    private var modelContext: ModelContext
    var profile: CompanyProfile?
    
    func fetchProfile() { ... }
    func saveProfile(...) { ... }
}
```

**Purpose:** Manage company profile CRUD operations

### View Layer

**Location:** `Sources/InvoiceGenerator/Views/`

Views are the UI components built with SwiftUI, responsible only for presentation.

#### InvoiceListView.swift
```swift
struct InvoiceListView: View {
    @State private var viewModel: InvoiceViewModel?
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            // UI code only
        }
    }
}
```

**Responsibilities:**
- Display data from ViewModels
- Capture user input
- Delegate actions to ViewModels
- Navigation and presentation

**Key Features:**
- Reactive UI with SwiftUI
- Bindings to ViewModel state
- No business logic
- Reusable components

### Service Layer

**Location:** `Sources/InvoiceGenerator/Services/`

Services handle external integrations and complex operations.

#### PDFGeneratorService.swift
```swift
final class PDFGeneratorService {
    static func generateInvoicePDF(
        invoice: Invoice,
        companyProfile: CompanyProfile?
    ) -> PDFDocument? {
        // PDF generation logic using PDFKit
    }
}
```

**Responsibilities:**
- Generate PDF documents
- Handle PDF layout and styling
- Save PDFs to file system

#### CloudKitService.swift
```swift
final class CloudKitService {
    static let shared = CloudKitService()
    
    func syncInvoices(_ invoices: [Invoice]) async throws {
        // CloudKit sync logic
    }
}
```

**Responsibilities:**
- Synchronize data with iCloud
- Handle CloudKit subscriptions
- Manage account status

### Utilities Layer

**Location:** `Sources/InvoiceGenerator/Utils/`

Helper extensions and utilities for common operations.

#### Extensions.swift
```swift
extension Decimal {
    var formattedAsCurrency: String { ... }
}

extension String {
    static func generateInvoiceNumber() -> String { ... }
}
```

**Purpose:** Reusable formatting and utility functions

## Data Flow

### Creating an Invoice

```
1. User taps "Add Invoice" button
   ↓
2. AddInvoiceView shows form
   ↓
3. User fills in details and taps "Create"
   ↓
4. View calls viewModel.createInvoice(...)
   ↓
5. ViewModel creates Invoice model
   ↓
6. ViewModel inserts into ModelContext
   ↓
7. SwiftData persists to disk
   ↓
8. ViewModel calls fetchInvoices()
   ↓
9. View automatically updates (via @Observable)
```

### Generating a PDF

```
1. User opens invoice detail
   ↓
2. User taps "Generate PDF"
   ↓
3. View calls PDFGeneratorService.generateInvoicePDF()
   ↓
4. Service fetches CompanyProfile from context
   ↓
5. Service uses PDFKit to render invoice
   ↓
6. PDF is saved to document directory
   ↓
7. Share sheet is presented with PDF URL
```

### CloudKit Sync (Optional)

```
1. App launches or data changes
   ↓
2. ViewModel calls CloudKitService.syncInvoices()
   ↓
3. Service converts SwiftData models to CKRecords
   ↓
4. Records are uploaded to iCloud
   ↓
5. CloudKit notifies other devices
   ↓
6. Other devices fetch and merge changes
```

## Design Principles

### Separation of Concerns
- Models: Data structure and business rules only
- ViewModels: Presentation logic and state management
- Views: UI presentation only
- Services: External integrations

### Dependency Injection
- ViewModels receive ModelContext in initializer
- Views receive ViewModels as parameters
- Makes testing easier with mock dependencies

### Single Responsibility
- Each class has one clear purpose
- Easy to understand and maintain
- Changes are localized

### Testability
- ViewModels can be tested without UI
- Models have unit tests for calculations
- Services can be mocked for testing

## Testing Strategy

### Model Tests
```swift
func testInvoiceCalculateTotal() {
    let invoice = Invoice(...)
    invoice.items = [item1, item2]
    invoice.calculateTotal()
    XCTAssertEqual(invoice.totalAmount, expectedTotal)
}
```

### ViewModel Tests
```swift
func testCreateInvoice() {
    viewModel.createInvoice(...)
    XCTAssertEqual(viewModel.invoices.count, 1)
}
```

### Integration Tests
- Test ViewModel + Model interaction
- Use in-memory ModelContainer for isolation

## SwiftData Integration

SwiftData provides:
- Automatic persistence
- Type-safe queries with `#Predicate`
- Relationship management
- iCloud sync (when configured)
- Undo/redo support

### Query Example
```swift
let descriptor = FetchDescriptor<Invoice>(
    predicate: #Predicate { invoice in
        invoice.status == .paid
    },
    sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
)
let paidInvoices = try modelContext.fetch(descriptor)
```

## Best Practices

### Do's ✅
- Keep Views focused on presentation
- Put business logic in ViewModels or Models
- Use `@Observable` for reactive updates
- Inject dependencies through initializers
- Write unit tests for ViewModels
- Use meaningful variable and function names

### Don'ts ❌
- Don't put business logic in Views
- Don't access ModelContext directly from Views
- Don't create tight coupling between layers
- Don't skip error handling
- Don't ignore memory management

## Future Enhancements

Potential architectural improvements:

1. **Repository Pattern**: Abstract data access
2. **Use Cases/Interactors**: For complex business logic
3. **Coordinator Pattern**: For navigation management
4. **Dependency Injection Container**: For better testability
5. **Error Handling Strategy**: Standardized error types

## Resources

- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [MVVM Pattern Guide](https://www.swiftbysundell.com/articles/mvvm-in-swift/)
- [SwiftUI Best Practices](https://developer.apple.com/documentation/swiftui)
- [CloudKit Framework](https://developer.apple.com/documentation/cloudkit)
