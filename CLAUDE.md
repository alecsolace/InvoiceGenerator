# CLAUDE.md — AI Assistant Guide for InvoiceGenerator

This file provides essential context for AI assistants (Claude, etc.) working on
the InvoiceGenerator iOS/macOS application. Read this before making any changes.

---

## Project Overview

**InvoiceGenerator** is a native iOS/macOS invoice management app built with
Swift and SwiftUI. It targets **iOS 17.0+ and macOS 14.0+** using modern Apple
frameworks: SwiftData, StoreKit 2, PDFKit, CloudKit, and Vision.

Key capabilities:
- Create, manage, and track invoices with line items and tax calculations (IVA/IRPF)
- Manage clients and multiple business entities (Issuers)
- Generate professional A4 PDF invoices
- Recurring invoice templates
- Optional iCloud sync (CloudKit) — subscription-gated
- Import invoices from photos via OCR (Vision + Foundation Models)
- In-app purchases (StoreKit 2): free tier + Pro monthly/yearly

---

## Build System

**Xcode 15.0+ is required.** The project **cannot** be built from the command
line with `swift build` because it uses SwiftUI and SwiftData, which require
the Xcode build system.

```
# Run tests (must be done from Xcode UI or xcodebuild)
xcodebuild test -project InvoiceGeneration.xcodeproj \
  -scheme InvoiceGeneration \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro"
```

There are **no shell scripts, Makefiles, npm, or package managers** — this is a
pure Xcode project.

---

## Directory Structure

```
InvoiceGenerator/
├── InvoiceGeneration/              # Main app source
│   ├── Models/                     # SwiftData entity models
│   ├── ViewModels/                 # MVVM business logic
│   ├── Views/                      # SwiftUI views
│   ├── Services/                   # PDF, CloudKit, StoreKit, etc.
│   ├── Utils/                      # Extensions and helpers
│   ├── Assets.xcassets/            # Images and icons
│   ├── Info.plist                  # StoreKit product IDs & app config
│   └── InvoiceGeneration.entitlements
├── InvoiceGenerationTests/         # Unit tests (Swift Testing framework)
├── InvoiceGenerationUITests/       # UI tests
├── InvoiceImageShareExtension/     # Share extension for importing invoices
├── InvoiceGeneration.xcodeproj/    # Xcode project
├── ARCHITECTURE.md
├── BUILDING.md
├── CLOUDKIT.md
├── CONVENTIONS.md
└── README.md
```

---

## Architecture: MVVM

The project strictly follows **Model-View-ViewModel (MVVM)**:

```
View (SwiftUI)  →  ViewModel (@Observable)  →  Model (SwiftData @Model)
    ↕                       ↕                           ↕
Presentation          Business Logic              Data & Persistence
```

### Layer Rules
- **Views** (`Views/`): Pure SwiftUI. No business logic. Use `@State`,
  `@Bindable`, `@Environment`. Never import SwiftData directly.
- **ViewModels** (`ViewModels/`): All business logic, validation, and data
  coordination. Receive `ModelContext` via initializer injection.
  Use `@Observable` macro (not `ObservableObject`).
- **Models** (`Models/`): SwiftData `@Model` classes only. Pure data
  definitions. No business logic except simple computed properties.
- **Services** (`Services/`): Standalone services injected into ViewModels.
  No View dependencies.

### Key ViewModels

| ViewModel | Responsibility |
|-----------|---------------|
| `InvoiceViewModel` | Invoice CRUD, filtering, PDF coordination, templates |
| `ClientViewModel` | Client management, subscription limit checks |
| `IssuerViewModel` | Business entity management, invoice numbering |
| `InvoiceTemplateViewModel` | Recurring invoice template management |
| `DashboardViewModel` | Analytics and summary statistics |
| `HomeViewModel` | Home screen data and quick actions |

---

## Data Models (SwiftData)

All models use the `@Model` macro and live in `Models/`:

### Invoice
- Properties: `id`, `invoiceNumber`, `clientName`, `clientEmail`, `issuerName`,
  `items: [InvoiceItem]`, `status`, `issueDate`, `dueDate`, `ivaPercentage`,
  `irpfPercentage`, `notes`
- Statuses: `draft`, `sent`, `paid`, `overdue`, `cancelled`
- Stores an **issuer snapshot** at creation time so invoice data is immutable
  even if the issuer changes later

### InvoiceItem
- Properties: `itemDescription`, `quantity`, `unitPrice`
- Cascade-deleted with parent Invoice

### Client
- Properties: `name`, `email`, `address`, `identificationNumber`, `accentColorHex`
- Stores default tax rates and due date offsets for quick invoice creation

### Issuer
- Properties: `name`, `code` (invoice prefix), `ownerName`, `email`, `phone`,
  `address`, `taxId`, `logoData`, `nextInvoiceSequence`
- Supports multiple business entities per user

### InvoiceTemplate
- Properties: `name`, `dueDays`, `ivaPercentage`, `irpfPercentage`, `notes`
- Links to Client and Issuer for auto-fill

---

## Services

| Service | Purpose |
|---------|---------|
| `PDFGeneratorService` | Generates A4 PDF invoices using PDFKit |
| `PersistenceController` | Singleton SwiftData ModelContainer setup |
| `SubscriptionService` | StoreKit 2 in-app purchases and entitlements |
| `InvoiceNumberingService` | Per-issuer sequential invoice numbering (e.g. FAM-0001) |
| `CloudKitService` | Optional iCloud sync (requires manual CloudKit config) |
| `InvoiceImageImportService` | OCR invoice import using Vision + Foundation Models |
| `IssuerMigrationService` | Migrates legacy CompanyProfile data to Issuer model |
| `EmailService` | Email sharing for invoices |

### PersistenceController
- Singleton: `PersistenceController.shared`
- Provides disk-backed container (SQLite at `~/Library/Application Support/InvoiceGeneration/`)
- `.inMemory` variant for tests: `PersistenceController.inMemory`
- Implements automatic store recovery if the SQLite database is corrupted

---

## Testing

Tests use the **Swift Testing** framework (not XCTest) and live in
`InvoiceGenerationTests/InvoiceGenerationTests.swift`.

### Patterns
- Always use `PersistenceController.inMemory` for test containers — never disk
- ViewModels are tested directly without UI
- Use `@MainActor` when testing code that accesses `@Observable` state
- Seed test data using `InvoiceComposerSeed` helpers

### Test Coverage Areas
- Subscription entitlements and StoreKit configuration
- Invoice numbering (sequential, per-issuer)
- Issuer migration from legacy profile
- Template creation and invoice generation from templates
- Monthly invoice duplication
- Invoice status transitions
- PDF generation (including multi-line addresses)
- Image import parsing (Spanish invoice format)
- Client creation with default settings

### Running Tests
Tests must be run from Xcode (⌘U) or via `xcodebuild test`. There is no
`make test` or `npm test`.

---

## Conventions

### Swift Style
- Follow Swift API Design Guidelines
- Use `camelCase` for variables and functions, `PascalCase` for types
- Prefer `let` over `var` whenever possible
- Use `guard` for early returns over nested `if`
- Avoid force-unwrapping (`!`); use `guard let` or `if let`

### SwiftUI Views
- Keep views small and composable — extract subviews when a view exceeds ~100 lines
- Use `@ViewBuilder` for conditional view logic
- Support both iOS and macOS in the same view where possible
- Always add `.accessibilityLabel()` for interactive elements

### ViewModels
- Declare as `@Observable` class (never `struct`)
- All `ModelContext` operations on `@MainActor`
- Expose errors via `var errorMessage: String?` property
- Expose loading state via `var isLoading: Bool`

### Models
- All SwiftData models use `@Model` macro
- Relationships declared with `@Relationship` and appropriate delete rules
- Cascade delete children when the parent is removed

### Naming
- Invoice PDFs: `Invoice-{invoiceNumber}.pdf`
- Invoice numbers: `{ISSUER_CODE}-{4-digit-sequence}` (e.g., `FAM-0042`)
- Hex colors stored as strings: `"#1F5FB8"`

---

## Subscription / Freemium Model

- **Free tier**: Limited to 2 clients; basic invoice creation
- **Pro tier** (monthly/yearly): Unlimited clients, CloudKit sync
- Product IDs defined in `Info.plist`:
  - Monthly: `pro_monthly`
  - Yearly: `pro_yearly`
- `SubscriptionService.shared` is the single source of truth for entitlement status
- Before adding clients, check `ClientViewModel.canAddClient()`

---

## Localization

The app targets **Spanish-speaking markets** (Spain). Key notes:
- Tax terms: **IVA** (VAT) and **IRPF** (income tax withholding)
- Invoice numbers use Spanish format: `FAM-0001`, `ACM-0050`
- Status strings are Spanish: `Borrador`, `Enviada`, `Pagada`, `Vencida`, `Cancelada`
- OCR import is tuned for Spanish invoice documents

---

## Sensitive Configuration (Not in Repo)

The following require manual setup and are **not committed to the repo**:
- Apple Developer Team ID and bundle identifier (`com.yourcompany.InvoiceGeneration`)
- CloudKit container identifier (`iCloud.com.yourcompany.InvoiceGeneration`)
- StoreKit product configuration (`.storekit` file for local testing)
- Push notification certificates (for CloudKit subscriptions)

See `BUILDING.md` and `CLOUDKIT.md` for setup instructions.

---

## Common Tasks for AI Assistants

### Adding a New Field to a Model
1. Add the property to the `@Model` class in `Models/`
2. Update the corresponding ViewModel to expose/modify the field
3. Update relevant Views to display/edit the field
4. Add migration logic if needed (see `IssuerMigrationService` as an example)
5. Add tests for the new behavior

### Adding a New View
1. Create the SwiftUI view in `Views/`
2. Create or update the corresponding ViewModel in `ViewModels/`
3. Keep all business logic in the ViewModel, not the View
4. Add navigation from an existing view (tab or sheet/navigation push)

### Modifying PDF Layout
- Edit `PDFGeneratorService.swift` in `Services/`
- A4 dimensions: 595 × 842 points
- Test with multi-line addresses and long item descriptions

### Adding a New Service
1. Create the service file in `Services/`
2. Inject into the relevant ViewModel(s) via initializer
3. Do not reference Views from Services

### Fixing Data Migration Issues
- Use `IssuerMigrationService` as a pattern
- Run migration at app startup in `InvoiceGeneratorApp.swift`
- Always test migration with both fresh installs and existing data

---

## What NOT to Do

- **Never add business logic to Views** — put it in ViewModels
- **Never use disk storage in tests** — always use `PersistenceController.inMemory`
- **Never force-unwrap optionals** without a clear justification
- **Never modify `Info.plist` product IDs** without updating the StoreKit config
- **Never call CloudKit APIs directly** — go through `CloudKitService`
- **Never break iOS 17 / macOS 14 compatibility** — do not use newer APIs without availability checks
- **Never add third-party dependencies** — this project has zero external dependencies by design

---

## Further Reading

- `ARCHITECTURE.md` — detailed MVVM diagrams and data flow
- `BUILDING.md` — Xcode setup, signing, simulator instructions
- `CLOUDKIT.md` — CloudKit schema and container configuration
- `CONVENTIONS.md` — extended code style guide
- `QUICKSTART.md` — 5-minute onboarding for new developers
