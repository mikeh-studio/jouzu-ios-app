import SwiftUI
import SwiftData

@main
struct JouzuApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(for: VocabCard.self)
    }
}

private struct AppRootView: View {
    var body: some View {
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
}
