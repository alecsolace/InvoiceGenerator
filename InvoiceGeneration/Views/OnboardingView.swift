import SwiftUI
import SwiftData

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let titleKey: String
    let messageKey: String
    let iconName: String
}

/// Onboarding flow shown the first time the app launches
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    let onFinish: () -> Void
    
    @State private var currentStep = 0
    @State private var profileViewModel: CompanyProfileViewModel?
    
    @State private var companyName = ""
    @State private var ownerName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var taxId = ""
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            titleKey: "Welcome to Invoice Generator",
            messageKey: "Create and send professional invoices from any Apple device.",
            iconName: "doc.text.fill"
        ),
        OnboardingPage(
            titleKey: "Stay Organized",
            messageKey: "Track clients, statuses, and totals with real-time dashboards.",
            iconName: "tray.full.fill"
        ),
        OnboardingPage(
            titleKey: "Sync with iCloud",
            messageKey: "Your invoices and clients stay updated automatically across iPhone, iPad, and Mac.",
            iconName: "icloud.and.arrow.up.fill"
        )
    ]
    
    private var totalSteps: Int { pages.count + 1 }
    private var isFinalStep: Bool { currentStep == totalSteps - 1 }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                onboardingPages
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 8)
                
                HStack {
                    if currentStep > 0 {
                        Button(String(localized: "Back", comment: "Back button")) {
                            goBack()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    Button(
                        isFinalStep ? String(localized: "Finish Setup", comment: "Finish onboarding button")
                        : String(localized: "Next", comment: "Next button")
                    ) {
                        advance()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isFinalStep && companyName.isEmpty)
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !isFinalStep {
                        Button(String(localized: "Skip", comment: "Skip onboarding button")) {
                            currentStep = totalSteps - 1
                        }
                    }
                }
            }
            .interactiveDismissDisabled()
        }
        .onAppear(perform: prepareProfile)
    }
    
    @ViewBuilder
    private var onboardingPages: some View {
        #if os(macOS)
        VStack(spacing: 12) {
            pagesTabView
            macPageIndicator
        }
        #else
        pagesTabView
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        #endif
    }
    
    private var pagesTabView: some View {
        TabView(selection: $currentStep) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                OnboardingIntroPage(page: page)
                    .tag(index)
            }
            
            profileStep
                .tag(totalSteps - 1)
        }
    }
    
    @ViewBuilder
    private var macPageIndicator: some View {
        #if os(macOS)
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? Color.accentColor : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
        }
        #endif
    }
    
    private var profileStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                    .padding(.bottom, 4)
                
                Text("Set Up Your Profile")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Enter your company details so they appear on every invoice.")
                    .foregroundStyle(.secondary)
                
                Text("We only use this information to personalize your invoices and sync it securely with iCloud.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 12) {
                    TextField(String(localized: "Company Name", comment: "Company name field"), text: $companyName)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField(String(localized: "Owner Name", comment: "Owner name field"), text: $ownerName)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField(String(localized: "Email", comment: "Email field"), text: $email)
                        .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    #endif
                    
                    TextField(String(localized: "Phone", comment: "Phone field"), text: $phone)
                        .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    #endif
                    
                    TextField(
                        String(localized: "Address", comment: "Address field"),
                        text: $address,
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    
                    TextField(String(localized: "Tax ID", comment: "Tax id field"), text: $taxId)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal)
        }
    }
    
    private func prepareProfile() {
        guard profileViewModel == nil else { return }
        let viewModel = CompanyProfileViewModel(modelContext: modelContext)
        profileViewModel = viewModel
        
        if let profile = viewModel.profile {
            companyName = profile.companyName
            ownerName = profile.ownerName
            email = profile.email
            phone = profile.phone
            address = profile.address
            taxId = profile.taxId
        }
    }
    
    private func goBack() {
        guard currentStep > 0 else { return }
        currentStep -= 1
    }
    
    private func advance() {
        if isFinalStep {
            finishSetup()
        } else {
            withAnimation {
                currentStep = min(currentStep + 1, totalSteps - 1)
            }
        }
    }
    
    private func finishSetup() {
        if profileViewModel == nil {
            profileViewModel = CompanyProfileViewModel(modelContext: modelContext)
        }
        
        profileViewModel?.saveProfile(
            companyName: companyName,
            ownerName: ownerName,
            email: email,
            phone: phone,
            address: address,
            taxId: taxId
        )
        
        onFinish()
        isPresented = false
    }
}

private struct OnboardingIntroPage: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: page.iconName)
                .font(.system(size: 60))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            
            Text(LocalizedStringKey(page.titleKey))
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text(LocalizedStringKey(page.messageKey))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
}
