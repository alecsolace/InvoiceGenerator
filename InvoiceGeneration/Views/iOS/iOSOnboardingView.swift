import SwiftData
import SwiftUI

/// iPhone-specific onboarding wizard matching the Stitch "Bienvenida" design.
struct iOSOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var currentStep = 0
    @State private var companyName = ""
    @State private var taxId = ""
    @State private var issuerCode = ""

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Group {
                switch currentStep {
                case 0:
                    welcomeStep
                case 1:
                    issuerSetupStep
                case 2:
                    readyStep
                default:
                    EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            Spacer()

            stepIndicator
                .padding(.bottom, 24)

            actionButton
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

            if currentStep == 1 {
                Button(String(localized: "Omitir")) {
                    advanceStep()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
            } else {
                Spacer()
                    .frame(height: 50)
            }
        }
        .background(Color.primaryBackground.ignoresSafeArea())
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text(String(localized: "Bienvenido a FacturaPro"))
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)

            Text(String(localized: "Facturacion profesional con cumplimiento VeriFactu integrado"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Step 2: Issuer Setup

    private var issuerSetupStep: some View {
        VStack(spacing: 20) {
            Text(String(localized: "Configura tu perfil de emisor"))
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(String(localized: "Esta informacion aparecera en todas tus facturas"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 14) {
                TextField(String(localized: "Nombre de la empresa"), text: $companyName)
                    .textFieldStyle(.roundedBorder)

                TextField("NIF/CIF", text: $taxId)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    TextField(String(localized: "Codigo emisor (3 letras)"), text: $issuerCode)
                        .textFieldStyle(.roundedBorder)
                        .textCase(.uppercase)
                        .onChange(of: issuerCode) { _, newValue in
                            issuerCode = String(newValue.uppercased().prefix(5))
                        }
                }
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Step 3: Ready

    private var readyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text(String(localized: "Todo listo!"))
                .font(.system(size: 28, weight: .bold))

            Text(String(localized: "Tu perfil esta configurado. Puedes empezar a facturar."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if !companyName.isEmpty {
                VStack(spacing: 8) {
                    Text(companyName)
                        .font(.headline)

                    if !issuerCode.isEmpty {
                        Text(String(localized: "Codigo: \(issuerCode)"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .cardStyle(cornerRadius: 12)
                .padding(.horizontal, 32)
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button {
            advanceStep()
        } label: {
            Text(buttonTitle)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var buttonTitle: String {
        switch currentStep {
        case 0: return String(localized: "Comenzar")
        case 1: return String(localized: "Siguiente")
        case 2: return String(localized: "Empezar a facturar")
        default: return ""
        }
    }

    // MARK: - Navigation

    private func advanceStep() {
        if currentStep < totalSteps - 1 {
            withAnimation {
                currentStep += 1
            }
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        // Save issuer if data provided
        if !companyName.isEmpty {
            let issuerVM = IssuerViewModel(modelContext: modelContext)
            let finalCode = issuerCode.isEmpty
                ? InvoiceNumberingService.defaultCodeCandidate(from: companyName)
                : issuerCode.uppercased()

            issuerVM.createIssuer(
                name: companyName,
                code: finalCode,
                ownerName: "",
                email: "",
                phone: "",
                address: "",
                taxId: taxId
            )
        }

        hasCompletedOnboarding = true
    }
}

#Preview {
    iOSOnboardingView()
        .modelContainer(PersistenceController.preview)
}
