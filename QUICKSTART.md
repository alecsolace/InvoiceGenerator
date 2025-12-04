# Quick Start Guide

Get up and running with InvoiceGenerator in 5 minutes!

## Step 1: Open in Xcode

```bash
# Clone the repository
git clone https://github.com/alecsolace/InvoiceGenerator.git
cd InvoiceGenerator

# Open in Xcode (15.0+)
open .
```

Or manually:
1. Open Xcode
2. File → Open
3. Select the `InvoiceGenerator` folder

## Step 2: Select Your Target

- For **iOS**: Choose an iPhone/iPad simulator
- For **Mac**: Choose "My Mac" destination

## Step 3: Build & Run

Press **⌘ + R** or click the Run button.

The app will launch showing the invoice list (empty initially).

## Step 4: Create Your First Invoice

1. **Set Up Company Profile** (Optional but recommended)
   - Tap the "Profile" tab
   - Enter your company information
   - Tap "Save Profile"

2. **Create an Invoice**
   - Go back to "Invoices" tab
   - Tap the **+** button
   - Fill in:
     - Invoice Number (auto-generated)
     - Client Name (required)
     - Client Email & Address (optional)
     - Dates (issue and due date)
   - Tap "Create"

3. **Add Line Items**
   - Tap on your new invoice
   - Tap "Add Item"
   - Enter:
     - Description (e.g., "Web Development")
     - Quantity (e.g., 40 hours)
     - Unit Price (e.g., $150)
   - Tap "Add"
   - Repeat for more items

4. **Generate PDF**
   - In the invoice detail view
   - Tap the menu button (•••)
   - Select "Generate PDF"
   - Share or save the PDF

## Features at a Glance

### Invoice Management
- ✅ Create invoices with client information
- ✅ Add multiple line items
- ✅ Automatic total calculation
- ✅ Track invoice status (Draft, Sent, Paid, etc.)
- ✅ Search invoices by client or number
- ✅ Filter by status

### PDF Export
- ✅ Professional invoice layout
- ✅ Company logo support (in profile)
- ✅ Complete client and item details
- ✅ Share via email, messages, etc.

### Data Persistence
- ✅ Automatic saving with SwiftData
- ✅ All data stored locally
- ✅ Ready for iCloud sync (see CloudKit guide)

## Project Structure

```
InvoiceGenerator/
├── Sources/InvoiceGenerator/
│   ├── Models/              # Data models (Invoice, CompanyProfile)
│   ├── ViewModels/          # Business logic (MVVM)
│   ├── Views/               # UI (SwiftUI)
│   ├── Services/            # PDF & CloudKit services
│   └── Utils/               # Helpers
└── Tests/                   # Unit tests
```

## Next Steps

### Customize for Your Business

1. **Update Invoice Numbering**
   - Edit `Extensions.swift`
   - Modify `generateInvoiceNumber()` function
   - Use your preferred format

2. **Change Currency**
   - Edit `Extensions.swift`
   - Update `formattedAsCurrency` function
   - Change `currencyCode` from "USD" to your currency

3. **Customize PDF Layout**
   - Edit `PDFGeneratorService.swift`
   - Adjust fonts, colors, spacing
   - Add your branding

### Enable CloudKit Sync

Follow the [CloudKit Configuration Guide](CLOUDKIT.md):
1. Enable iCloud capability in Xcode
2. Configure CloudKit container
3. Update `CloudKitService.swift` with your container ID
4. Test on multiple devices

### Deploy to Device

1. Connect your iPhone/iPad
2. Select your device in Xcode
3. Update Bundle Identifier
4. Select your Development Team
5. Build and Run (⌘ + R)

## Common Tasks

### Search Invoices
- Use the search bar at the top
- Searches by client name or invoice number
- Real-time results

### Filter by Status
- Tap the filter button (☰)
- Select a status or "All Invoices"

### Edit an Invoice
- Open invoice detail
- Tap menu (•••) → Edit
- Update client info or notes
- Tap Save

### Delete an Invoice
- Swipe left on invoice in list
- Tap "Delete"
- Or use Edit mode in detail view

### Change Invoice Status
- Open invoice detail
- Tap the status dropdown
- Select new status

## Keyboard Shortcuts (Mac)

- **⌘ + N**: New invoice (when implemented)
- **⌘ + F**: Search
- **⌘ + W**: Close window
- **⌘ + Q**: Quit app

## Tips & Tricks

### Invoice Numbers
- Auto-generated as `INV-YYYYMM-XXXX`
- YYYYMM = Current year and month
- XXXX = Random 4-digit number
- Customize in code if needed

### Date Selection
- Issue date defaults to today
- Due date defaults to 30 days from issue
- Easily adjustable with date pickers

### Currency Formatting
- Automatically formats based on locale
- Uses 2 decimal places
- Currency symbol included

### PDF File Names
- Saved as `Invoice_[NUMBER].pdf`
- Stored in app's document directory
- Access via Files app on iOS

## Troubleshooting

### App Won't Build
- Clean build folder: ⌘ + Shift + K
- Reset package caches: File → Packages → Reset
- Restart Xcode

### No Data Showing
- Check if you've created any invoices
- Try force quit and relaunch
- Check console for errors

### PDF Not Generating
- Ensure invoice has items
- Check console for errors
- Verify PDFKit is available

### CloudKit Issues
- Must be signed into iCloud
- Enable iCloud Drive in Settings
- See [CloudKit Guide](CLOUDKIT.md)

## Learning Resources

- **Architecture**: Read [ARCHITECTURE.md](ARCHITECTURE.md)
- **Building**: See [BUILDING.md](BUILDING.md)
- **CloudKit**: Check [CLOUDKIT.md](CLOUDKIT.md)
- **README**: Full documentation in [README.md](README.md)

## Code Examples

### Add Custom Field to Invoice

1. Update `Invoice.swift`:
```swift
var customField: String = ""
```

2. Update form in `AddInvoiceView.swift`:
```swift
TextField("Custom Field", text: $customField)
```

3. Save value in create function

### Customize PDF Colors

Edit `PDFGeneratorService.swift`:
```swift
// Change header color
context.cgContext.setFillColor(UIColor.blue.cgColor)

// Change text color
let attributes: [NSAttributedString.Key: Any] = [
    .foregroundColor: UIColor.darkBlue
]
```

## Getting Help

- **GitHub Issues**: Report bugs or request features
- **Documentation**: Check the docs in this repository
- **Apple Forums**: For SwiftData/SwiftUI questions
- **Stack Overflow**: Tag with `swiftui` and `swiftdata`

## Contributing

Want to improve InvoiceGenerator?

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

---

Happy invoicing! 🎉

For more detailed information, check out the [full README](README.md).
