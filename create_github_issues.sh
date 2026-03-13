#!/bin/bash
# Script to create GitHub issues from QA feedback
# Run this after: gh auth login
# Usage: ./create_github_issues.sh

set -e

REPO="alecsolace/InvoiceGenerator"

echo "Creating GitHub issues for $REPO..."

# Create labels if they don't exist
for label in "bug" "enhancement" "design" "cleanup" "macOS" "pdf" "ui"; do
  gh label create "$label" --repo "$REPO" --force 2>/dev/null || true
done

echo "Creating issue 1/11..."
gh issue create --repo "$REPO" \
  --title "[macOS] Welcome carousel: icons not displaying and incorrect bottom padding" \
  --label "bug,macOS,ui" \
  --body "## Description
On macOS, the welcome onboarding carousel has two visual issues:
1. The icon container shows blank grey boxes instead of the app icon (see screenshot)
2. The bottom padding of the icon container is incorrect, causing the carousel page indicators to overlap

## Steps to Reproduce
1. Launch the app on macOS for the first time (or reset onboarding)
2. Observe the welcome carousel

## Expected Behavior
- App icon appears correctly in the icon container
- Proper bottom padding separates the icon from the page indicators (dots)

## Affected File
\`Views/OnboardingView.swift\`

## Platform
macOS 14+ (not reproducible on iOS)"

echo "Creating issue 2/11..."
gh issue create --repo "$REPO" \
  --title "[macOS] Invoice creation dialog: layout and spacing issues" \
  --label "bug,macOS,ui" \
  --body "## Description
The \"Factura rápida\" (quick invoice) dialog has misaligned spacing and layout issues on macOS. The form elements are not properly spaced for the macOS platform.

## Steps to Reproduce
1. Open the app on macOS
2. Tap/click the button to create a new invoice
3. Observe the layout in the \"Factura rápida\" modal

## Expected Behavior
The dialog should have proper macOS-appropriate spacing between all form elements (mode selector, step selector, issuer info, date fields, etc.)

## Affected File
\`Views/AddInvoiceView.swift\`

## Platform
macOS only"

echo "Creating issue 3/11..."
gh issue create --repo "$REPO" \
  --title "[Bug] PDF generation truncates multiple fields" \
  --label "bug,pdf" \
  --body "## Description
The generated PDF is cutting off several fields — issuer name, address, and other text is being clipped or rendered incorrectly (strikethrough-like effect visible in the PDF preview).

## Steps to Reproduce
1. Create an invoice with a complete issuer profile (name, address, tax ID, etc.)
2. Generate the PDF
3. Observe the PDF output — multiple text fields are truncated

## Expected Behavior
All fields should render completely without truncation.

## Affected File
\`Services/PDFGeneratorService.swift\`

## Notes
The issue appears in the layout methods: \`drawCompanyHeader()\`, \`drawClientInfo()\`, or \`drawItemsTable()\`. Likely a coordinate/frame calculation issue."

echo "Creating issue 4/11..."
gh issue create --repo "$REPO" \
  --title "Address fields: support multiline input or structured fields (street, postal code, city, country)" \
  --label "enhancement" \
  --body "## Description
The current address field is a single text input. Improve it to either:

**Option A:** Allow line breaks (multiline) so users can format addresses naturally
**Option B:** Split into separate structured fields: Street, Postal Code, City, Country

Additionally, integrate Apple Intelligence to parse a single-line address string into structured fields automatically (similar to the existing image invoice import via \`InvoiceImageImportService\`).

## Affected Files
- \`Views/AddClientView.swift\`
- \`Views/OnboardingView.swift\` (issuer address)
- \`Views/InvoiceEditorComponents.swift\`
- Possibly new \`Services/AddressParsingService.swift\`

## Notes
- The AI parsing should be iOS-only (Apple Intelligence not available on macOS)
- Keep backward compatibility with existing single-line addresses stored in SwiftData"

echo "Creating issue 5/11..."
gh issue create --repo "$REPO" \
  --title "Default invoice notes/observations should be per-issuer, not per-client" \
  --label "enhancement" \
  --body "## Description
Currently, default notes/observations for invoices are associated at the client level. This should be changed so that each **issuer** has their own default notes template, which is then pre-filled when creating invoices.

## Why
An issuer (company/freelancer) typically has consistent standard terms, payment instructions, or legal text they put on all their invoices — regardless of which client the invoice is for.

## Changes Required
1. Add \`defaultNotes: String?\` property to \`Issuer\` model (\`Models/Issuer.swift\`)
2. Update \`AddInvoiceView\` to pre-fill notes from the selected issuer instead of the client (\`Views/AddInvoiceView.swift\`)
3. Update \`InvoiceEditorComponents\` accordingly
4. Update \`IssuerViewModel\` or \`SettingsView\` to allow editing the issuer's default notes

## Affected Files
- \`Models/Issuer.swift\`
- \`Views/AddInvoiceView.swift\`
- \`Views/InvoiceEditorComponents.swift\`
- \`ViewModels/InvoiceViewModel.swift\`"

echo "Creating issue 6/11..."
gh issue create --repo "$REPO" \
  --title "Invoice code and auto-numbering should be per-client, not per-issuer" \
  --label "enhancement" \
  --body "## Description
The current \`InvoiceNumberingService\` uses the format \`{IssuerCode}-{Sequence}\` where the sequence counter is global per issuer. Change this so that each **client** has their own code prefix and sequence counter.

## Why
In many billing scenarios, invoice numbers are tracked per client (e.g., CLIENT-A-0001, CLIENT-B-0001). This allows independent numbering sequences per client relationship.

## Changes Required
1. Add \`invoiceCode: String?\` and \`nextInvoiceSequence: Int\` to \`Client\` model (\`Models/Client.swift\`)
2. Update \`InvoiceNumberingService\` to use client-scoped sequences (\`Services/InvoiceNumberingService.swift\`)
3. Update invoice creation flow to use client's code/sequence (\`Views/AddInvoiceView.swift\`)
4. Update \`InvoiceViewModel\` accordingly
5. Migration: existing invoices should retain their current numbers

## Affected Files
- \`Models/Client.swift\`
- \`Models/Issuer.swift\` (may keep issuer code as fallback)
- \`Services/InvoiceNumberingService.swift\`
- \`ViewModels/InvoiceViewModel.swift\`"

echo "Creating issue 7/11..."
gh issue create --repo "$REPO" \
  --title "[Design] Home view visual redesign: summary boxes, monthly invoices section, and gradient" \
  --label "design" \
  --body "## Description
Several visual elements on the Home screen need redesign:

1. **\"Tus facturas del mes\"** section — colors and layout don't look right
2. **Summary/stats boxes** — need color and layout redesign
3. **Dark grey background** — doesn't render well on macOS
4. **Gradient** — the current gradient looks too \"vibe coder\"; remove or replace with something more professional

## Goals
- Clean, professional appearance appropriate for a business invoicing app
- Consistent with macOS/iOS platform design guidelines
- Remove the gradient from \`InvoiceDetailView\` or replace with a subtle, professional alternative

## Affected Files
- \`Views/HomeView.swift\`
- \`Views/InvoiceDetailView.swift\` (gradient)
- \`Assets.xcassets/\` (colors)"

echo "Creating issue 8/11..."
gh issue create --repo "$REPO" \
  --title "[Design] Onboarding / initial form redesign" \
  --label "design" \
  --body "## Description
The initial onboarding form (issuer setup step in the welcome carousel) needs a full redesign. The current layout, field order, and visual presentation feel unpolished.

## Goals
- More intuitive field ordering (e.g., company name → owner name → tax ID → address → contact)
- Better visual hierarchy and typography
- Proper padding and spacing consistent with platform guidelines
- Consider a step-by-step approach if there are too many fields on one screen

## Affected Files
- \`Views/OnboardingView.swift\`"

echo "Creating issue 9/11..."
gh issue create --repo "$REPO" \
  --title "[Cleanup] Remove templates feature entirely" \
  --label "cleanup" \
  --body "## Description
The invoice templates feature is not adding enough value in its current state. Remove it completely from the app.

## Scope of Removal
1. Remove templates section from Home view (\`Views/HomeView.swift\`)
2. Remove template loading UI from invoice creation flow (\`Views/AddInvoiceView.swift\`)
3. Remove \`TemplateListView\` and its navigation entry (\`Views/TemplateListView.swift\`)
4. Remove preferred template selector from \`AddClientView\` (\`Views/AddClientView.swift\`)
5. Delete \`InvoiceTemplateViewModel\` (\`ViewModels/InvoiceTemplateViewModel.swift\`)
6. Delete or archive \`InvoiceTemplate\` model (consider keeping with a migration that deletes existing template data)

## Affected Files
- \`Views/TemplateListView.swift\` (delete)
- \`Views/HomeView.swift\`
- \`Views/AddInvoiceView.swift\`
- \`Views/AddClientView.swift\`
- \`Models/InvoiceTemplate.swift\`
- \`ViewModels/InvoiceTemplateViewModel.swift\`

## Notes
Ensure SwiftData migration handles deletion of existing template records gracefully."

echo "Creating issue 10/11..."
gh issue create --repo "$REPO" \
  --title "[Cleanup] Hide analytics/dashboard section (not ready)" \
  --label "cleanup" \
  --body "## Description
The analytics/dashboard section is not polished enough for production. Hide it from the UI for now without deleting the code.

## Scope
1. Remove/comment out the navigation link to \`DashboardView\` from the Home screen (\`Views/HomeView.swift\`)
2. Remove any tab bar entry or button leading to the dashboard
3. Keep \`DashboardView.swift\` and \`DashboardViewModel.swift\` in the codebase for future use

## Affected Files
- \`Views/HomeView.swift\`
- \`InvoiceGeneratorApp.swift\` (if dashboard is accessible from tab bar)"

echo "Creating issue 11/11..."
gh issue create --repo "$REPO" \
  --title "[Cleanup] Remove \"Paso Base/Importes\" step from invoice creation flow" \
  --label "cleanup" \
  --body "## Description
The \"Paso\" (Base / Importes) step selector in the quick invoice creation dialog doesn't make sense in the current flow and adds unnecessary complexity. Remove it.

## Steps to Reproduce
1. Create a new invoice using the quick mode
2. Observe the \"Paso\" toggle with \"Base\" and \"Importes\" options

## Expected Behavior
The step selector should be removed. The invoice creation flow should go directly from the mode selection to the relevant fields.

## Affected File
\`Views/AddInvoiceView.swift\`"

echo ""
echo "✅ All 11 issues created successfully!"
gh issue list --repo "$REPO" --limit 15
