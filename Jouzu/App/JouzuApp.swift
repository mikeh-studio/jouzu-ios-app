import SwiftUI
import SwiftData

@main
struct JouzuApp: App {
    @State private var syncCoordinator = SyncCoordinator()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(syncCoordinator)
        }
        .modelContainer(for: VocabCard.self)
    }
}

private struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncCoordinator.self) private var syncCoordinator

    var body: some View {
        Group {
            #if DEBUG
            if let destination = ScreenshotDestination.current {
                ScreenshotRootView(destination: destination)
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
        .task { @MainActor in
            await syncCoordinator.bootstrapIfNeeded(context: modelContext)
        }
    }
}
