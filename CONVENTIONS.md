# Code Conventions and Best Practices

This document outlines the coding standards and conventions used in the InvoiceGenerator project.

## Swift Style Guide

### Naming Conventions

#### Types
- **Classes, Structs, Enums, Protocols**: UpperCamelCase
  ```swift
  class InvoiceViewModel { }
  struct Invoice { }
  enum InvoiceStatus { }
  protocol InvoiceServiceProtocol { }
  ```

#### Variables and Functions
- **Variables, Constants, Functions**: lowerCamelCase
  ```swift
  var invoiceNumber: String
  let totalAmount: Decimal
  func calculateTotal() { }
  ```

#### Acronyms
- Treat acronyms as words
  ```swift
  let pdfDocument: PDFDocument  // Not PDFDocument
  let urlString: String          // Not URLString
  ```

### Code Organization

#### File Structure
Each Swift file should follow this order:
1. Import statements
2. Type definition (class/struct/enum)
3. Properties
4. Initializers
5. Public methods
6. Private methods
7. Extensions

Example:
```swift
import Foundation
import SwiftData

/// Documentation comment
@Model
final class Invoice {
    // MARK: - Properties
    var id: UUID
    var invoiceNumber: String
    
    // MARK: - Initialization
    init(id: UUID = UUID(), invoiceNumber: String) {
        self.id = id
        self.invoiceNumber = invoiceNumber
    }
    
    // MARK: - Public Methods
    func calculateTotal() { }
    
    // MARK: - Private Methods
    private func validateData() { }
}
```

#### MARK Comments
Use MARK comments to organize code:
```swift
// MARK: - Properties
// MARK: - Initialization  
// MARK: - Lifecycle
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Actions
// MARK: - Helpers
```

### SwiftData Conventions

#### Model Definitions
- Use `@Model` macro for persistent types
- Use descriptive property names
- Include timestamps (createdAt, updatedAt)
- Document relationships

```swift
@Model
final class Invoice {
    var id: UUID
    var invoiceNumber: String
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \InvoiceItem.invoice)
    var items: [InvoiceItem]
    
    init(...) { }
}
```

#### Relationships
- Always specify delete rules
- Use inverse relationships when bidirectional
- Document the relationship purpose

### MVVM Architecture

#### ViewModels
- Use `@Observable` macro for reactive updates
- Prefix private properties with underscore if shadowing
- Inject ModelContext through initializer
- Keep ViewModels testable

```swift
@Observable
final class InvoiceViewModel {
    private var modelContext: ModelContext
    var invoices: [Invoice] = []
    var isLoading = false
    var errorMessage: String?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchInvoices() { }
    func createInvoice(...) { }
    
    private func saveContext() { }
}
```

#### Views
- Keep Views focused on presentation only
- No business logic in Views
- Use State and Bindable appropriately
- Extract complex UI into separate View structs

```swift
struct InvoiceListView: View {
    @State private var viewModel: InvoiceViewModel?
    @State private var searchText = ""
    
    var body: some View {
        // UI only - no business logic
    }
    
    private var emptyStateView: some View { }
}
```

### SwiftUI Best Practices

#### State Management
- `@State`: Local view state
- `@Bindable`: ViewModel observation
- `@Environment`: Dependency injection

```swift
struct MyView: View {
    @State private var text = ""
    @Bindable var viewModel: MyViewModel
    @Environment(\.modelContext) private var modelContext
}
```

#### View Modifiers
- Extract repeated modifiers into custom ViewModifiers
- Use method chaining for readability

```swift
Text("Invoice")
    .font(.headline)
    .foregroundStyle(.primary)
    .padding()
```

#### Preview
- Always include previews for views
- Use in-memory model containers for tests

```swift
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Invoice.self, configurations: config)
    return InvoiceListView()
        .modelContainer(container)
}
```

### Error Handling

#### Do-Catch Blocks
- Always handle errors from throwing functions
- Provide user-friendly error messages
- Log errors for debugging

```swift
func fetchData() {
    do {
        let data = try modelContext.fetch(descriptor)
        // Handle success
    } catch {
        errorMessage = "Failed to fetch: \(error.localizedDescription)"
        print("Error: \(error)")
    }
}
```

#### Optional Handling
- Use guard for early returns
- Use if let for non-critical optionals
- Avoid force unwrapping (!)

```swift
// Preferred
guard let invoice = selectedInvoice else { return }

// For non-critical
if let email = invoice.clientEmail, !email.isEmpty {
    // Use email
}

// Avoid
let invoice = selectedInvoice! // Don't do this
```

### Documentation

#### Types and Methods
- Document public APIs with `///`
- Explain parameters and return values
- Include usage examples for complex APIs

```swift
/// Generate a PDF document for an invoice
/// - Parameters:
///   - invoice: The invoice to generate PDF for
///   - companyProfile: Optional company profile for header
/// - Returns: PDFDocument if successful, nil otherwise
static func generateInvoicePDF(
    invoice: Invoice,
    companyProfile: CompanyProfile?
) -> PDFDocument? {
    // Implementation
}
```

### Testing

#### Unit Tests
- Test ViewModels, not Views
- Use descriptive test names
- One assertion per test (when possible)
- Use in-memory storage for isolation

```swift
func testCreateInvoice() {
    // Arrange
    let viewModel = InvoiceViewModel(modelContext: testContext)
    
    // Act
    viewModel.createInvoice(invoiceNumber: "INV-001", clientName: "Test")
    
    // Assert
    XCTAssertEqual(viewModel.invoices.count, 1)
}
```

### Performance

#### SwiftData Queries
- Use predicates for filtering
- Add indexes for commonly queried fields
- Fetch only needed properties
- Use pagination for large datasets

```swift
let descriptor = FetchDescriptor<Invoice>(
    predicate: #Predicate { $0.status == .paid },
    sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
)
```

#### Memory Management
- Avoid retain cycles with `[weak self]`
- Release large resources when done
- Use lazy properties for expensive computations

### Code Quality

#### Linting
- Follow SwiftLint rules (when configured)
- No warnings allowed in production code
- Run static analysis regularly

#### Comments
- Explain "why", not "what"
- Update comments when code changes
- Remove commented-out code before commit

```swift
// Good: Explains why
// Using 30 days as default to match standard payment terms
let dueDate = issueDate.addingTimeInterval(30 * 24 * 60 * 60)

// Bad: Explains what (obvious from code)
// Add 30 days to issue date
let dueDate = issueDate.addingTimeInterval(30 * 24 * 60 * 60)
```

### Git Conventions

#### Commit Messages
- Use present tense ("Add feature" not "Added feature")
- Be descriptive but concise
- Reference issues when applicable

```
Add PDF generation with company logo

- Implement PDFGeneratorService
- Add logo rendering in header
- Include unit tests

Fixes #123
```

#### Branch Naming
- feature/description
- bugfix/description  
- refactor/description

### Security

#### Sensitive Data
- Never commit secrets or API keys
- Use environment variables for configuration
- Don't log sensitive information

#### Input Validation
- Validate all user input
- Sanitize before storing
- Use type-safe APIs

```swift
// Validate email format
func isValidEmail(_ email: String) -> Bool {
    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
    return emailPredicate.evaluate(with: email)
}
```

## Accessibility

#### VoiceOver Support
- Provide meaningful labels
- Use semantic views when possible
- Test with VoiceOver enabled

```swift
Image(systemName: "plus")
    .accessibilityLabel("Add invoice")
```

## Localization

#### String Handling
- Use string catalogs (Xcode 15+)
- Don't concatenate localized strings
- Include context for translators

```swift
// Preferred
Text("invoice.count", count: invoices.count)

// Avoid
Text("You have \(count) invoices") // Hard to localize
```

## Summary

Key principles to follow:
1. **Clarity over brevity**: Write clear, self-documenting code
2. **Consistency**: Follow established patterns
3. **MVVM**: Separate concerns properly
4. **Testing**: Write testable code
5. **Documentation**: Document public APIs
6. **Safety**: Use type safety and handle errors
7. **Performance**: Be mindful of performance
8. **Accessibility**: Make the app accessible to all

## Resources

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftUI Best Practices](https://developer.apple.com/documentation/swiftui)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
