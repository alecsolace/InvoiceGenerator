# InvoiceGenerator

A cross-platform SwiftUI application for generating and managing invoices with SwiftData persistence, PDFKit export, and CloudKit synchronization.

## Features

- 📱 **SwiftUI Interface** - Modern, native iOS/macOS interface
- 💾 **SwiftData** - Persistent local storage with automatic sync
- 📄 **PDF Generation** - Export invoices as PDF documents using PDFKit
- ☁️ **CloudKit Integration** - Sync data across devices (ready for configuration)
- 🏗️ **MVVM Architecture** - Clean, testable, and maintainable code structure
- 🔍 **Search & Filter** - Find invoices quickly by client name or invoice number
- 📊 **Invoice Management** - Create, edit, and track invoice status
- 💰 **Automatic Calculations** - Line items and totals calculated automatically

## Architecture

This project follows the **MVVM (Model-View-ViewModel)** pattern:

### Models (`Sources/InvoiceGenerator/Models/`)
- **Invoice.swift** - Main invoice entity with SwiftData support
- **CompanyProfile.swift** - Company/user profile information

### ViewModels (`Sources/InvoiceGenerator/ViewModels/`)
- **InvoiceViewModel.swift** - Manages invoice operations (CRUD, search, filter)
- **CompanyProfileViewModel.swift** - Manages company profile

### Views (`Sources/InvoiceGenerator/Views/`)
- **InvoiceGeneratorApp.swift** - Main app entry point with SwiftData container
- **InvoiceListView.swift** - List of all invoices with search and filter
- **InvoiceDetailView.swift** - Detailed invoice view with PDF export
- **AddInvoiceView.swift** - Create new invoices
- **AddItemView.swift** - Add line items to invoices
- **CompanyProfileView.swift** - Manage company information

### Services (`Sources/InvoiceGenerator/Services/`)
- **PDFGeneratorService.swift** - Generate PDF documents from invoices
- **CloudKitService.swift** - CloudKit synchronization (ready for configuration)

### Utils (`Sources/InvoiceGenerator/Utils/`)
- **Extensions.swift** - Utility extensions for formatting

## Requirements

- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/alecsolace/InvoiceGenerator.git
cd InvoiceGenerator
```

### 2. Build the Package

```bash
swift build
```

### 3. Run Tests

```bash
swift test
```

### 4. Open in Xcode

To create an Xcode project:

```bash
swift package generate-xcodeproj
open InvoiceGenerator.xcodeproj
```

Or open the package directly in Xcode 15+:
- File → Open → Select the `InvoiceGenerator` folder

## CloudKit Configuration

To enable CloudKit synchronization:

1. Open your project in Xcode
2. Select your target → Signing & Capabilities
3. Add **iCloud** capability
4. Enable **CloudKit**
5. Create or select a CloudKit container
6. Update `CloudKitService.swift` with your container identifier

## Usage

### Creating an Invoice

1. Tap the "+" button in the Invoices tab
2. Enter client information
3. Add line items with descriptions, quantities, and prices
4. Save the invoice

### Generating a PDF

1. Open an invoice from the list
2. Tap the menu button (•••)
3. Select "Generate PDF"
4. Share or save the PDF document

### Managing Company Profile

1. Go to the Profile tab
2. Enter your company information
3. This information will appear on all generated PDF invoices

## Project Structure

```
InvoiceGenerator/
├── Package.swift                    # Swift Package manifest
├── Sources/
│   └── InvoiceGenerator/
│       ├── Models/                  # Data models
│       │   ├── Invoice.swift
│       │   └── CompanyProfile.swift
│       ├── ViewModels/              # Business logic
│       │   ├── InvoiceViewModel.swift
│       │   └── CompanyProfileViewModel.swift
│       ├── Views/                   # UI components
│       │   ├── InvoiceGeneratorApp.swift
│       │   ├── InvoiceListView.swift
│       │   ├── InvoiceDetailView.swift
│       │   ├── AddInvoiceView.swift
│       │   ├── AddItemView.swift
│       │   └── CompanyProfileView.swift
│       ├── Services/                # External services
│       │   ├── PDFGeneratorService.swift
│       │   └── CloudKitService.swift
│       └── Utils/                   # Utilities
│           └── Extensions.swift
└── Tests/
    └── InvoiceGeneratorTests/       # Unit tests
        ├── InvoiceTests.swift
        └── InvoiceViewModelTests.swift
```

## Key Technologies

- **SwiftUI** - Declarative UI framework
- **SwiftData** - Modern persistence framework (introduced in iOS 17)
- **PDFKit** - PDF generation and manipulation
- **CloudKit** - Apple's cloud storage solution
- **Observation** - New observation framework for reactive updates
- **Swift Package Manager** - Dependency management and project structure

## Testing

The project includes comprehensive unit tests for models and view models:

```bash
swift test
```

Tests cover:
- Invoice creation and calculation
- Invoice item management
- ViewModel CRUD operations
- Status updates and filtering

## Future Enhancements

- [ ] Multi-currency support
- [ ] Recurring invoices
- [ ] Payment tracking
- [ ] Email integration
- [ ] Custom PDF templates
- [ ] Tax calculations
- [ ] Client management
- [ ] Analytics and reports

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

Created for cross-platform invoice generation with modern Swift technologies.
