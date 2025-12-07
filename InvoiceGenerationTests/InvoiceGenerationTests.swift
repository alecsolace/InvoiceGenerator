//
//  InvoiceGenerationTests.swift
//  InvoiceGenerationTests
//
//  Created by Alexander Aguirre on 4/12/25.
//

import Testing
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

}
