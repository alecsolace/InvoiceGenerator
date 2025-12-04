# Building and Running InvoiceGenerator

## Important Note

This is a **SwiftUI + SwiftData** application that requires Xcode to build and run. The standard `swift build` command will not work because SwiftData, SwiftUI, PDFKit, and CloudKit are Apple platform-specific frameworks that are only available when building through Xcode.

## Prerequisites

- **macOS** with Xcode 15.0 or later installed
- **iOS 17.0+** (for iOS builds) or **macOS 14.0+** (for macOS builds)
- Apple Developer Account (for device deployment and CloudKit)

## Opening the Project in Xcode

### Option 1: Open Package Directly (Recommended for Xcode 15+)

1. Open Xcode
2. Choose **File → Open**
3. Navigate to the `InvoiceGenerator` folder
4. Select the folder and click **Open**
5. Xcode will automatically recognize the Swift Package

### Option 2: Generate Xcode Project

If you prefer a traditional Xcode project:

```bash
cd InvoiceGenerator
swift package generate-xcodeproj
open InvoiceGenerator.xcodeproj
```

## Building the App

### For iOS

1. In Xcode, select an iOS target (iPhone or iPad simulator)
2. Press **Cmd + B** to build, or **Cmd + R** to build and run
3. The app will launch in the iOS Simulator

### For macOS

1. In Xcode, select **My Mac** as the destination
2. Press **Cmd + B** to build, or **Cmd + R** to build and run
3. The app will launch as a native macOS application

## Running Tests

1. In Xcode, press **Cmd + U** to run all tests
2. Or use **Product → Test** from the menu
3. Test results will appear in the Test Navigator

## Project Structure

This project uses Swift Package Manager as its structure:

```
InvoiceGenerator/
├── Package.swift           # Package definition
├── Sources/
│   └── InvoiceGenerator/  # Main app code
└── Tests/
    └── InvoiceGeneratorTests/  # Unit tests
```

## Configuring for Your Use

### 1. Bundle Identifier

When creating an actual app target in Xcode:
- Set a unique bundle identifier (e.g., `com.yourcompany.invoicegenerator`)

### 2. CloudKit Setup

To enable CloudKit synchronization:

1. Select your app target in Xcode
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **iCloud**
5. Enable **CloudKit**
6. Create or select a container
7. Update `CloudKitService.swift` with your container ID

### 3. Code Signing

For running on a physical device:
1. Select your target → **Signing & Capabilities**
2. Choose your team from the dropdown
3. Xcode will automatically manage provisioning profiles

## Creating a Full Xcode Project

While the Swift Package is great for library development, to distribute as a standalone app:

1. Create a new iOS/macOS App project in Xcode
2. Choose SwiftUI as the interface
3. Choose SwiftData as the storage
4. Add this package as a local dependency:
   - **File → Add Package Dependencies**
   - Choose **Add Local**
   - Select the InvoiceGenerator package folder

OR copy the source files directly into your new project.

## Troubleshooting

### "No such module SwiftData"

This is expected when using `swift build` from the command line. SwiftData is only available when building through Xcode for iOS/macOS targets.

### Build Errors in Xcode

1. Clean the build folder: **Product → Clean Build Folder** (Cmd + Shift + K)
2. Reset package caches: **File → Packages → Reset Package Caches**
3. Restart Xcode

### CloudKit Not Working

1. Ensure you're signed in with an Apple ID in Xcode preferences
2. Check that iCloud capability is properly configured
3. Test on a real device (CloudKit has limitations in the simulator)

## Next Steps

1. Open the project in Xcode
2. Build and run to see the app in action
3. Customize the code for your specific needs
4. Configure CloudKit for cross-device synchronization
5. Add your company logo and branding to PDF exports

## Platform Support

- **iOS 17.0+**: Full support with iPad optimizations
- **macOS 14.0+**: Native Mac app with all features
- **Cross-platform**: Code is shared between iOS and macOS

Enjoy building your invoice management solution! 🎉
