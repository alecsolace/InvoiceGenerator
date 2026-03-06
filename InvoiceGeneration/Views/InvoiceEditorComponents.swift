import Foundation
import SwiftUI

struct DraftInvoiceItem: Identifiable, Equatable {
    let id: UUID
    var description: String
    var quantity: Int
    var unitPrice: Decimal

    init(id: UUID = UUID(), description: String, quantity: Int, unitPrice: Decimal) {
        self.id = id
        self.description = description
        self.quantity = quantity
        self.unitPrice = unitPrice
    }

    var total: Decimal { Decimal(quantity) * unitPrice }
}

struct InvoiceEditorSections: View {
    let issuers: [Issuer]
    let clients: [Client]
    @Binding var selectedIssuerID: UUID?
    @Binding var selectedClientID: UUID?
    @Binding var invoiceNumber: String
    @Binding var clientName: String
    @Binding var clientEmail: String
    @Binding var clientIdentificationNumber: String
    @Binding var clientAddress: String
    @Binding var issueDate: Date
    @Binding var dueDate: Date
    @Binding var ivaPercentage: String
    @Binding var irpfPercentage: String
    @Binding var notes: String
    @Binding var draftItems: [DraftInvoiceItem]
    @Binding var showingAddItem: Bool
    @Binding var editingDraftItem: DraftInvoiceItem?
    let onAddClient: () -> Void
    let onUseNextInvoiceNumber: () -> Void
    let onRemoveDraftItem: (DraftInvoiceItem) -> Void

    var body: some View {
        invoiceSection
        issuerSection
        savedClientsSection
        clientDataSection
        itemsSection
        taxesSection
        notesSection
    }

    private var invoiceSection: some View {
        Section("Factura") {
            TextField("Numero de factura", text: $invoiceNumber)
#if os(iOS)
                .autocapitalization(.allCharacters)
#endif

            Button("Usar siguiente numero") {
                onUseNextInvoiceNumber()
            }
            .disabled(issuers.isEmpty)

            DatePicker("Fecha de emision", selection: $issueDate, displayedComponents: .date)
            DatePicker("Fecha de vencimiento", selection: $dueDate, displayedComponents: .date)
        }
    }

    private var issuerSection: some View {
        Section("Emisor") {
            if !issuers.isEmpty {
                Picker("Emisor", selection: $selectedIssuerID) {
                    ForEach(issuers) { issuer in
                        Text("\(issuer.name) (\(issuer.code))")
                            .tag(Optional(issuer.id))
                    }
                }
            } else {
                Text("No hay emisores disponibles. Crealos desde Ajustes.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var savedClientsSection: some View {
        Section("Clientes guardados") {
            if !clients.isEmpty {
                Picker("Cliente", selection: $selectedClientID) {
                    Text("Ninguno")
                        .tag(UUID?.none)

                    ForEach(clients) { client in
                        Text(client.name)
                            .tag(Optional(client.id))
                    }
                }
            } else {
                Text("Aun no tienes clientes guardados.")
                    .foregroundStyle(.secondary)
            }

            Button(action: onAddClient) {
                Label("Crear cliente", systemImage: "plus")
            }
        }
    }

    private var clientDataSection: some View {
        Section("Datos del cliente") {
            TextField("Nombre", text: $clientName)
            TextField("Email", text: $clientEmail)
                .textContentType(.emailAddress)
                .disableAutocorrection(true)
            TextField("NIF/CIF", text: $clientIdentificationNumber)
            TextField("Direccion", text: $clientAddress, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var itemsSection: some View {
        Section("Importes") {
            if draftItems.isEmpty {
                Text("Anade los conceptos para calcular total, IVA e IRPF desde el principio.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(draftItems) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.description)
                                .font(.headline)
                            Spacer()
                            Text(item.total.formattedAsCurrency)
                                .font(.headline)
                        }

                        Text("\(item.quantity) x \(item.unitPrice.formattedAsCurrency)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button(action: { editingDraftItem = item }) {
                                Label("Editar", systemImage: "slider.horizontal.3")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive, action: { onRemoveDraftItem(item) }) {
                                Label("Eliminar", systemImage: "trash")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Button {
                showingAddItem = true
            } label: {
                Label("Anadir concepto", systemImage: "plus.circle")
            }
            .accessibilityIdentifier("invoice-add-item")
        }
    }

    private var taxesSection: some View {
        Section("Totales") {
            TextField("IVA %", text: $ivaPercentage)
#if os(iOS)
                .keyboardType(.decimalPad)
#endif

            TextField("IRPF %", text: $irpfPercentage)
#if os(iOS)
                .keyboardType(.decimalPad)
#endif

            LabeledContent("Subtotal", value: itemsTotal.formattedAsCurrency)
            LabeledContent("IVA (\(ivaPercentageValue.formattedAsPercent))", value: ivaAmount.formattedAsCurrency)
            LabeledContent("IRPF (\(irpfPercentageValue.formattedAsPercent))", value: (-irpfAmount).formattedAsCurrency)
            LabeledContent("Total", value: invoiceTotal.formattedAsCurrency)
        }
    }

    private var notesSection: some View {
        Section("Notas") {
            TextField("Notas para esta factura", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var itemsTotal: Decimal {
        draftItems.reduce(0) { $0 + $1.total }
    }

    private var ivaPercentageValue: Decimal {
        Decimal(string: ivaPercentage) ?? 0
    }

    private var irpfPercentageValue: Decimal {
        Decimal(string: irpfPercentage) ?? 0
    }

    private var ivaAmount: Decimal {
        (itemsTotal * ivaPercentageValue) / Decimal(100)
    }

    private var irpfAmount: Decimal {
        (itemsTotal * irpfPercentageValue) / Decimal(100)
    }

    private var invoiceTotal: Decimal {
        itemsTotal + ivaAmount - irpfAmount
    }
}

struct InvoiceDraftItemEditor: View {
    enum Mode {
        case add
        case edit(DraftInvoiceItem)

        var title: String {
            switch self {
            case .add:
                return "Anadir concepto"
            case .edit:
                return "Editar concepto"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let onSave: (DraftInvoiceItem) -> Void

    @State private var descriptionText: String
    @State private var quantity: Int
    @State private var unitPrice: String

    init(mode: Mode, onSave: @escaping (DraftInvoiceItem) -> Void) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .add:
            _descriptionText = State(initialValue: "")
            _quantity = State(initialValue: 1)
            _unitPrice = State(initialValue: "")
        case .edit(let item):
            _descriptionText = State(initialValue: item.description)
            _quantity = State(initialValue: item.quantity)
            _unitPrice = State(initialValue: NSDecimalNumber(decimal: item.unitPrice).stringValue)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Concepto") {
                    TextField("Descripcion", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...4)

                    Stepper("Cantidad: \(quantity)", value: $quantity, in: 1...999)

                    TextField("Precio unitario", text: $unitPrice)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                }

                if let price = Decimal(string: unitPrice), price > 0 {
                    Section {
                        LabeledContent("Total", value: (price * Decimal(quantity)).formattedAsCurrency)
                    }
                }
            }
            .navigationTitle(mode.title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        persist()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !descriptionText.isEmpty && Decimal(string: unitPrice) != nil
    }

    private func persist() {
        guard let price = Decimal(string: unitPrice) else { return }

        let identifier: UUID
        switch mode {
        case .add:
            identifier = UUID()
        case .edit(let item):
            identifier = item.id
        }

        onSave(
            DraftInvoiceItem(
                id: identifier,
                description: descriptionText,
                quantity: quantity,
                unitPrice: price
            )
        )
        dismiss()
    }
}
