import SwiftUI

/// Colored capsule pill for displaying invoice status.
struct StatusBadge: View {
    let status: InvoiceStatus

    var body: some View {
        Text(status.localizedTitle)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(status.color.opacity(0.12), in: Capsule())
            .foregroundStyle(status.color)
    }
}

// MARK: - Status Color Extension

extension InvoiceStatus {
    var color: Color {
        switch self {
        case .draft: return .gray
        case .sent: return .blue
        case .paid: return .green
        case .overdue: return .red
        case .cancelled: return .orange
        }
    }

    var iconName: String {
        switch self {
        case .draft: return "pencil.circle"
        case .sent: return "paperplane.fill"
        case .paid: return "checkmark.circle.fill"
        case .overdue: return "exclamationmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

#Preview {
    HStack {
        StatusBadge(status: .draft)
        StatusBadge(status: .sent)
        StatusBadge(status: .paid)
        StatusBadge(status: .overdue)
        StatusBadge(status: .cancelled)
    }
    .padding()
}
