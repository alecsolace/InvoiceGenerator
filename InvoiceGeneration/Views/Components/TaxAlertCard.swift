import SwiftUI

// MARK: - Tax Alert Status

enum TaxAlertStatus: String, CaseIterable {
    case pending
    case upcoming
    case overdue
    case completed

    var localizedTitle: String {
        switch self {
        case .pending: return String(localized: "Pendiente")
        case .upcoming: return String(localized: "Proximo")
        case .overdue: return String(localized: "Vencido")
        case .completed: return String(localized: "Presentado")
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .upcoming: return .blue
        case .overdue: return .red
        case .completed: return .green
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "clock.fill"
        case .upcoming: return "calendar.badge.clock"
        case .overdue: return "exclamationmark.triangle.fill"
        case .completed: return "checkmark.seal.fill"
        }
    }
}

// MARK: - Tax Alert Data

struct TaxAlertData: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let status: TaxAlertStatus
}

// MARK: - Tax Alert Card

/// Card component showing upcoming tax filing deadlines (IVA quarterly, IRPF retentions).
struct TaxAlertCard: View {
    let alert: TaxAlertData

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: alert.status.iconName)
                .font(.title3)
                .foregroundStyle(alert.status.color)
                .frame(width: 36, height: 36)
                .background(alert.status.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(alert.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(alert.status.localizedTitle)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(alert.status.color.opacity(0.12), in: Capsule())
                .foregroundStyle(alert.status.color)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.cardBackground)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }
}

// MARK: - Tax Alert Helper

enum TaxAlertHelper {
    /// Computes upcoming quarterly tax deadlines based on current date.
    static func currentAlerts(for date: Date = Date()) -> [TaxAlertData] {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)

        // Spanish quarterly tax deadlines: IVA/IRPF due on the 20th of the month after quarter ends
        // Q1: Jan-Mar → due April 20
        // Q2: Apr-Jun → due July 20
        // Q3: Jul-Sep → due October 20
        // Q4: Oct-Dec → due January 30 next year (special case)

        let quarterInfo: (name: String, ivaDeadline: Date, irpfDeadline: Date)

        switch month {
        case 1...3:
            let ivaDate = calendar.date(from: DateComponents(year: year, month: 4, day: 20))!
            let irpfDate = calendar.date(from: DateComponents(year: year, month: 4, day: 20))!
            quarterInfo = ("T1", ivaDate, irpfDate)
        case 4...6:
            let ivaDate = calendar.date(from: DateComponents(year: year, month: 7, day: 20))!
            let irpfDate = calendar.date(from: DateComponents(year: year, month: 7, day: 20))!
            quarterInfo = ("T2", ivaDate, irpfDate)
        case 7...9:
            let ivaDate = calendar.date(from: DateComponents(year: year, month: 10, day: 20))!
            let irpfDate = calendar.date(from: DateComponents(year: year, month: 10, day: 20))!
            quarterInfo = ("T3", ivaDate, irpfDate)
        default:
            let ivaDate = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 30))!
            let irpfDate = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 30))!
            quarterInfo = ("T4", ivaDate, irpfDate)
        }

        let daysUntilIva = calendar.dateComponents([.day], from: date, to: quarterInfo.ivaDeadline).day ?? 0
        let ivaStatus: TaxAlertStatus = daysUntilIva < 0 ? .overdue : (daysUntilIva <= 7 ? .pending : .upcoming)
        let irpfStatus: TaxAlertStatus = daysUntilIva < 0 ? .overdue : (daysUntilIva <= 7 ? .pending : .upcoming)

        let daysText: String
        if daysUntilIva < 0 {
            daysText = String(localized: "Vencido hace \(abs(daysUntilIva)) dias")
        } else if daysUntilIva == 0 {
            daysText = String(localized: "Vence hoy")
        } else {
            daysText = String(localized: "Vence en \(daysUntilIva) dias")
        }

        return [
            TaxAlertData(
                title: String(localized: "Liquidacion IVA \(quarterInfo.name)"),
                subtitle: daysText,
                status: ivaStatus
            ),
            TaxAlertData(
                title: String(localized: "Retenciones IRPF \(quarterInfo.name)"),
                subtitle: daysText,
                status: irpfStatus
            ),
        ]
    }
}

#Preview {
    VStack(spacing: 12) {
        TaxAlertCard(alert: TaxAlertData(title: "Liquidacion IVA T3", subtitle: "Vence en 3 dias", status: .pending))
        TaxAlertCard(alert: TaxAlertData(title: "Retenciones IRPF T3", subtitle: "Vence en 3 dias", status: .pending))
        TaxAlertCard(alert: TaxAlertData(title: "Liquidacion IVA T2", subtitle: "Presentado", status: .completed))
    }
    .padding()
}
