import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

enum PaywallReason {
    case clientLimit
    case sync
    case settings

    var message: String {
        switch self {
        case .clientLimit:
            return String(localized: "Free includes up to 2 clients. Upgrade to keep adding without limits.", comment: "Paywall reason for client cap")
        case .sync:
            return String(localized: "iCloud sync is part of Pro so your invoices stay updated everywhere.", comment: "Paywall reason for sync")
        case .settings:
            return String(localized: "Unlock Pro to enable iCloud sync and lift the client cap.", comment: "Paywall reason from settings")
        }
    }
}

/// Bottom sheet showcasing Pro benefits and handling purchase actions.
struct PaywallView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    let reason: PaywallReason?

    @State private var selectedPlanID: String?

    private var perks: [String] {
        [
            String(localized: "iCloud sync across iPhone, iPad, and Mac", comment: "Paywall perk for sync"),
            String(localized: "Unlimited clients (Free allows 2)", comment: "Paywall perk for client cap"),
            String(localized: "Priority support and faster backups", comment: "Paywall perk for support"),
            String(localized: "Offline friendly — sync catches up automatically", comment: "Paywall perk for offline sync")
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    perkList
                    planSelector
                    primaryCTA
                    restoreControls
                    footerNote
                }
                .padding()
            }
            .background(
                backgroundGradient
            )
            .navigationTitle(String(localized: "Unlock InvoiceGeneration Pro", comment: "Paywall navigation title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .imageScale(.medium)
                            .bold()
                    }
                }
            }
        }
#if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(subscriptionService.isPurchasing)
#endif
        .onAppear {
            if selectedPlanID == nil {
                selectedPlanID = subscriptionService.preferredPlanID()
            }
        }
        .onChange(of: subscriptionService.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 60, height: 60)

                    Image(systemName: "cloud.lock.fill")
                        .foregroundStyle(.tint)
                        .imageScale(.large)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Sync securely. Grow without limits.", comment: "Paywall headline"))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .fixedSize(horizontal: false, vertical: true)

                    if let reason {
                        Text(reason.message)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(String(localized: "Pro keeps your business in sync and removes client limits.", comment: "Paywall generic subheadline"))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var perkList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(perks, id: \.self) { perk in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.tint)
                    Text(perk)
                        .font(.callout)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var planSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Choose your plan", comment: "Paywall plan selector title"))
                .font(.headline)

            if subscriptionService.isLoadingProducts {
                ProgressView(String(localized: "Loading prices…", comment: "Loading products label"))
            }

            ForEach(subscriptionService.plans) { plan in
                planButton(for: plan)
            }
        }
    }

    private func planButton(for plan: SubscriptionService.Plan) -> some View {
        let isSelected = selectedPlanID == plan.id

        return Button {
            selectedPlanID = plan.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.title)
                            .font(.headline)
                        if let highlight = plan.highlight {
                            Text(highlight)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    Text(plan.subtitle)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price)
                        .font(.headline)
                    if plan.hasIntroOffer {
                        Text(String(localized: "Free trial available", comment: "Intro offer badge"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .imageScale(.large)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : cardBackgroundColor)
            )
        }
        .buttonStyle(.plain)
    }

    private var primaryCTA: some View {
        Button {
            startPurchase()
        } label: {
            HStack {
                Spacer()
                if subscriptionService.isPurchasing {
                    ProgressView()
                } else {
                    Text(String(localized: "Start Pro", comment: "Primary paywall button"))
                        .fontWeight(.semibold)
                }
                Spacer()
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(selectedPlanID == nil || subscriptionService.isPurchasing)
    }

    private var restoreControls: some View {
        HStack {
            Button(String(localized: "Restore purchases", comment: "Restore purchases button")) {
                Task { await subscriptionService.restorePurchases() }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(String(localized: "Continue free", comment: "Continue without subscribing button")) {
                dismiss()
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var footerNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Cancel anytime from Settings. Prices are localized in your region.", comment: "Paywall disclaimer"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let error = subscriptionService.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func startPurchase() {
        guard let planID = selectedPlanID else { return }
        Task {
            await subscriptionService.purchase(planID: planID)
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.15),
                platformBackgroundColor
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var platformBackgroundColor: Color {
        #if canImport(UIKit)
        return Color(.systemBackground)
        #elseif canImport(AppKit)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color.white
        #endif
    }

    private var cardBackgroundColor: Color {
        #if canImport(UIKit)
        return Color(.secondarySystemBackground)
        #elseif canImport(AppKit)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color.white
        #endif
    }
}

#Preview {
    PaywallView(reason: .clientLimit)
        .environmentObject(SubscriptionService())
}
