import SwiftData
import SwiftUI

#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

private enum PlatformColors {
    static var secondarySystemBackground: Color {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(macOS)
        return Color(NSColor.underPageBackgroundColor)
        #else
        return Color(.white)
        #endif
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: HomeViewModel?
    @State private var invoiceViewModel: InvoiceViewModel?
    @State private var composerSeed: InvoiceComposerSeed?
    @State private var selectedInvoice: Invoice?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel, let invoiceViewModel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            heroCard
                            statsSection(viewModel: viewModel)
                            templatesSection(viewModel: viewModel)
                            frequentClientsSection(viewModel: viewModel)
                            pendingSection(viewModel: viewModel)
                            draftsSection(viewModel: viewModel)
                            analyticsLink
                        }
                        .padding()
                    }
                    .navigationDestination(item: $selectedInvoice) { invoice in
                        InvoiceDetailView(invoice: invoice, viewModel: invoiceViewModel)
                    }
                    .sheet(item: $composerSeed, onDismiss: refreshData) { seed in
                        AddInvoiceView(viewModel: invoiceViewModel, seed: seed) { created in
                            selectedInvoice = created
                            refreshData()
                        }
                    }
                } else {
                    ProgressView("Cargando inicio…")
                }
            }
            .navigationTitle("Inicio")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        composerSeed = .quick
                    } label: {
                        Label("Nueva factura", systemImage: "plus")
                    }
                }
            }
        }
        .onAppear {
            loadViewModelsIfNeeded()
            refreshData()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tu facturacion del mes")
                .font(.title2)
                .fontWeight(.bold)

            Text("Crea la factura de este mes, reutiliza plantillas y sigue los cobros pendientes sin salir de Inicio.")
                .foregroundStyle(.secondary)

            Button {
                composerSeed = .quick
            } label: {
                Label("Crear factura rapida", systemImage: "bolt.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("home-quick-create")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.18), Color.teal.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func statsSection(viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resumen")
                .font(.headline)

            HStack(spacing: 12) {
                HomeStatCard(title: "Emitido", value: viewModel.thisMonthIssued.formattedAsCurrency, tint: .blue)
                HomeStatCard(title: "Cobrado", value: viewModel.thisMonthPaid.formattedAsCurrency, tint: .green)
                HomeStatCard(title: "Pendiente", value: viewModel.pendingAmount.formattedAsCurrency, tint: .orange)
            }
        }
    }

    private func templatesSection(viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Plantillas")
                    .font(.headline)
                Spacer()
                Text(viewModel.templates.isEmpty ? "0" : "\(viewModel.templates.count)")
                    .foregroundStyle(.secondary)
            }

            if viewModel.templates.isEmpty {
                helperCard(text: "Guarda una factura como plantilla para emitir el siguiente mes en segundos.")
            } else {
                ForEach(viewModel.templates.prefix(4)) { template in
                    Button {
                        composerSeed = .template(template)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(template.client?.name ?? template.clientName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.tint)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PlatformColors.secondarySystemBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func frequentClientsSection(viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clientes frecuentes")
                .font(.headline)

            if viewModel.frequentClients.isEmpty {
                helperCard(text: "Tus clientes con historial apareceran aqui para facturarlos sin buscar entre pantallas.")
            } else {
                ForEach(viewModel.frequentClients) { summary in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.client.name)
                                .font(.headline)
                            Text("\(summary.invoiceCount) facturas")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Facturar") {
                            composerSeed = .client(summary.client)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("home-client-\(summary.client.id.uuidString)")
                    }
                    .padding()
                    .background(PlatformColors.secondarySystemBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private func pendingSection(viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cobros pendientes")
                .font(.headline)

            if viewModel.pendingInvoices.isEmpty {
                helperCard(text: "No hay facturas enviadas o vencidas pendientes de cobro.")
            } else {
                ForEach(viewModel.pendingInvoices) { invoice in
                    Button {
                        selectedInvoice = invoice
                    } label: {
                        CompactInvoiceCard(invoice: invoice)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func draftsSection(viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Borradores recientes")
                .font(.headline)

            if viewModel.recentDrafts.isEmpty {
                helperCard(text: "Los borradores recientes apareceran aqui para retomarlos sin navegar por toda la app.")
            } else {
                ForEach(viewModel.recentDrafts) { invoice in
                    Button {
                        selectedInvoice = invoice
                    } label: {
                        CompactInvoiceCard(invoice: invoice)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var analyticsLink: some View {
        NavigationLink {
            DashboardView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Analitica")
                        .font(.headline)
                    Text("Revisa estados e ingresos cuando necesites contexto, no para cada factura.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chart.pie")
                    .font(.title3)
                    .foregroundStyle(.tint)
            }
            .padding()
            .background(PlatformColors.secondarySystemBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func helperCard(text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PlatformColors.secondarySystemBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func loadViewModelsIfNeeded() {
        if viewModel == nil {
            viewModel = HomeViewModel(modelContext: modelContext)
        }

        if invoiceViewModel == nil {
            invoiceViewModel = InvoiceViewModel(modelContext: modelContext)
        }
    }

    private func refreshData() {
        viewModel?.refresh()
        invoiceViewModel?.fetchInvoices()
    }
}

private struct HomeStatCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct CompactInvoiceCard: View {
    let invoice: Invoice

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.invoiceNumber)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(invoice.clientName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Vence \(invoice.dueDate.mediumFormat)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(invoice.totalAmount.formattedAsCurrency)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(invoice.status.localizedTitle)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(PlatformColors.secondarySystemBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    HomeView()
        .modelContainer(PersistenceController.preview)
        .environmentObject(SubscriptionService())
}
