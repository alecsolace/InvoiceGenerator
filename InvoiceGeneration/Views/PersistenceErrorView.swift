import SwiftUI

/// Shown when the SwiftData ModelContainer cannot be created at startup.
struct PersistenceErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text(String(localized: "Unable to Open Data", comment: "Persistence error title"))
                    .font(.title2.bold())

                Text(String(localized: "Your data could not be loaded. This may be caused by low disk space or a storage error. Please restart the app. If the problem persists, free up disk space and try again.", comment: "Persistence error body"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
    }
}
