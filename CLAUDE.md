# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Open in Xcode
open InvoiceGeneration.xcodeproj

# CLI build (mirrors Cmd+B)
xcodebuild -scheme InvoiceGeneration -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run all tests (Cmd+U in Xcode)
xcodebuild -scheme InvoiceGeneration -destination 'platform=iOS Simulator,name=iPhone 15' test
```

There is no SPM package, Makefile, or linter CLI configured — Xcode is the primary build tool.

## Architecture Overview

**Stack:** SwiftUI + SwiftData + CloudKit + PDFKit + StoreKit, targeting iOS 17+ / macOS 14+.

**Pattern:** Strict MVVM.
- `Models/` — SwiftData `@Model` classes (`Invoice`, `InvoiceItem`, `Client`, `Issuer`, `InvoiceTemplate`, `CompanyProfile`). Models own business logic like `calculateTotal()` and `captureIssuerSnapshot()`.
- `ViewModels/` — `@Observable` classes that inject `ModelContext` via initializer and expose state/actions to views. No business logic belongs in views.
- `Views/` — SwiftUI views that are purely presentational.
- `Services/` — Stateless or singleton services for cross-cutting concerns.
- `Utils/` — Extensions, formatters, and lightweight helpers.

**Navigation:** Tab-based via `ContentView` (Home → Invoice List → Client List → Settings). Invoice creation uses `InvoiceComposerSeed` as a data-transfer struct passed into `AddInvoiceView`.

**Key services:**
| Service | Responsibility |
|---|---|
| `PersistenceController` | Shared `ModelContainer`; handles store corruption recovery |
| `PDFGeneratorService` | A4 PDF layout using PDFKit; outputs `PDFDocument` |
| `InvoiceNumberingService` | Auto-numbering scheme: `{IssuerCode}-{Sequence}` (e.g. `FAM-0042`) |
| `SubscriptionService` | StoreKit entitlements; free tier = max 2 clients |
| `CloudKitService` | Private iCloud database sync; requires Pro subscription |

**Issuer snapshot pattern:** When an invoice is created, issuer fields are copied directly onto the `Invoice` record (`issuerName`, `issuerTaxId`, etc.). This means invoice PDFs remain accurate even if the issuer profile is later edited. Don't remove these snapshot fields.

**Subscription gating:** `SubscriptionService` exposes `entitlementStatus` (`.free` / `.active` / `.expired`) and `syncStatus`. Client creation beyond 2 and iCloud sync are gated behind Pro. Always check entitlement before enabling these flows.

## Localization

The app is fully localized in English and Spanish using Xcode string catalogs (`Localizable.xcstrings`). All user-facing strings must use `String(localized:)` or `Text("key")` — never raw string literals in views. Don't concatenate localized strings; use format strings with named arguments instead.

## SwiftData Conventions

- Always specify `deleteRule` on `@Relationship`.
- Use inverse relationships when bidirectional (`inverse: \Client.invoices`).
- Use in-memory `ModelContainer` in tests: `ModelConfiguration(isStoredInMemoryOnly: true)`.
- Filter with `#Predicate` in `FetchDescriptor`; don't filter in-memory post-fetch.

## Entitlements & CloudKit

If you change CloudKit container IDs, update both `InvoiceGeneration.entitlements` and `CloudKitService.swift` together. The CloudKit container name must match exactly what's registered in App Store Connect.

## Code Style

- UpperCamelCase types, lowerCamelCase members, acronyms as words (`pdfDocument`, not `PDFDocument`).
- File order: imports → type → properties → inits → public methods → private methods → extensions.
- Use `// MARK: -` separators for each section.
- Prefer `guard` for early returns over nested `if let`.
- Zero SwiftLint warnings in production code.
