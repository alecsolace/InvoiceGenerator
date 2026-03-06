//
//  InvoiceGenerationTests.swift
//  InvoiceGenerationTests
//
//  Created by Alexander Aguirre on 4/12/25.
//

import Testing
import SwiftData
@testable import InvoiceGeneration

struct InvoiceGenerationTests {

    @MainActor
    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @MainActor
    @Test func freePlanCapsClientsAtTwo() async throws {
        let service = SubscriptionService()

        #expect(service.canAddClient(currentCount: 0))
        #expect(service.canAddClient(currentCount: 1))
        #expect(!service.canAddClient(currentCount: service.freeClientLimit))
    }

    @MainActor
    @Test func syncRequiresActivePro() async throws {
        let service = SubscriptionService()
        service.syncPreferred = true
        #expect(service.syncEnabled == false)

        #if DEBUG
        service.debugSetStatus(.active(expirationDate: nil))
        #expect(service.syncEnabled == true)
        #endif
    }

    @MainActor
    @Test func issuerNumberingIncrementsSequence() async throws {
        let issuer = Issuer(name: "Family", code: "FAM")

        #expect(InvoiceNumberingService.nextInvoiceNumber(for: issuer) == "FAM-0001")

        InvoiceNumberingService.registerUsedInvoiceNumber("FAM-0001", for: issuer)
        #expect(issuer.nextInvoiceSequence == 2)
        #expect(InvoiceNumberingService.nextInvoiceNumber(for: issuer) == "FAM-0002")
    }

    @MainActor
    @Test func issuerManualOverrideBumpsSequenceWhenHigher() async throws {
        let issuer = Issuer(name: "Family", code: "FAM", nextInvoiceSequence: 2)

        InvoiceNumberingService.registerUsedInvoiceNumber("FAM-0150", for: issuer)

        #expect(issuer.nextInvoiceSequence == 151)
        #expect(InvoiceNumberingService.nextInvoiceNumber(for: issuer) == "FAM-0151")
    }

    @MainActor
    @Test func issuerMigrationCreatesDefaultAndLinksInvoices() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Invoice.self,
            InvoiceItem.self,
            CompanyProfile.self,
            Client.self,
            Issuer.self,
            configurations: configuration
        )
        let context = container.mainContext

        let profile = CompanyProfile(companyName: "Acme Family", email: "hello@acme.dev")
        context.insert(profile)

        let invoice = Invoice(invoiceNumber: "ACM-0007", clientName: "Client")
        context.insert(invoice)
        try context.save()

        IssuerMigrationService.runIfNeeded(modelContext: context)

        let issuers = try context.fetch(FetchDescriptor<Issuer>())
        let invoices = try context.fetch(FetchDescriptor<Invoice>())

        #expect(issuers.count == 1)
        #expect(invoices.count == 1)
        #expect(invoices[0].issuer != nil)
        #expect(!invoices[0].issuerName.isEmpty)
    }

    @MainActor
    @Test func issuerMigrationPersistsDefaultWithoutInvoices() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Invoice.self,
            InvoiceItem.self,
            CompanyProfile.self,
            Client.self,
            Issuer.self,
            configurations: configuration
        )
        let context = container.mainContext

        let profile = CompanyProfile(companyName: "No Invoices Co", email: "hola@example.com")
        context.insert(profile)
        try context.save()

        IssuerMigrationService.runIfNeeded(modelContext: context)

        let issuers = try context.fetch(FetchDescriptor<Issuer>())
        #expect(issuers.count == 1)
        #expect(issuers[0].name == "No Invoices Co")
    }

    @MainActor
    @Test func issuerDeleteBlockedWhenInvoicesExist() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Invoice.self,
            InvoiceItem.self,
            CompanyProfile.self,
            Client.self,
            Issuer.self,
            configurations: configuration
        )
        let context = container.mainContext
        let viewModel = IssuerViewModel(modelContext: context)

        guard let issuer = viewModel.createIssuer(name: "Main", code: "MNN") else {
            Issue.record("Failed to create issuer")
            return
        }

        let invoice = Invoice(invoiceNumber: "MNN-0001", clientName: "Client", issuer: issuer)
        invoice.captureIssuerSnapshot(from: issuer)
        context.insert(invoice)
        try context.save()
        viewModel.fetchIssuers()

        let deleted = viewModel.deleteIssuer(issuer)
        #expect(deleted == false)
    }

}
