import SwiftData
import SwiftUI

struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: InvoiceTemplateViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading {
                    ProgressView("Cargando plantillas…")
                } else if viewModel.templates.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(viewModel.templates) { template in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(template.name)
                                    .font(.headline)
                                Text(template.client?.name ?? template.clientName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let issuer = template.issuer {
                                    Text("Emisor: \(issuer.name)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(template.items.count) conceptos")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            .templateRowActions {
                                viewModel.deleteTemplate(template)
                            }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Plantillas")
        .onAppear {
            if viewModel == nil {
                viewModel = InvoiceTemplateViewModel(modelContext: modelContext)
            } else {
                viewModel?.fetchTemplates()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("No hay plantillas")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Guarda una factura como plantilla desde el detalle para reutilizarla el proximo mes.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

private extension View {
    @ViewBuilder
    func templateRowActions(onDelete: @escaping () -> Void) -> some View {
        #if os(iOS)
        self.swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Eliminar", systemImage: "trash")
            }
        }
        #else
        self.contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Eliminar", systemImage: "trash")
            }
        }
        #endif
    }
}

#Preview {
    NavigationStack {
        TemplateListView()
            .modelContainer(PersistenceController.preview)
    }
}
