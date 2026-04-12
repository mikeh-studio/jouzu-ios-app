import SwiftUI
import SwiftData

struct SyncStatusView: View {
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    LabeledContent("State", value: statusText)
                    LabeledContent("Owner ID", value: syncCoordinator.ownerId)

                    if let lastSyncAt = syncCoordinator.lastSyncAt {
                        LabeledContent("Last Sync") {
                            Text(lastSyncAt, style: .relative)
                        }
                    }

                    if let error = syncCoordinator.lastError, !error.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Last Error")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Results") {
                    LabeledContent("Pulled New", value: "\(syncCoordinator.lastResult.pulledCreated)")
                    LabeledContent("Pulled Updated", value: "\(syncCoordinator.lastResult.pulledUpdated)")
                    LabeledContent("Pushed Upserts", value: "\(syncCoordinator.lastResult.pushedUpserts)")
                    LabeledContent("Pushed Deletes", value: "\(syncCoordinator.lastResult.pushedDeletes)")
                    LabeledContent("Failures", value: "\(syncCoordinator.lastResult.failed)")
                }

                if !syncCoordinator.isConfigured {
                    Section("Configuration") {
                        Text("Set `GOOGLE_SHEET_SYNC_BASE_URL` and `GOOGLE_SHEET_SYNC_API_KEY` in Info.plist to enable Google Sheet sync.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Sync Now") {
                        Task { @MainActor in
                            await syncCoordinator.syncNow(context: modelContext)
                        }
                    }
                    .disabled(!syncCoordinator.isConfigured || syncCoordinator.status == .syncing)
                }
            }
        }
    }

    private var statusText: String {
        switch syncCoordinator.status {
        case .idle:
            return "Idle"
        case .syncing:
            return "Syncing"
        case .succeeded:
            return "Synced"
        case .failed:
            return "Failed"
        case .disabled:
            return "Disabled"
        }
    }
}

#Preview {
    SyncStatusView()
        .modelContainer(PreviewSampleData.previewModelContainer)
        .environment(SyncCoordinator.preview)
}
