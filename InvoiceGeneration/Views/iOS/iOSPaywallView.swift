import SwiftUI

/// iPhone-specific paywall / Pro upgrade view matching the Stitch "Suscripcion Pro" design.
struct iOSPaywallView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedPlanIndex = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroSection
                    featureComparison
                    planCards
                    subscribeButton
                    footerLinks
                }
                .padding(24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .frame(width: 80, height: 80)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            Text(String(localized: "Desbloquea FacturaPro"))
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Feature Comparison

    private var featureComparison: some View {
        HStack(alignment: .top, spacing: 14) {
            // Free tier
            VStack(alignment: .leading, spacing: 10) {
                Text("Free")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                featureRow("2 clientes maximo", included: true)
                featureRow("1 emisor", included: true)
                featureRow(String(localized: "Facturas ilimitadas"), included: true)
                featureRow(String(localized: "iCloud Sync"), included: false)
                featureRow(String(localized: "Multiples emisores"), included: false)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(cornerRadius: 12)

            // Pro tier
            VStack(alignment: .leading, spacing: 10) {
                Text("Pro")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)

                featureRow(String(localized: "Clientes ilimitados"), included: true)
                featureRow(String(localized: "Multiples emisores"), included: true)
                featureRow(String(localized: "Facturas ilimitadas"), included: true)
                featureRow(String(localized: "iCloud Sync"), included: true)
                featureRow(String(localized: "Soporte prioritario"), included: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .prominentCardStyle(cornerRadius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 2)
            )
        }
    }

    private func featureRow(_ text: String, included: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: included ? "checkmark.circle.fill" : "xmark.circle")
                .font(.caption)
                .foregroundStyle(included ? .green : .secondary.opacity(0.5))
            Text(text)
                .font(.caption)
                .foregroundStyle(included ? .primary : .secondary)
        }
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        VStack(spacing: 12) {
            let plans = subscriptionService.availablePlans

            if plans.isEmpty {
                // Placeholder cards
                planCardView(
                    title: String(localized: "Anual"),
                    price: "29,99 €/ano",
                    badge: String(localized: "Ahorra 33%"),
                    isSelected: selectedPlanIndex == 0
                ) {
                    selectedPlanIndex = 0
                }

                planCardView(
                    title: String(localized: "Mensual"),
                    price: "3,99 €/mes",
                    badge: nil,
                    isSelected: selectedPlanIndex == 1
                ) {
                    selectedPlanIndex = 1
                }
            } else {
                ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                    planCardView(
                        title: plan.title,
                        price: plan.price,
                        badge: plan.highlight,
                        isSelected: selectedPlanIndex == index
                    ) {
                        selectedPlanIndex = index
                    }
                }
            }
        }
    }

    private func planCardView(title: String, price: String, badge: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.15), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    Text(price)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subscribe Button

    private var subscribeButton: some View {
        Button {
            Task {
                let plans = subscriptionService.availablePlans
                if let planID = plans.indices.contains(selectedPlanIndex) ? plans[selectedPlanIndex].id : subscriptionService.preferredPlanID() {
                    await subscriptionService.purchase(planID: planID)
                }
            }
        } label: {
            if subscriptionService.isPurchaseInFlight {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text(String(localized: "Suscribirse"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(subscriptionService.isPurchaseInFlight)
    }

    // MARK: - Footer

    private var footerLinks: some View {
        VStack(spacing: 10) {
            Button(String(localized: "Restaurar compra")) {
                Task { await subscriptionService.restorePurchases() }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .disabled(subscriptionService.isPurchaseInFlight)

            HStack(spacing: 16) {
                Button(String(localized: "Terminos")) {
                    if let url = URL(string: "https://facturapro.app/terms") {
                        openURL(url)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Button(String(localized: "Privacidad")) {
                    if let url = URL(string: "https://facturapro.app/privacy") {
                        openURL(url)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let error = subscriptionService.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    iOSPaywallView()
        .environmentObject(try! SubscriptionService(storeConfiguration: .testing, startTasks: false))
}
