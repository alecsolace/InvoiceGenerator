# Repository Guidelines

## Project Structure & Module Organization
Source code lives in `InvoiceGeneration/`, organized by role: `Models` for SwiftData entities, `ViewModels` for MVVM logic, `Views` for SwiftUI screens, and `Services`/`Utils` for PDF, CloudKit, and formatting helpers. Shared assets, entitlements, and Info.plist reside alongside the modules. Unit and integration tests live in `InvoiceGenerationTests` and `InvoiceGenerationUITests`, while root-level docs (e.g., `BUILDING.md`, `CONVENTIONS.md`) capture deeper architecture notes—consult them before altering app-wide patterns.

## Build, Test, and Development Commands
- `open InvoiceGeneration.xcodeproj` – launch the Xcode workspace configured with the proper entitlements.  
- `xcodebuild -scheme InvoiceGeneration -destination 'platform=iOS Simulator,name=iPhone 15' build` – CI-friendly build that mirrors Cmd+B.  
- `xcodebuild -scheme InvoiceGeneration -destination 'platform=iOS Simulator,name=iPhone 15' test` – executes XCTest targets (`InvoiceGenerationTests`, `InvoiceGenerationUITests`).  
- `swift package generate-xcodeproj` (run inside `InvoiceGeneration/` only when you need a regenerated project file; SwiftData still requires opening the result in Xcode).

## Coding Style & Naming Conventions
Follow the Swift rules documented in `CONVENTIONS.md`: UpperCamelCase types, lowerCamelCase members, acronyms treated as words (`pdfDocument`). Keep files ordered imports→type→properties→inits→APIs, with `// MARK:` separators. Prefer MVVM boundaries (Views stay presentational; ViewModels inject `ModelContext`). Indent with four spaces, keep SwiftLint warnings at zero, and explain “why” in comments when behavior is non-obvious.

## Testing Guidelines
All functional logic should sit behind XCTest cases using in-memory SwiftData containers. Name tests descriptively (`testCreateInvoicePersistsItems`). Target coverage focuses on `Models`, `ViewModels`, and service helpers that touch CloudKit or PDF output; UI-only SwiftUI views can rely on previews plus smoke UITests. Run `xcodebuild test …` locally before pushing and use `Cmd+U` in Xcode for iterative runs.

## Commit & Pull Request Guidelines
Commits should read in present tense (“Add CloudKit sync hook”), include a short subject plus optional bulleted body describing impacts, and reference issues (`Fixes #42`) when relevant. Branch names follow `feature/<scope>` or `bugfix/<scope>`. Pull requests must summarize behavior changes, list test evidence (command + result), call out migrations/config changes, and attach screenshots or PDFs when UI or invoice layouts shift.

## Security & Configuration Tips
Never hard-code Apple IDs, CloudKit container IDs, or secrets—keep them in your local Xcode signing settings. If you change entitlements or container names, update `InvoiceGeneration.entitlements` and `CloudKitService.swift` together and document the new container in the PR. PDFs may contain user data, so audit logging calls to avoid leaking invoice contents.
