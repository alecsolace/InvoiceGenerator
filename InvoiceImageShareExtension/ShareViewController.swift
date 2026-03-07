import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var hasStartedImport = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        embedStatusView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasStartedImport else { return }
        hasStartedImport = true

        Task { @MainActor in
            await importSharedImage()
        }
    }

    private func embedStatusView() {
        let hostingController = UIHostingController(rootView: ShareExtensionStatusView())
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
    }

    @MainActor
    private func importSharedImage() async {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = extensionItem.attachments?.first(where: {
                  $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
              }) else {
            extensionContext?.cancelRequest(withError: ShareExtensionError.noImage)
            return
        }

        do {
            let imageData = try await loadImageData(from: attachment)
            try SharedImageImportStore.savePendingImageData(imageData, source: .shareExtension)
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        } catch {
            extensionContext?.cancelRequest(withError: error)
        }
    }

    private func loadImageData(from attachment: NSItemProvider) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let url = item as? URL, let data = try? Data(contentsOf: url) {
                    continuation.resume(returning: data)
                    return
                }

                if let data = item as? Data {
                    continuation.resume(returning: data)
                    return
                }

                continuation.resume(throwing: ShareExtensionError.unreadablePayload)
            }
        }
    }
}

private struct ShareExtensionStatusView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 42))
                .foregroundStyle(.tint)

            Text("Guardando captura")
                .font(.title3.weight(.semibold))

            Text("La imagen se enviara a InvoiceGeneration para precargar una nueva factura cuando abras la app.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            ProgressView()
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

private enum ShareExtensionError: LocalizedError {
    case noImage
    case unreadablePayload

    var errorDescription: String? {
        switch self {
        case .noImage:
            return "No se encontro ninguna imagen para importar."
        case .unreadablePayload:
            return "No se pudo leer la imagen compartida."
        }
    }
}

private enum SharedImageImportStore {
    static let appGroupIdentifier = "group.com.alecsolace.InvoiceGeneration"

    private static let imageFileName = "pending-invoice-import-image.bin"
    private static let metadataFileName = "pending-invoice-import-metadata.json"

    static func savePendingImageData(_ data: Data, source: PendingImportSource) throws {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )?.appendingPathComponent("PendingInvoiceImport", isDirectory: true) else {
            throw ShareExtensionError.unreadablePayload
        }

        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true, attributes: nil)
        try data.write(to: containerURL.appendingPathComponent(imageFileName), options: .atomic)

        let metadata = PendingImportMetadata(createdAt: Date(), source: source)
        let encodedMetadata = try JSONEncoder().encode(metadata)
        try encodedMetadata.write(to: containerURL.appendingPathComponent(metadataFileName), options: .atomic)
    }
}

private enum PendingImportSource: String, Codable {
    case shareExtension
}

private struct PendingImportMetadata: Codable {
    let createdAt: Date
    let source: PendingImportSource
}
