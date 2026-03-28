import SwiftUI

/// Metric card displaying a title, value, and optional accent color indicator.
struct SummaryCard: View {
    let title: String
    let value: String
    var subtitle: String?
    var icon: String?
    var tint: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }
}

/// Horizontal scrolling row of summary cards.
struct SummaryCardRow: View {
    let cards: [SummaryCardData]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(cards) { card in
                    SummaryCard(
                        title: card.title,
                        value: card.value,
                        subtitle: card.subtitle,
                        tint: card.tint
                    )
                    .frame(minWidth: 150)
                }
            }
        }
    }
}

struct SummaryCardData: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    var subtitle: String?
    var tint: Color = .blue
}

#Preview {
    SummaryCardRow(cards: [
        SummaryCardData(title: "Vencido", value: "120,80 €", tint: .red),
        SummaryCardData(title: "Próx. 30 días", value: "0,00 €", tint: .orange),
        SummaryCardData(title: "Cobrado", value: "3.450,00 €", tint: .green),
    ])
    .padding()
}
