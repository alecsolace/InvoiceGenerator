import SwiftData
import SwiftUI

private enum OnboardingStep: Int, CaseIterable {
    case intro
    case profile
}

private enum OnboardingField: Hashable {
    case companyName
    case ownerName
    case taxId
    case email
    case phone
    case address
}

private struct OnboardingBenefit: Identifiable {
    let id = UUID()
    let iconName: String
    let titleKey: String
    let messageKey: String
}

/// Onboarding flow shown the first time the app launches
struct OnboardingView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    let onFinish: () -> Void

    @FocusState private var focusedField: OnboardingField?
    @State private var currentStep: OnboardingStep = .intro
    @State private var issuerViewModel: IssuerViewModel?

    @State private var companyName = ""
    @State private var ownerName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var taxId = ""

    private let benefits: [OnboardingBenefit] = [
        OnboardingBenefit(
            iconName: "sparkles.rectangle.stack.fill",
            titleKey: "Create polished invoices fast",
            messageKey: "Start with the details that should appear on every invoice."
        ),
        OnboardingBenefit(
            iconName: "tray.full.fill",
            titleKey: "Stay organized from day one",
            messageKey: "Keep your emitter profile ready for clients, templates, and recurring work."
        ),
        OnboardingBenefit(
            iconName: "icloud.and.arrow.up.fill",
            titleKey: "Sync securely with iCloud",
            messageKey: "Your information stays available across iPhone, iPad, and Mac."
        )
    ]

    private var canFinishSetup: Bool {
        !companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var progressText: String {
        String(
            format: String(localized: "%lld of %lld", comment: "Onboarding progress label"),
            currentStep.rawValue + 1,
            OnboardingStep.allCases.count
        )
    }

    private var navigationTitle: LocalizedStringKey {
        switch currentStep {
        case .intro:
            return "Welcome"
        case .profile:
            return "Set Up Company"
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            onboardingContent
                .navigationTitle(navigationTitle)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar { toolbarContent }
                .interactiveDismissDisabled()
        }
        .onAppear(perform: prepareIssuer)
    }

    @ViewBuilder
    private var onboardingContent: some View {
        switch currentStep {
        case .intro:
            introStep
        case .profile:
            profileStep
        }
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(progressText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 48))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)

                Text(String(localized: "Welcome to Invoice Generator", comment: "Onboarding welcome title"))
                    .font(.largeTitle.weight(.bold))

                Text(
                    String(
                        localized: "Set up your company details once so every invoice starts ready to send.",
                        comment: "Onboarding intro subtitle"
                    )
                )
                .font(.title3)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(benefits) { benefit in
                    OnboardingBenefitRow(benefit: benefit)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Button(String(localized: "Set Up Company", comment: "Primary onboarding action")) {
                    advanceToProfile()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("onboarding-start-button")

                Button(String(localized: "Skip for now", comment: "Secondary onboarding action")) {
                    skipOnboarding()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("onboarding-skip-button")
            }
        }
        .padding(24)
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var profileStep: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            profileForm

            HStack {
                Spacer()

                finishButton
                    .frame(maxWidth: 220)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        #else
        profileForm
            .safeAreaInset(edge: .bottom, spacing: 0) {
                finishActionBar
            }
        #endif
    }

    private var profileForm: some View {
        Form {
            Section {
                TextField(String(localized: "Company Name", comment: "Company name field"), text: $companyName)
                    .focused($focusedField, equals: .companyName)
                    .submitLabel(.next)
                    .onSubmit { focusNextField(after: .companyName) }
                    .accessibilityIdentifier("onboarding-company-name-field")

                TextField(String(localized: "Owner Name", comment: "Owner name field"), text: $ownerName)
                    .focused($focusedField, equals: .ownerName)
                    .submitLabel(.next)
                    .onSubmit { focusNextField(after: .ownerName) }
                    .accessibilityIdentifier("onboarding-owner-name-field")

                TextField(String(localized: "Tax ID", comment: "Tax id field"), text: $taxId)
                    .focused($focusedField, equals: .taxId)
                    .submitLabel(.next)
                    .onSubmit { focusNextField(after: .taxId) }
                    .accessibilityIdentifier("onboarding-tax-id-field")
            } header: {
                Text(String(localized: "Company Information", comment: "Onboarding company information section title"))
            } footer: {
                Text(
                    String(
                        localized: "Only Company Name is required. You can update the rest later in Settings.",
                        comment: "Onboarding company information footer"
                    )
                )
            }

            Section {
                TextField(String(localized: "Email", comment: "Email field"), text: $email)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusNextField(after: .email) }
                    .accessibilityIdentifier("onboarding-email-field")
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif

                TextField(String(localized: "Phone", comment: "Phone field"), text: $phone)
                    .focused($focusedField, equals: .phone)
                    .submitLabel(.next)
                    .onSubmit { focusNextField(after: .phone) }
                    .accessibilityIdentifier("onboarding-phone-field")
                    #if os(iOS)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    #endif

                TextField(
                    String(localized: "Address", comment: "Address field"),
                    text: $address,
                    axis: .vertical
                )
                .focused($focusedField, equals: .address)
                .submitLabel(.done)
                .lineLimit(2...4)
                .onSubmit { focusedField = nil }
                .accessibilityIdentifier("onboarding-address-field")
            } header: {
                Text(String(localized: "Contact Information", comment: "Onboarding contact information section title"))
            } footer: {
                Text(
                    String(
                        localized: "Contact details are optional, but helpful for clients who need to reach you.",
                        comment: "Onboarding contact information footer"
                    )
                )
            }
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
    }

    #if !os(macOS)
    private var finishActionBar: some View {
        VStack(spacing: 12) {
            finishButton

            if !canFinishSetup {
                Text(
                    String(
                        localized: "Add your company name to finish setup.",
                        comment: "Validation hint for onboarding finish button"
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
    #endif

    private var finishButton: some View {
        Button(String(localized: "Finish Setup", comment: "Finish onboarding button")) {
            finishSetup()
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)
        .disabled(!canFinishSetup)
        .accessibilityIdentifier("onboarding-finish-button")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if currentStep == .profile {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "Back", comment: "Back button")) {
                    goBack()
                }
                .accessibilityIdentifier("onboarding-back-button")
            }
        }

        ToolbarItem(placement: .principal) {
            Text(progressText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("onboarding-progress-label")
        }

        #if os(iOS)
        if currentStep == .profile {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button(String(localized: "Done", comment: "Dismiss keyboard button")) {
                    focusedField = nil
                }
            }
        }
        #endif
    }

    // MARK: - Private Methods

    private func prepareIssuer() {
        guard issuerViewModel == nil else { return }
        let viewModel = IssuerViewModel(modelContext: modelContext)
        issuerViewModel = viewModel

        if let issuer = viewModel.issuers.first {
            companyName = issuer.name
            ownerName = issuer.ownerName
            email = issuer.email
            phone = issuer.phone
            address = issuer.address
            taxId = issuer.taxId
        }
    }

    private func advanceToProfile() {
        withAnimation {
            currentStep = .profile
        }
    }

    private func goBack() {
        focusedField = nil
        withAnimation {
            currentStep = .intro
        }
    }

    private func skipOnboarding() {
        onFinish()
        isPresented = false
    }

    private func focusNextField(after field: OnboardingField) {
        switch field {
        case .companyName:
            focusedField = .ownerName
        case .ownerName:
            focusedField = .taxId
        case .taxId:
            focusedField = .email
        case .email:
            focusedField = .phone
        case .phone:
            focusedField = .address
        case .address:
            focusedField = nil
        }
    }

    private func finishSetup() {
        if issuerViewModel == nil {
            issuerViewModel = IssuerViewModel(modelContext: modelContext)
        }

        let code = InvoiceNumberingService.defaultCodeCandidate(from: companyName)

        if let issuer = issuerViewModel?.issuers.first {
            _ = issuerViewModel?.updateIssuer(
                issuer,
                name: companyName,
                code: issuer.code,
                ownerName: ownerName,
                email: email,
                phone: phone,
                address: address,
                taxId: taxId,
                logoData: issuer.logoData
            )
        } else {
            _ = issuerViewModel?.createIssuer(
                name: companyName,
                code: code,
                ownerName: ownerName,
                email: email,
                phone: phone,
                address: address,
                taxId: taxId
            )
        }

        onFinish()
        isPresented = false
    }
}

private struct OnboardingBenefitRow: View {
    // MARK: - Properties

    let benefit: OnboardingBenefit

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: benefit.iconName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(benefit.titleKey))
                    .font(.headline)

                Text(LocalizedStringKey(benefit.messageKey))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
