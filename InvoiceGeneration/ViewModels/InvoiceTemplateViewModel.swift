import Foundation
import Observation
import OSLog
import SwiftData

@Observable
final class InvoiceTemplateViewModel {
    private let modelContext: ModelContext

    var templates: [InvoiceTemplate] = []
    var isLoading = false
    var errorMessage: String?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchTemplates()
    }

    func fetchTemplates() {
        isLoading = true
        errorMessage = nil

        do {
            let descriptor = FetchDescriptor<InvoiceTemplate>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            templates = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "No se pudieron cargar las plantillas: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func template(for client: Client) -> InvoiceTemplate? {
        if let preferredTemplateID = client.preferredTemplateID,
           let preferred = templates.first(where: { $0.id == preferredTemplateID }) {
            return preferred
        }

        return templates.first(where: { $0.client?.id == client.id })
    }

    @discardableResult
    func createTemplate(
        name: String,
        client: Client?,
        issuer: Issuer?,
        clientName: String,
        clientEmail: String,
        clientIdentificationNumber: String,
        clientAddress: String,
        dueDays: Int,
        ivaPercentage: Decimal,
        irpfPercentage: Decimal,
        notes: String,
        items: [TemplateLineItemInput]
    ) -> InvoiceTemplate? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "La plantilla necesita un nombre."
            return nil
        }

        let template = InvoiceTemplate(
            name: trimmedName,
            client: client,
            issuer: issuer,
            clientName: clientName,
            clientEmail: clientEmail,
            clientIdentificationNumber: clientIdentificationNumber,
            clientAddress: clientAddress,
            dueDays: dueDays,
            ivaPercentage: ivaPercentage,
            irpfPercentage: irpfPercentage,
            notes: notes
        )

        modelContext.insert(template)

        for (index, item) in items.enumerated() {
            let templateItem = InvoiceTemplateItem(
                description: item.description,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                sortOrder: index
            )
            templateItem.template = template
            template.items.append(templateItem)
            modelContext.insert(templateItem)
        }

        if let client {
            client.preferredTemplateID = template.id
            client.updateTimestamp()
        }

        if saveContext() {
            fetchTemplates()
            return template
        }

        return nil
    }

    @discardableResult
    func createTemplate(from invoice: Invoice, suggestedName: String? = nil) -> InvoiceTemplate? {
        let dueDays = max(Calendar.current.dateComponents([.day], from: invoice.issueDate, to: invoice.dueDate).day ?? 0, 0)
        let name = suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? suggestedName!
            : "\(invoice.clientName) mensual"

        let items = invoice.items.enumerated().map { index, item in
            TemplateLineItemInput(
                description: item.itemDescription,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                sortOrder: index
            )
        }

        return createTemplate(
            name: name,
            client: invoice.client,
            issuer: invoice.issuer,
            clientName: invoice.clientName,
            clientEmail: invoice.clientEmail,
            clientIdentificationNumber: invoice.clientIdentificationNumber,
            clientAddress: invoice.clientAddress,
            dueDays: dueDays,
            ivaPercentage: invoice.ivaPercentage,
            irpfPercentage: invoice.irpfPercentage,
            notes: invoice.notes,
            items: items
        )
    }

    func deleteTemplate(_ template: InvoiceTemplate) {
        modelContext.delete(template)

        if let clients = template.client {
            if clients.preferredTemplateID == template.id {
                clients.preferredTemplateID = nil
                clients.updateTimestamp()
            }
        }

        if saveContext() {
            fetchTemplates()
        }
    }

    private func saveContext() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            errorMessage = "No se pudo guardar la plantilla: \(error.localizedDescription)"
            PersistenceController.logger.error("Failed to save template: \(error.localizedDescription)")
            return false
        }
    }
}

struct TemplateLineItemInput {
    let description: String
    let quantity: Int
    let unitPrice: Decimal
    let sortOrder: Int
}
