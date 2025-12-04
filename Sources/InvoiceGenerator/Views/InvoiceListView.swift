import SwiftUI
import SwiftData

/// View displaying list of invoices
struct InvoiceListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: InvoiceViewModel?
    @State private var searchText = ""
    @State private var selectedStatus: InvoiceStatus?
    @State private var showingAddInvoice = false
    @State private var showingInvoiceDetail = false
    @State private var selectedInvoice: Invoice?
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    if viewModel.isLoading {
                        ProgressView("Loading invoices...")
                    } else if viewModel.invoices.isEmpty {
                        emptyStateView
                    } else {
                        invoiceList(viewModel: viewModel)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Invoices")
            .searchable(text: $searchText, prompt: "Search invoices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddInvoice = true }) {
                        Label("Add Invoice", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("All Invoices") {
                            selectedStatus = nil
                            viewModel?.filterByStatus(nil)
                        }
                        
                        ForEach(InvoiceStatus.allCases, id: \.self) { status in
                            Button(status.rawValue) {
                                selectedStatus = status
                                viewModel?.filterByStatus(status)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddInvoice) {
                if let viewModel = viewModel {
                    AddInvoiceView(viewModel: viewModel)
                }
            }
            .sheet(item: $selectedInvoice) { invoice in
                if let viewModel = viewModel {
                    InvoiceDetailView(invoice: invoice, viewModel: viewModel)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = InvoiceViewModel(modelContext: modelContext)
            }
        }
        .onChange(of: searchText) { _, newValue in
            viewModel?.searchInvoices(query: newValue)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Invoices")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first invoice to get started")
                .foregroundStyle(.secondary)
            
            Button(action: { showingAddInvoice = true }) {
                Label("Create Invoice", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private func invoiceList(viewModel: InvoiceViewModel) -> some View {
        List {
            ForEach(viewModel.invoices) { invoice in
                InvoiceRowView(invoice: invoice)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedInvoice = invoice
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.deleteInvoice(invoice)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }
}

/// Row view for invoice in list
struct InvoiceRowView: View {
    let invoice: Invoice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(invoice.invoiceNumber)
                    .font(.headline)
                
                Spacer()
                
                Text(invoice.totalAmount.formattedAsCurrency)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            Text(invoice.clientName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                Label(invoice.issueDate.shortFormat, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                statusBadge
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusBadge: some View {
        Text(invoice.status.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch invoice.status {
        case .draft: return .gray
        case .sent: return .blue
        case .paid: return .green
        case .overdue: return .red
        case .cancelled: return .orange
        }
    }
}

#Preview {
    InvoiceListView()
        .modelContainer(for: [Invoice.self, InvoiceItem.self, CompanyProfile.self])
}
