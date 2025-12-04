# CloudKit Configuration Guide

## Overview

This document explains how to configure CloudKit for syncing invoices across devices.

## Prerequisites

- Active Apple Developer Account
- iCloud entitlement
- CloudKit Dashboard access

## CloudKit Schema

### Record Types

#### Invoice Record Type

**Record Type Name:** `Invoice`

**Fields:**

| Field Name      | Type           | Indexed | Required |
|----------------|----------------|---------|----------|
| invoiceNumber  | String         | Yes     | Yes      |
| clientName     | String         | Yes     | Yes      |
| clientEmail    | String         | No      | No       |
| clientAddress  | String         | No      | No       |
| issueDate      | Date/Time      | Yes     | Yes      |
| dueDate        | Date/Time      | Yes     | Yes      |
| status         | String         | Yes     | Yes      |
| notes          | String         | No      | No       |
| totalAmount    | Double         | Yes     | Yes      |
| createdAt      | Date/Time      | Yes     | Yes      |
| updatedAt      | Date/Time      | Yes     | Yes      |

**Indexes:**
- `invoiceNumber` (Queryable, Sortable)
- `clientName` (Queryable, Sortable)
- `issueDate` (Sortable)
- `status` (Queryable)

#### InvoiceItem Record Type

**Record Type Name:** `InvoiceItem`

**Fields:**

| Field Name       | Type           | Indexed | Required |
|-----------------|----------------|---------|----------|
| itemDescription | String         | No      | Yes      |
| quantity        | Int64          | No      | Yes      |
| unitPrice       | Double         | No      | Yes      |
| total          | Double         | No      | Yes      |
| invoiceRef     | Reference      | Yes     | Yes      |

**References:**
- `invoiceRef` → `Invoice` (Delete source record)

#### CompanyProfile Record Type

**Record Type Name:** `CompanyProfile`

**Fields:**

| Field Name   | Type           | Indexed | Required |
|-------------|----------------|---------|----------|
| companyName | String         | No      | Yes      |
| ownerName   | String         | No      | No       |
| email       | String         | No      | No       |
| phone       | String         | No      | No       |
| address     | String         | No      | No       |
| taxId       | String         | No      | No       |
| logoData    | Asset          | No      | No       |
| createdAt   | Date/Time      | No      | Yes      |
| updatedAt   | Date/Time      | No      | Yes      |

## Configuration Steps

### 1. Enable iCloud in Xcode

1. Open your project in Xcode
2. Select your app target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **iCloud**

### 2. Configure CloudKit

1. In the iCloud capability section, enable **CloudKit**
2. Click the **+** button to create a new container or select existing
3. Container name format: `iCloud.com.yourcompany.InvoiceGenerator`

### 3. Update Code

In `CloudKitService.swift`, update the container initialization:

```swift
private init() {
    // Replace with your container identifier
    container = CKContainer(identifier: "iCloud.com.yourcompany.InvoiceGenerator")
    privateDatabase = container.privateCloudDatabase
}
```

### 4. Configure CloudKit Dashboard

1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)
2. Select your container
3. Go to **Schema** → **Record Types**
4. Click **+** to add record types
5. Create the record types as specified above

### 5. Set Up Subscriptions

The app automatically sets up subscriptions for push notifications:

```swift
// Called automatically when CloudKit is configured
try await CloudKitService.shared.setupSubscription()
```

### 6. Add Background Modes (Optional)

For background sync:

1. Add **Background Modes** capability
2. Enable **Remote notifications**

## Testing

### Local Testing

1. Build and run on simulator with iCloud account signed in
2. Create an invoice
3. Check CloudKit Dashboard for new records
4. Run on second device to test sync

### Debugging

Enable CloudKit logging:

```swift
// Add to CloudKitService init
#if DEBUG
CKContainer.default().accountStatus { status, error in
    print("iCloud Status: \(status.rawValue)")
    if let error = error {
        print("iCloud Error: \(error)")
    }
}
#endif
```

## Data Privacy

### Private Database

- Data is stored in the user's private database
- Only accessible by the authenticated user
- Automatically encrypted by Apple
- Counts against user's iCloud storage

### Public Database

Not used in this app, but available for:
- Shared templates
- Public invoice templates
- Does not count against user storage

## Sync Behavior

### Automatic Sync

SwiftData with CloudKit integration provides:
- Automatic conflict resolution
- Merge policies for concurrent edits
- Background sync
- Low battery/data mode awareness

### Manual Sync

Call explicitly when needed:

```swift
Task {
    do {
        let invoices = viewModel.invoices
        try await CloudKitService.shared.syncInvoices(invoices)
    } catch {
        print("Sync failed: \(error)")
    }
}
```

## Limitations

### CloudKit Quotas

**Free Tier:**
- 1 PB of public database storage
- 10 GB per user private database storage
- Generous request limits

**Request Limits:**
- 40 requests per second
- Automatically throttled if exceeded

### Size Limits

- Maximum record size: 1 MB
- Maximum asset size: 250 MB
- Maximum query results: 400 records per request

## Troubleshooting

### "Account Not Available"

- User must be signed into iCloud
- iCloud Drive must be enabled
- Check Settings → [User] → iCloud

### "Permission Denied"

- Ensure proper entitlements
- Check CloudKit Dashboard permissions
- Verify container identifier matches

### Records Not Syncing

- Check network connection
- Verify iCloud account status
- Check CloudKit Dashboard for errors
- Ensure record types are defined correctly

### Development vs Production

- Development container: Test environment
- Production container: Live environment
- Switch in CloudKit Dashboard

## Security Considerations

### Encryption

- All data encrypted in transit (TLS)
- At rest encryption by Apple
- Private database isolated per user

### Authentication

- Automatic via iCloud account
- No additional auth required
- User controls data access

### Data Deletion

When user deletes data:
- Removed from local database
- Removed from iCloud
- Cascading deletes for relationships

## Best Practices

1. **Batch Operations**: Group related saves
2. **Error Handling**: Always handle CloudKit errors
3. **Offline Support**: Cache data locally with SwiftData
4. **Conflict Resolution**: Use latest write wins strategy
5. **Testing**: Test on multiple devices
6. **Monitoring**: Watch for sync errors in production

## Resources

- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)
- [SwiftData + CloudKit Guide](https://developer.apple.com/documentation/swiftdata/syncing-data-between-devices)
- [WWDC Sessions on CloudKit](https://developer.apple.com/videos/cloudkit)

## Support

For CloudKit issues:
- Apple Developer Forums
- Technical Support Incidents (TSI)
- File feedback at [Apple Feedback](https://feedbackassistant.apple.com)
